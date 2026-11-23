"""Build SYSINIT relocation data from the linked MASM kernel."""

from pathlib import Path
import re
import struct
import sys

root = Path(__file__).resolve().parents[2]
dos = root / "kernel/dos"
image = (dos / "msdos.sys").read_bytes()
symbols = {
    name.lower(): int(addr, 16)
    for addr, name in re.findall(
        r"0000:([0-9A-F]{4}) +([^\s]+)", (dos / "msdos.map").read_text()
    )
}
start = symbols["$get_fcb_position"]
end = symbols["hmaioend"]
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
    ("create", symbols["hma_create"]),
    ("open", symbols["hma_open"]),
    ("disk", symbols["hma_read"]),
    ("disk2", symbols["setup"]),
    ("disk3", symbols["diskwrite"]),
    ("dir2", symbols["hma_getpath"]),
    ("fcb", symbols["hma_makefcb"]),
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
vectors = ("read", "write", "open", "create", "getpath", "getpathnoset", "makefcb", "nametrans", "packname")
table = [0] * (max(entries) + 1)
lowentries = []
for fn in entries:
    pos = symbols["dispatch"] + 2 * fn
    target = int.from_bytes(image[pos : pos + 2], "little") - start
    assert 0 <= target < len(native)
    lowentries.extend([pos, target])
    table[fn] = target
lowvectors = []
for fn, name in enumerate(vectors, 41):
    table[fn] = symbols["hma_" + name] - start
    lowvectors.extend([symbols[name + "_vector"], table[fn]])
for fn in entries + list(range(41, 41 + len(vectors))):
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
out += export("FcbNative", "BYTE", native)
out += "        ALIGN 16\n" + export("FcbUpper", "BYTE", upper)
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
            "FcbHiLength": len(upper),
            "FcbLinked": start,
            "FcbGatePtr": symbols["fcb_gate"],
            "FcbEntryIP": symbols["fcb_entry"],
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
