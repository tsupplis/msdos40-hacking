# MS-DOS 4.01 rebuild

A from-source rebuild of MS-DOS 4.01 on a modern Unix host, with the aim of patching it into a usable replacement for DOS 3.3.
It builds with GNU make, using the original vintage tools under `emu2`, and the floppy images boot under PCE (`pce-ibmpc`).

## 1. Summary of the sources

The sources come from <https://github.com/lotharsm/MS-DOS/tree/dos-4.01-reconstructed>, a fork of [microsoft/MS-DOS](https://github.com/microsoft/MS-DOS).
The reconstruction of 4.01 on top of the released 4.00 sources is by **hharte**.

- The upstream repository holds the MS-DOS 1.25, 2.0 and 4.0 sources (4.0 was developed jointly by IBM and Microsoft), released under the MIT License (see `LICENSE.md`).
- The 4.00 tree contains the kernel, the command interpreter, the external commands, the device drivers and the `select` installer.
- The 4.01 reconstruction changes 29 files of that tree.
  17 of them differ only in character encoding; the other 12 are real changes (section 2).

Layout of this repository:

| Directory | Content |
|---|---|
| `boot/` | boot sector |
| `kernel/bios/`, `kernel/dos/` | `IO.SYS`, `MSDOS.SYS` |
| `kernel/<driver>/` | device drivers and code pages (`ansi`, `country`, `display`, `keyboard`, `printer`, `driver`, `ramdrive`, `smartdrv`, `vdisk`, `xma2ems`, `xmaem`, `memm`) |
| `commands/` | `COMMAND.COM`, 37 external commands, `select` |
| `common/`, `mapper/`, `messages/` | shared objects, `mapper.lib`, message files |
| `asminc/`, `include/` | assembler includes, C headers |
| `sdk/` | the vintage build tools (`bin/`), C runtime headers and libraries |
| `media/` | floppy image rules (`msdos40_base.img`, `msdos40_dist.img`, `msdos40_full.img`) |

## 2. 4.01 fixes understood

What the 12 real changes do, taken from the diff between the 4.00 and 4.01 trees.
The first column says how much is known: **diff** = stated by the diff itself, **inferred** = my reading of the surrounding code, not tested.

| File | Change | |
|---|---|---|
| `messages/usa-ms.msg` | The start-up banner and the `VER` text say 4.01 instead of 4.00. | diff |
| `commands/command/tcmd2a.asm` | `VER` adds one to the minor version it got from DOS before printing it. | diff |
| `commands/command/tranmsg.asm` | The minor-version field of the `VER` message gets the `Right_Align` flag (2 wide, `0` padded). | diff; effect inferred |
| `kernel/dos/dev.asm` | The high word of the saved current sector is read from `HIGH_SECTOR` instead of from the word after `CALLSSEC`. | diff; effect (sector numbers above 16 bits) inferred |
| `commands/format/format.asm` | The high word of the sector number is tested as well as the low word, in two places. 4.00 compared only the low word. | diff |
| `commands/fastopen/fastseek.asm` | The truncate path no longer returns at once with `DI = 0`; it walks the chain of extents (`EH_COUNT`) until the last one. | diff; effect inferred |
| `kernel/dos/ctrlc.asm` | The call that restores the user's EMS map (`RESTORE_USER_MAP`, under `BUFFERFLAG`) is removed from the Ctrl-C path. | diff |
| `kernel/bios/msinit.asm` | Disk compatibility only. A disk formatted by another system carries an "OEM name" in its first sector (`MSDOS4.0`, `IBM  3.3`, ...). DOS reads that name to decide whether the disk's geometry table can be trusted. 4.01 adds one more name pattern, `10.` right after the 7-character prefix (such as `OS2 10.1`, apparently an OS/2 1.x-era format), and accepts such disks. No effect on disks made by this build (`MSDOS4.0`). | diff; the OS/2 link is inferred |
| `commands/select/panels.asm`, `scroll.asm`, `usa.inf` | The panel border characters are restored to the right CP437 bytes. | diff |
| `setenv.bat` | Build environment of the original tree (paths for the vintage tools). Not used here: the Makefiles replace it, and the file is removed. | diff |

The other 17 files (`select`, `kernel/display/int10com.inc`, `mapper/getmsg.asm` and others) differ only in character encoding.
The 4.00 copies had CP437 box-drawing bytes replaced by U+FFFD, which stops `select` from assembling (MASM `A2106`).
The 4.01 files carry the correct bytes.

`asminc/versiona.inc` still defines `minor_version equ 00`: the 4.01 diff does not touch it.
The "4.01" shown by the banner and by `VER` comes from the message file and the `VER` change above; 

## 3. Changes after 4.01

Everything in this section is a change made to this tree after the 4.01 reconstruction, with the evidence for it.
Section 2 is what 4.01 changed; this section is what we changed afterwards.
Each change is a source edit marked `PD0255` in a comment, so `grep -rn PD0255` lists them.

### 3.1 Microsoft PD0255 "MS-DOS 4.0X patch disk" (revision 8/92)

| Patch | Component | Fix | Source |
|---|---|---|---|
| PD0255 | `MSDOS.SYS` | Directory zeroing carries into the high sector word (`INC DX` became `ADD DX,1` / `ADC [HIGH_SECTOR],0`): directory table on a 32 MB boundary. | `kernel/dos/mknode.asm` |
| PD0255 | `MSDOS.SYS` | `DISKWRITE` saves `HIGH_SECTOR` before the zero-base decrement and rounds the sector count up in `DI`: append to a file near 32 MB. | `kernel/dos/disk3.asm` |
| PD0255 | `GRAPHICS.COM` | Multiplex number `15H` (MSCDEX's) changed to `0ACH`. | `commands/graphics/grint2fh.asm` |
| PD0255 | `FASTOPEN.EXE`, `FORMAT.COM` | Nothing to apply: `FASTOPEN` is byte-identical to ours; `FORMAT` has identical code (2 non-functional bytes differ). | none |

The rebuilt `msdos.sys` and `graphics.com` are byte-identical to the PD0255 files. Not run-tested.

### 3.2 IBM PC DOS 4.00 CSD UR31300 fixes

| APAR | Component | Fix | Source |
|---|---|---|---|
| IR80263 | `ANSI.SYS` | Select the BIOS alternate print screen (INT 10h `AH=12h BL=20h`) when more than 25 rows are set, not at load, so Shift-PrtSc works. | `kernel/ansi/ioctl.asm`, `ansiinit.asm` |
