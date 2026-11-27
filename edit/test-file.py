"""Exercise the DOS executable and the allocation/I/O failure build under emu2."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as folder:
    work = Path(folder)
    drive = work / "b"
    drive.mkdir()
    target = drive / "edit.txt"
    env = dict(os.environ, EMU2_DRIVE_B=str(drive), EMU2_DRIVE_C=folder)

    def run(program, *args):
        return subprocess.run(["emu2", str(root / program), *args], cwd=work,
                              env=env, capture_output=True, timeout=20)

    for mode in [0, 1, 2, *range(10, 14), 16, 17]:
        original = b"first\r\nlast\x1a"
        target.write_bytes(original)
        p = run("testfile.exe", str(mode))
        assert p.returncode == 0 and b"EDIT PASS" in p.stdout, (mode,p)
        assert target.read_bytes() == (original if mode else b"saved\r\nlast\x1a")

    for mode, data in [(31, b"first\r\nlast\x1a"),
                       (32, (b"a"*999+b"\n"+b"b"*998+b"\r\n")*40)]:
        target.write_bytes(data)
        p = run("testfile.exe", str(mode))
        assert p.returncode == 0 and b"EDIT PASS" in p.stdout, p
        assert target.read_bytes() == data

    for mode in (33, 34, 36, 37, 38, 39, 40):
        target.unlink(missing_ok=True)
        if mode == 39:
            target.write_bytes(b"aa\na")
        if mode == 40:
            target.write_bytes(b"a\r\n" + b"a"*32766)
        if mode == 38:
            target.write_bytes(b"first\nlast")
        if mode == 33:
            target.write_bytes(b"first")
        if mode == 34:
            target.write_bytes(b"a"*32000)
        p = run("testfile.exe", str(mode))
        assert p.returncode == 0 and b"EDIT PASS" in p.stdout, p
        if mode == 39:
            assert target.read_bytes() == b"\n"
        if mode == 34:
            assert target.read_bytes() == (b"\r\na\r\n"*50 + b"a"*31950)
        assert not list(drive.glob("*.tmp"))

    for data in (b"a\0b", b"a\x1ab", b"x"*32767):
        target.write_bytes(data)
        p = run("edit.exe", "B:EDIT.TXT")
        assert p.returncode == 1 and b"Cannot load complete" in p.stderr, p
        assert target.read_bytes() == data

    # Same compiler, runtime and document implementation as EDIT. Find the
    # last complete load in whole rows for two explicitly sized workloads.
    for width in (78, 1022):
        low, high = 0, 700000//(width+2)
        while high-low > 1:
            count = (high+low)//2
            target.write_bytes((b"x"*width+b"\r\n")*count)
            p = run("testfile.exe","30")
            assert p.returncode in (0,2), p
            if p.returncode == 0:
                low = count
            else:
                high = count
        assert low*(width+2) > 65536
        print(f"{width}-byte lines: {low*(width+2):,} bytes loaded, "
              f"{high*(width+2):,} refused")
print("EDIT file, allocation and I/O checks passed")
