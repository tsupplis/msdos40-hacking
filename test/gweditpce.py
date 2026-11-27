"""Compare live GW-BASIC editor screens and BIOS cursor positions in one PCE boot."""
import os
import subprocess
import time

from pcecfg import write_config


# Cases exercised at the live Ok prompt. The audit supplies the same input
# sequences to its historical and PCE runners.
cases = {294, 295, 297, 299, 301, 389, 390}


def key_names(sequence):
    for part in sequence.split("|"):
        if part.startswith("ctrl-"):
            yield "+Ctrl " + part[5:] + " -Ctrl"
        elif part.isupper():
            for char in part:
                yield "Space" if char == " " else "+Shift " + char.lower() + " -Shift"
        else:
            yield part


def editor_results(folder, boot, data, sequences, put, read):
    batch = ["@echo off", "b:"]
    for version in ("ref", "exe"):
        for case in sequences:
            program = f"{version}{case}.bas"
            if case == 301:
                # Read the expansion of each BIOS function key before entering direct mode.
                body = (f'10 OPEN "{version}.KEY" FOR OUTPUT AS #1:FOR F=1 TO 10\n'
                        '20 DEF SEG=&H40:POKE 26,30:POKE 28,30:POKE 30,0:POKE 31,58+F:POKE 28,32:DEF SEG\n'
                        '30 A$=INKEY$:IF LEN(A$) THEN PRINT #1,ASC(A$);:GOTO 30\n'
                        '40 PRINT #1,:NEXT:CLOSE:SYSTEM\n')
                put(data, folder, version + "key.bas", body)
                batch.append(f"{version} {version}key.bas")
            put(data, folder, program, f'10 KEY OFF:CLS:PRINT "{version[0].upper()}{case:04d}":END\n')
            batch.append(f"{version} {program}")
    put(boot, folder, "autoexec.bat", "\n".join(batch + ["echo EDIT-DONE"]) + "\n")
    data.rename(folder / "b.img")
    write_config(folder)
    pce = os.environ.get("PCE_HEADLESS") or "pce-ibmpc"
    with (folder / "editor.log").open("wb") as log, subprocess.Popen(
        [pce, "-c", "pce.cfg", "-t", "null", "-g", "vga"], cwd=folder,
        stdin=subprocess.PIPE, stdout=log, stderr=log, text=True
    ) as vm:
        def send(cmd):
            vm.stdin.write(cmd + "\n")
            vm.stdin.flush()

        def snapshot(cycles):
            # The cursor dump is written last and signals completion of both saves.
            cursor = folder / "cursor.bin"
            cursor.unlink(missing_ok=True)
            send(f'c {cycles}\nsave "screen.bin" bin b800:0 fa0\nsave "cursor.bin" bin 40:50 2')
            deadline = time.monotonic() + 5
            while not cursor.exists() or cursor.stat().st_size != 2:
                if vm.poll() is not None or time.monotonic() >= deadline:
                    raise RuntimeError("PCE monitor did not complete the screen capture")
                time.sleep(.005)
            cells = (folder / "screen.bin").read_bytes()[0:3840:2].decode("cp437")
            return {"screen": "\n".join(cells[i:i+80].rstrip() for i in range(0, len(cells), 80)).rstrip(),
                    "cursor": list(cursor.read_bytes())}

        def expect(marker):
            deadline = time.monotonic() + 10
            while True:
                obs = snapshot(200000)
                if marker in obs["screen"]:
                    return
                if time.monotonic() >= deadline:
                    raise RuntimeError(f"Expected {marker!r}, last capture {obs!r}")

        def key(name):
            send(f"key {name}\nc 20000")

        try:
            results = [[], []]
            for version, observations in zip(("ref", "exe"), results):
                for case, sequence in sequences.items():
                    ready = f"{version[0].upper()}{case:04d}"
                    expect(ready + "\nOk")
                    intermediate = []
                    for name in key_names(sequence):
                        key(name)
                        if case in (294, 295, 297) and name in ("+Shift x -Shift", "up"):
                            step = snapshot(100000)
                            step["screen"] = step["screen"].replace(ready, "READY", 1)
                            intermediate.append(step)
                    if case == 301:
                        expect("Ok")  # F10 executes SCREEN and returns to direct mode.
                    obs = snapshot(200000)
                    obs["screen"] = obs["screen"].replace(ready, "READY", 1)
                    if intermediate:
                        obs["steps"] = intermediate
                    observations.append(obs)
                    key("Return")
                    for name in "system":
                        key(name)
                    key("Return")
            expect("EDIT-DONE")
        finally:
            if vm.poll() is None:
                try:
                    send("quit")
                    vm.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    vm.kill()
                    vm.wait()
    if 301 in sequences:
        index = list(sequences).index(301)
        for version, observations in zip(("ref", "exe"), results):
            report = read(folder / "b.img", version + ".KEY")
            if report is None or len(report.splitlines()) != 10:
                raise RuntimeError(f"Incomplete {version} function key report")
            observations[index]["macros"] = [bytes(map(int, row.split())).decode("ascii")
                                               for row in report.splitlines()]
    return results
