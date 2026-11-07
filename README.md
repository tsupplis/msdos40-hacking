# MS-DOS 4.00 Rebuild

Source-based build of MS-DOS 4.00 for modern Unix systems using vintage tools running under `emu2` and PCE emulator (`pce-ibmpc`).

## Prerequisites

- **emu2** (DOS emulator for running vintage build tools)
- **pce-ibmpc** (PCE PC emulator for running disk images)
- **mtools** (`mformat`, `mcopy`, `mattrib`, `mdir`, `mdel`)
- **GNU Make** (>= 3.81)

## Directory Structure

- `boot/` — Boot sector sources (`msboot.asm`, `boot.skl`)
- `kernel/` — Kernel components:
  - `bios/` — `io.sys` (`msbio.exe`, `msload.com`)
  - `dos/` — `msdos.sys` (MS-DOS kernel)
  - `<driver>/` — Device drivers (`ansi`, `country`, `display`, `driver`, `keyboard`, `printer`, `ramdrive`, `smartdrv`, `vdisk`, `xma2ems`, `xmaem`, `memm`)
- `commands/` — External DOS commands (`command`, `attrib`, `format`, `fdisk`, `select`, etc.)
- `asminc/` — Assembler include files and macros
- `include/` — C header files
- `common/` — Shared compilation units (`nibdos`, `const2`, `msdata`, etc.)
- `messages/` — System messages (`usa-ms.msg`)
- `mapper/` — `mapper.lib` sources
- `sdk/` — Vintage SDK & tools:
  - `bin/` — Vintage build executables (`masm`, `link`, `cl`, `exe2bin`, etc.)
  - `include/` — Vendor C runtime headers
  - `lib/` — Vendor C runtime libraries and prebuilt libraries
- `media/` — Floppy image rules (mtools), `config.sys` and `autoexec.bat`; the images are generated here
- `rom/` — PCE ROM files (symlink / user-supplied)

## Build & Run

```sh
make              # build everything and the three floppy images in media/
make check        # build, then verify that every expected file is on the full image
make run          # build and boot media/msdos40_base.img in PCE (./msdos, msdos.cfg)
make clean
make -C commands/format     # any single directory builds on its own
```

Objects and binaries are built next to their sources (they are ignored by git).
The Makefiles are compatible with GNU make 3.81 (macOS `make`) and newer (`gmake`).
Builds are serial (`.NOTPARALLEL`): `cl.exe` under `emu2` shares temp files and fails with C1042 when run concurrently.

### Images (`media/`)

| Image | Content |
|---|---|
| `msdos40_base.img` | boot sector, `IO.SYS`, `MSDOS.SYS`, `COMMAND.COM` and the 37 external commands |
| `msdos40_dist.img` | base + drivers (`ansi`, `country`, `display`, `keyboard`, `printer`, `ramdrive`, `smartdrv`, `driver`, `vdisk`, `xma2ems`, `xmaem`, `emm386`), code pages, `select` files, `graphics.pro` |
| `msdos40_full.img` | dist + `CONFIG.SYS` and `AUTOEXEC.BAT` from `media/` |

`config.sys` deliberately loads no driver, so an untested driver cannot hang the boot.
The 1.44 MB image has about 260 KB free after the full file set.

### Environment

The old `setenv.bat` is replaced by the Makefiles: each exports `EMU2_DRIVE_C` (the repository root, seen as `C:`) and sets `INCLUDE`/`LIB`/`PATH` for `cl.exe` and `link.exe` on the command line. `COUNTRY` defaults to `usa-ms`.

### Sources

The tree is the released MS-DOS 4.00 source with the 4.01 changes applied (version 4.01, FORMAT/FASTOPEN high-sector fixes, SELECT panel fixes).
