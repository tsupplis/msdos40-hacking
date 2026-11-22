# MS-DOS 4.01 rebuild

A from-source rebuild of MS-DOS 4.01 on a modern Unix host, with the aim of patching it into a usable replacement for DOS 3.3.
It builds with GNU make, using the original vintage tools under `emu2`, and the floppy images boot under PCE (`pce-ibmpc`).

## 1. Summary of the sources

The sources come from <https://github.com/lotharsm/MS-DOS/tree/dos-4.01-reconstructed>, a fork of [microsoft/MS-DOS](https://github.com/microsoft/MS-DOS).
The reconstruction of 4.01 on top of the released 4.00 sources is by **hharte**.

- The upstream repository holds the MS-DOS 1.25, 2.0 and 4.0 sources (4.0 was developed jointly by IBM and Microsoft), released under the MIT License (see [license.md](LICENSE.md)).
- The 4.00 tree contains the kernel, the command interpreter, the external commands, the device drivers and the `select` installer.
- The 4.01 reconstruction changes 29 files of that tree.
  17 of them differ only in character encoding; the other 12 are real changes (section 2).

Layout of this repository:

| Directory | Content |
|---|---|
| `boot/` | boot sector |
| `kernel/bios/`, `kernel/dos/` | `io.sys`, `msdos.sys` |
| `kernel/<driver>/` | device drivers and code pages (`ansi`, `country`, `display`, `keyboard`, `printer`, `driver`, `ramdrive`, `smartdrv`, `vdisk`, `xma2ems`, `xmaem`, `memm`) |
| `commands/` | `command.com`, 37 external commands, `select` |
| `common/`, `mapper/`, `messages/` | shared objects, `mapper.lib`, message files |
| `asminc/`, `include/` | assembler includes, C headers |
| `sdk/` | the vintage build tools (`bin/`), C runtime headers and libraries |
| `media/` | floppy image rules (`msdos40_base.img`, `msdos40_dist.img`, `msdos40_full.img`) |

## 2. 4.01 fixes understood

What the 12 real changes do, taken from the diff between the 4.00 and 4.01 trees.
The first column says how much is known: **diff** = stated by the diff itself, **inferred** = my reading of the surrounding code, not tested.

| File | Change | |
|---|---|---|
| `messages/usa-ms.msg` | The start-up banner and the `ver` text say 4.01 instead of 4.00. | diff |
| `commands/command/tcmd2a.asm` | `ver` adds one to the minor version it got from DOS before printing it. | diff |
| `commands/command/tranmsg.asm` | The minor-version field of the `ver` message gets the `Right_Align` flag (2 wide, `0` padded). | diff; effect inferred |
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
The "4.01" shown by the banner and by `ver` comes from the message file and the `ver` change above.

## 3. Changes after 4.01

Everything in this section is a change made to this tree after the 4.01 reconstruction, with the evidence for it.
Section 2 is what 4.01 changed; this section is what we changed afterwards.
The Microsoft patch changes are marked `PD0255` in a comment, so `grep -rn PD0255` lists them.

### 3.1 Microsoft PD0255 "MS-DOS 4.0X patch disk" (revision 8/92)

| Patch | Component | Fix | Source |
|---|---|---|---|
| PD0255 | `msdos.sys` | Directory zeroing carries into the high sector word (`INC DX` became `ADD DX,1` / `ADC [HIGH_SECTOR],0`): directory table on a 32 MB boundary. | `kernel/dos/mknode.asm` |
| PD0255 | `msdos.sys` | `DISKWRITE` saves `HIGH_SECTOR` before the zero-base decrement and rounds the sector count up in `DI`: append to a file near 32 MB. | `kernel/dos/disk3.asm` |
| PD0255 | `graphics.com` | Multiplex number `15H` (mscdex's) changed to `0ACH`. | `commands/graphics/grint2fh.asm` |
| PD0255 | `fastopen.exe`, `format.com` | Nothing to apply: `fastopen` is byte-identical to ours; `format` has identical code (2 non-functional bytes differ). | none |

Before UMB support was added, with historical line editing selected, the rebuilt `msdos.sys` and `graphics.com` are byte-identical to the PD0255 files. Not run-tested.

### 3.2 IBM PC DOS 4.00 CSD UR31300 fixes

| APAR | Component | Fix | Source |
|---|---|---|---|
| IR80263 | `ansi.sys` | Select the BIOS alternate print screen (INT 10h `AH=12h BL=20h`) when more than 25 rows are set, not at load, so Shift-PrtSc works. | `kernel/ansi/ioctl.asm`, `ansiinit.asm` |

### 3.3 Command-line editing

At the DOS prompt, Left and Right move one character, Home and End move to either end, and Ins toggles between insert (the default) and overwrite. Del removes the character under the cursor. Backspace or Ctrl-H removes the character to its left. Enter submits the whole line from any cursor position. Esc discards the current edit.

On an empty line, Up recalls the previous line supplied by the caller. Down is ignored. command.com and programs using buffered console input (`INT 21h/AH=0Ah`, including `AH=0Ch/AL=0Ah`) share this editor. Cooked console handle reads also support cursor editing, with Up disabled because their buffer belongs to DOS. Raw input, redirected streams, and programs with their own editors retain their existing behaviour.

Set `LINEEDIT EQU 0` in `kernel/dos/editsw.inc` and run `make dist` for historical line editing. The default IBM single-byte build reuses the DOS input buffer and adds 640 bytes to the linked kernel. Run `test/check_edit` after building to exercise the editor in PCE. The distribution archive `disks.zip` at the repository root contains the base, dist and full floppy images.

### 3.4 Command enhancements

| Command | Enhancement |
|---|---|
| `more` | `more filename` pages a file directly. With no filename, `more` reads standard input. |
| `loadhigh`, `lh` | Loads an external program into upper memory when it fits. |

### 3.5 Upper memory blocks

On PCE, place the provider on the boot disk and add these lines to `config.sys`:

```dos
dos=umb
device=pcehimem.sys
```

DOS claims the available XMS upper memory blocks during boot. Programs can query or change the UMB link state with `INT 21h/AX=5802h` and `5803h`. While linked, allocation strategies `40h–42h` select upper memory only and `80h–82h` try upper memory first. Programs should restore both settings after use.

---

## Companion projects

| Project | Description |
|---------|-------------|
| [cpm86-kernel](https://github.com/tsupplis/cpm86-kernel)     | CP/M-86 1.1 distribution rebuilt from patched and reconstituted sources |
| [ccpm86-kernel](https://github.com/tsupplis/ccpm86-kernel)         | CCP/M-86 3.1 distribution rebuilt from patched and reconstituted sources |
| [cdos41-kernel](https://github.com/tsupplis/cdos41-kernel)         | Concurrent DOS 4.1 distribution rebuilt from patched and reconstituted sources |
| [cpm86-kernel](https://github.com/tsupplis/cpm86-kernel)     | CP/M-86 1.1 distribution rebuilt from patched and reconstituted sources |
| [cpm86-crossdev](https://github.com/tsupplis/cpm86-crossdev) | Unix CP/M-86 cross development project (compilers, emulation and tools) |
| [cpm86-hacking](https://github.com/tsupplis/cpm86-hacking)   | CP/M-86 miscellaneous tools and PCE emulator helpers |
| [cpm86-cmdtools](https://github.com/tsupplis/cpm86-cmdtools) | CP/M-86 `.cmd` file manipulation tools |
| [cpm86-ports](https://github.com/tsupplis/cpm86-ports)       | CP/M-86 application ports in C and assembler |
| [cpm86-vi](https://github.com/tsupplis/cpm86-vi)             | STevie vi port for CP/M-86 and PC-DOS |
| [cpm86-msbasic](https://github.com/tsupplis/cpm86-msbasic)   | A recreaction of msbasic-86 for CP/M-86 and PC-DOS 1.1 from gwbasic sources |
| [cpm86-menu](https://github.com/tsupplis/cpm86-menu)   | A submit replacement and a menu system for submit orchestration for CP/M-86 1.1 |
| [cpm86-make](https://github.com/tsupplis/cpm86-make)   | A simple submit based make tool for CP/M-86 |
| [pcdos11-hacking](https://github.com/tsupplis/pcdos11-hacking) | PC-DOS 1.1 distribution, tools and notes |
| [msdos40-hacking](https://github.com/tsupplis/msdos40-hacking) | MS-DOS 4.0 distribution, tools and notes |

---

## License

The whole repository is under MIT [License](LICENSE.md) unless specified otherwise in a subdirectory.
