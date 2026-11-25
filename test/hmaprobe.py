"""Build the DOS layout and I/O probe against the current kernel maps."""
import os
import re
import shutil
import subprocess


def install_probe(root, folder, image):
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
        f"DeviceName EQU {dos['NAME1']}\nDeviceAttr EQU {dos['ATTRIB']}\n"
        f"DevicePtr EQU {dos['DEVPT']}\nNullHeader EQU {dos['NULDEV']}\n"
        f"CurrentSFT EQU {dos['THISSFT']}\n"
        f"ShareTable EQU {dos['JShare']}\n"
        f"CallbackSeg EQU {dos['DosCallbackPtr'] + 2}\n"
        f"GateSeg EQU {dos['FCB_GATE'] + 2}\nBodyOff EQU {bios['GateBody'] - bios['GateStart']}\n"
    )
    install_asm_probe(root, folder, image, "hmaio")


def install_asm_probe(root, folder, image, name):
    shutil.copyfile(root / f"test/{name}.asm", folder / f"{name}.asm")
    env = dict(os.environ, EMU2_DRIVE_C=str(folder))
    for tool, args in (
        ("masm", f"{name}.asm,{name}.obj;"),
        ("link", f"{name}.obj,{name}.exe,nul;"),
    ):
        subprocess.run(
            ["emu2", root / f"sdk/bin/{tool}.exe", args],
            env=env,
            cwd=folder,
            check=True,
        )
    subprocess.run(["mcopy", "-o", "-i", image, folder / f"{name}.exe", f"::{name}.exe"], check=True)
