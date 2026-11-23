"""Build the DOS layout and I/O probe against the current kernel maps."""
import os
import re
import shutil
import subprocess


def install_probe(root, folder, image):
    shutil.copyfile(root / "test/hmaio.asm", folder / "hmaio.asm")

    def map_symbols(path):
        return {
            name: int(offset, 16)
            for offset, name in re.findall(
                r"[0-9A-F]{4}:([0-9A-F]{4}) +(\S+)", path.read_text()
            )
        }

    dos = map_symbols(root / "kernel/dos/msdos.map")
    bios = map_symbols(root / "kernel/bios/msbio.map")
    (folder / "hma.inc").write_text(
        f"ShareTable EQU {dos['JShare']}\n"
        f"OpenSlot EQU {dos['DISPATCH'] + 30}\nEntryIP EQU {dos['FCB_ENTRY']}\n"
        f"GateSeg EQU {dos['FCB_GATE'] + 2}\nBodyOff EQU {bios['GateBody'] - bios['GateStart']}\n"
    )
    env = dict(os.environ, EMU2_DRIVE_C=str(folder))
    for tool, args in (
        ("masm", "hmaio.asm,hmaio.obj;"),
        ("link", "hmaio.obj,hmaio.exe,nul;"),
    ):
        subprocess.run(
            ["emu2", root / f"sdk/bin/{tool}.exe", args],
            env=env,
            cwd=folder,
            check=True,
        )
    subprocess.run(["mcopy", "-o", "-i", image, folder / "hmaio.exe", "::HMAIO.EXE"], check=True)
