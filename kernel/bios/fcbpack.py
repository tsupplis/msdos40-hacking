"""Build SYSINIT relocation data from the linked MASM kernel."""

from pathlib import Path
import re
import struct
import sys

root = Path(__file__).resolve().parents[2]
dos = root / "kernel/dos"
image = (dos / "msdos.sys").read_bytes()
link_map = (dos / "msdos.map").read_text()
symbols = {
    name.lower(): int(addr, 16)
    for addr, name in re.findall(
        r"0000:([0-9A-F]{4}) +([^\s]+)", link_map
    )
}
start = symbols["$get_fcb_position"]
end = symbols["doscodeend"]
# LINK supplies the placement-independent suffix shared by both boot layouts.
segment = re.search(r"^ +([0-9A-F]+)H +[0-9A-F]+H +([0-9A-F]+)H +DOSCODE +DOSCODE", link_map, re.M)
if not segment:
    raise ValueError("missing DOSCODE segment")
code_start, code_length = (int(value, 16) for value in segment.groups())
if not start <= code_start or code_start + code_length != end:
    raise ValueError("DOSCODE must end at DosCodeEnd")
legacy_length = code_start - start
native = image[start:end]
upper = bytearray(native)
base = 0x100
entries = [15, 16, 19, 20, 21, 22, 23, 33, 34, 35, 36, 39, 40, 78, 79]
backs = {}
segments = []
low_relative = []


def word(value):
    return struct.pack("<H", value & 0xFFFF)


def bridge(target):
    if target not in backs:
        pos = len(upper)
        backs[target] = pos
        if target in (symbols["save_world"], symbols["restore_world"]):
            code = bytearray(image[target : target + 19])
            assert code[:2] == b"\x2e\x8f" and code[14:17] == b"\x2e\xff\x26"
            code[0] = code[14] = 0x36
            upper.extend(code)
        else:
            segments.append(base + pos + 3)
            upper.extend(b"\x9a" + word(0) + word(0) + word(target) + b"\xc3")
    return backs[target]


# MASM emits 16-bit offset fixups against DOSGROUP. Relative fixups are
# calls or tail jumps. Absolute fixups include the four near I/O selectors.
def object_fixups(path):
    obj = path.read_bytes()
    pos = 0
    active = False
    data_offset = None
    names = [None]
    segments = [None]
    while pos < len(obj):
        kind = obj[pos]
        size = int.from_bytes(obj[pos + 1 : pos + 3], "little")
        record = obj[pos + 3 : pos + 2 + size]
        pos += size + 3
        if kind == 0x96:  # LNAMES
            i = 0
            while i < len(record):
                length = record[i]
                names.append(record[i + 1 : i + 1 + length])
                i += length + 1
        if kind == 0x98:  # SEGDEF (16-bit relocatable segments)
            segments.append(names[record[3]])
        if kind == 0xA0:  # LEDATA, segment index < 128
            data_offset = int.from_bytes(record[1:3], "little")
            active = segments[record[0]] == b"LAST"
        if kind != 0x9C or not active:  # FIXUPP
            continue
        i = 0
        while i < len(record):
            loc, offset, spec = record[i : i + 3]
            if (
                data_offset is None
                or loc & 0xBC != 0x84
                or spec not in (0x10, 0x12, 0x14, 0x16)
            ):
                raise ValueError(
                    f"{path}: unsupported MASM fixup {record[i:i+3].hex()}"
                )
            yield data_offset + ((loc & 3) << 8) + offset, not bool(loc & 0x40)
            i += 3
            for _ in range(2):  # group index and target index
                i += 2 if record[i] & 0x80 else 1
            if not spec & 4:
                i += 2  # explicit target displacement


selectors = {symbols[n] for n in ("dos_open", "dos_create", "dos_read", "dos_write")}
for name, origin in [
    ("fcbio", start),
    ("fcbio2", symbols["getrr"]),
    ("search", symbols["$find_first"]),
    ("rename", symbols["hma_localrename"]),
    ("create", symbols["hma_create"]),
    ("open", symbols["hma_open"]),
    ("dircall", symbols["hma_dos_mkdir"]),
    ("disk", symbols["hma_read"]),
    ("disk2", symbols["setup"]),
    ("disk3", symbols["diskwrite"]),
    ("isearch", symbols["hma_localfirst"]),
    ("dir", symbols["hma_findentry"]),
    ("dir2", symbols["hma_getpath"]),
    ("mknode", symbols["hma_builddir"]),
    ("rom", symbols["fndclus"]),
    ("fcb", symbols["hma_makefcb"]),
    ("file", symbols["hma_$open"]),
    ("macro2", symbols["hma_transfcb"]),
    ("fat", symbols["hma_iseof"]),
]:
    for within, relative in object_fixups(dos / (name + ".obj")):
        address = origin + within
        if not start <= address < end - 1:
            raise ValueError(f"{name}: relocation outside movable code at {address:x}")
        off = address - start
        value = int.from_bytes(image[address : address + 2], "little")
        if relative:
            target = (address + 2 + value) & 0xFFFF
            if start <= target < end:
                continue
            if image[address - 1] not in (0xE8, 0xE9):
                raise ValueError(f"unexpected branch at {address:x}")
            low_relative.append(off)
            upper[off : off + 2] = word(bridge(target) - off - 2)
        elif (
            name in ("fcbio", "fcbio2")
            and value in selectors
            and image[address - 1] in (0xBF, 0xB9)
        ):
            if value in (symbols["dos_read"], symbols["dos_write"]):
                body = "hma_read" if value == symbols["dos_read"] else "hma_write"
                upper[off : off + 2] = word(base + symbols[body] - start)
            else:
                upper[off : off + 2] = word(base + bridge(value))
vectors = ("read", "write", "open", "create", "getpath", "getpathnoset", "makefcb", "nametrans", "packname",
           "findentry", "srch", "nextent", "metacompare", "getentry", "getent",
           "setdirsrch", "startsrch", "matchattributes", "localfirst", "localnext", "rename_next",
           "iseof", "unpack", "pack", "allocate", "figrec",
           "newdir", "setdotent", "makenode", "localrename", "doopen", "dos_mkdir", "dos_chdir", "dos_rmdir")
# 78 and 79 are DOS find-first/find-next entry points.
extra_vectors = (
    "transfcb", "transpath", "transpathset", "transpathnoset", "skipback", "splice", "pathsepgotch",
    "$open", "$open2", "$creat", "$chmod", "$unlink", "$rename", "$createnewfile", "$createtempfile",
    "$extended_open",
)
slots = [(fn, name, "hma_" + name)
         for fn, name in (*enumerate(vectors, 41), *enumerate(extra_vectors, 80))]
# Each module supplies its own zero-terminated list of (vector, body) pairs.
module_pos = symbols["doscodemodules"]
linked_slots = []
while pos := struct.unpack_from("<H", image, module_pos)[0]:
    while vector := struct.unpack_from("<H", image, pos)[0]:
        body = struct.unpack_from("<H", image, pos + 2)[0]
        stub = struct.unpack_from("<H", image, vector)[0]
        if image[stub:stub + 2] != b"\x50\xb4" or not code_start <= body < end:
            raise ValueError(f"invalid linked DOSCODE entry at {pos:x}")
        linked_slots.append((image[stub + 2], vector, body - start))
        pos += 4
    module_pos += 2
table = [0] * (1 + max(max(entries), slots[-1][0], *(fn for fn, _, _ in linked_slots)))
lowentries = []
for fn in entries:
    pos = symbols["dispatch"] + 2 * fn
    target = int.from_bytes(image[pos : pos + 2], "little") - start
    assert 0 <= target < len(native)
    lowentries.extend([pos, target])
    table[fn] = target
lowvectors = []
for fn, name, body in slots:
    table[fn] = symbols[body] - start
    if not 0 <= table[fn] < len(native):
        raise ValueError(f"{name}: entry outside movable code")
    vector = symbols[name + "_vector"]
    if fn >= 80:
        stub = int.from_bytes(image[vector : vector + 2], "little")
        if image[stub : stub + 3] != bytes((0x50, 0xb4, fn)):  # PUSH AX / MOV AH,selector
            raise ValueError(f"{name}: selector differs from HmaEntry")
    lowvectors.extend([vector, table[fn]])
for fn, vector, offset in linked_slots:
    if fn in entries or any(fn == old for old, _, _ in slots):
        raise ValueError(f"duplicate gateway selector {fn}")
    lowvectors.extend([vector, offset])
    table[fn] = offset
    entries.append(fn)
for fn in entries + [fn for fn, _, _ in slots]:
    target = table[fn]
    table[fn] = len(upper) + base
    upper.extend(b"\xe8" + word(target - len(upper) - 3) + b"\xcb")


def rows(op, vals):
    return "\n".join(
        "        " + op + " " + ",".join(map(str, vals[n : n + 12]))
        for n in range(0, len(vals), 12)
    )


def export(label, kind, vals):
    return (
        f"        PUBLIC {label}\n{label} LABEL {kind}\n"
        + rows("DB" if kind == "BYTE" else "DW", vals)
        + "\n"
    )


out = "SYSINITSEG SEGMENT PUBLIC 'SYSTEM_INIT'\n"
if upper[legacy_length:len(native)] != native[legacy_length:]:
    raise ValueError("DOSCODE differs between placements")
out += export("FcbNative", "BYTE", native[:legacy_length])
out += export("FcbUpper", "BYTE", upper[:legacy_length])
out += export("FcbBridges", "BYTE", upper[len(native):])
out += export("FcbRelative", "WORD", low_relative + [65535])
out += export("FcbSegments", "WORD", segments + [65535])
out += export("FcbVectors", "WORD", lowvectors)
out += export("FcbEntries", "WORD", lowentries + [65535])
out += "SYSINITSEG ENDS\nEND\n"
bios = root / "kernel/bios"
sizes = (
    "\n".join(
        f"{k} EQU {v}"
        for k, v in {
            "FcbLength": len(native),
            "FcbLegacyLength": legacy_length,
            "FcbHiLength": len(upper),
            "FcbLinked": start,
            "FcbGatePtr": symbols["fcb_gate"],
            "FcbEntryIP": symbols["fcb_entry"],
            "CallbackPtr": symbols["doscallbackptr"],
            "NativeCallback": symbols["doscallbacklow"],
            "LowReturn": symbols["fcbreturn"],
        }.items()
    )
    + "\n"
)
outputs = {
    "fcbpack.asm": out,
    "fcbsizes.inc": sizes,
    "fcbtable.inc": rows("DW", table) + "\n",
}
output = sys.argv[1]
(bios / output).write_text(outputs[output])
