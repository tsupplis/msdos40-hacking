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
end = symbols["doscodeend"]
# LINK supplies the placement-independent suffix shared by both boot layouts.
segment = re.search(r"^ +([0-9A-F]+)H +[0-9A-F]+H +([0-9A-F]+)H +DOSCODE +DOSCODE", link_map, re.M)
if not segment:
    raise ValueError("missing DOSCODE segment")
code_start, code_length = (int(value, 16) for value in segment.groups())
if code_start + code_length != end:
    raise ValueError("DOSCODE must end at DosCodeEnd")
# Each module supplies its own zero-terminated list of (vector, body) pairs.
module_pos = symbols["doscodemodules"]
far_entries = {}
near_vectors = []
while pos := struct.unpack_from("<H", image, module_pos)[0]:
    while vector := struct.unpack_from("<H", image, pos)[0]:
        body = struct.unpack_from("<H", image, pos + 2)[0]
        stub = struct.unpack_from("<H", image, vector)[0]
        if image[stub:stub + 2] != b"\x50\xb4" or not code_start <= body < end:
            raise ValueError(f"invalid linked DOSCODE entry at {pos:x}")
        selector = image[stub + 2]
        if selector in far_entries:
            raise ValueError(f"duplicate gateway selector {selector}")
        offset = body - code_start
        far_entries[selector] = 0x100 + offset
        near_vectors.extend((vector, offset))
        pos += 4
    module_pos += 2


def words(values):
    """Emit at most twelve words per MASM source line."""
    return "".join(
        "        DW " + ",".join(map(str, values[i:i + 12])) + "\n"
        for i in range(0, len(values), 12)
    )


# The far gateway indexes by selector. Unassigned selectors have zero entries.
table = [far_entries.get(i, 0) for i in range(max(far_entries) + 1)]
sizes = {
    "FcbLength": code_length,
    "FcbLinked": code_start,
    "FcbGatePtr": symbols["fcb_gate"],
    "FarReturnIP": 0x100 + symbols["doscodefarreturn"] - code_start,
    "CallbackPtr": symbols["doscallbackptr"],
    "NativeCallback": symbols["doscallbacklow"],
    "LowReturn": symbols["fcbreturn"],
}
outputs = {
    "fcbpack.asm": (
        "SYSINITSEG SEGMENT PUBLIC 'SYSTEM_INIT'\n"
        "        PUBLIC FcbVectors\nFcbVectors LABEL WORD\n"
        + words(near_vectors + [65535])
        + "SYSINITSEG ENDS\nEND\n"
    ),
    "fcbsizes.inc": "".join(f"{name} EQU {value}\n" for name, value in sizes.items()),
    "fcbtable.inc": words(table),
}
output = sys.argv[1]
Path(__file__).with_name(output).write_text(outputs[output])
