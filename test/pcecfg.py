"""Bind the test PCE configuration to a prepared scratch floppy."""
from pathlib import Path
import os
import re
import sys

root = Path(__file__).resolve().parents[1]


def write_config(folder, *hard_disks, readonly_boot=False):
    folder = Path(folder).resolve()
    boot = folder / "boot.img"
    if not boot.is_file():
        raise FileNotFoundError(boot)
    config = Path(os.environ.get("PCE_TEST_CONFIG", root / "test/msdos-high.cfg")).read_text()
    # Replace only the file field of drive A, regardless of its default image.
    drive_a = r'(?ms)(^disk\s*\{\s*drive\s*=\s*0x00\s*\n[^}]*?^\s*file\s*=\s*)"[^"]*"'
    boot_file = f'"{boot}"'
    if readonly_boot:
        boot_file += '\n readonly = 1'
    config, count = re.subn(drive_a, lambda m: m[1] + boot_file, config)
    if count != 1:
        raise ValueError("expected exactly one drive A in the test configuration")
    for old, new in [('"rom"', f'"{root}/rom"'), ('"fd1.img"', f'"{folder}/b.img"')]:
        config = config.replace(old, new)
    for name in ("ser1.out", "par1.out", "par2.out"):
        config = config.replace("file=" + name, f"file={folder / name}")
    for drive, hard_disk in enumerate(hard_disks, 0x80):
        disk = Path(hard_disk).resolve(strict=True)
        config += f'\ndisk {{\n drive = {drive:#x}\n type = "auto"\n file = "{disk}"\n}}\n'
    (folder / "pce.cfg").write_text(config)


if __name__ == "__main__":
    write_config(*sys.argv[1:], readonly_boot=os.environ.get("PCE_TEST_BOOT_READONLY") == "1")
