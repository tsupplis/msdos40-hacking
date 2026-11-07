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
- `asminc/` — Assembler include files and macros (from `inc/`)
- `include/` — C header files (from `h/`)
- `common/` — Shared compilation units (`nibdos`, `const2`, `msdata`, etc.)
- `messages/` — System messages (`usa-ms.msg`)
- `mapper/` — `mapper.lib` sources
- `sdk/` — Vintage SDK & tools:
  - `bin/` — Vintage build executables (`masm`, `link`, `cl`, `exe2bin`, etc.)
  - `include/` — Vendor C runtime headers
  - `lib/` — Vendor C runtime libraries and prebuilt libraries
- `mk/` — Shared Makefile definitions and build rules
- `media/` — Master disk images and templates for floppy generation
- `rom/` — PCE ROM files (symlink / user-supplied)
- `build/` — Generated build outputs and disk images

## Build & Run

```sh
# Build everything
make

# Build and run in PCE emulator
make msdos
```
