# MS-DOS 4.0 Rebuild Plan

## RESTART BRIEFING (read this first in a new context)

### How to resume
1. Work in **Agent mode**, workspace `/Users/thierry/Projects/DOS/msdos40-hacking`. Read this whole file.
2. Run **one sub-task at a time**, in order (sub-task 1 is next). After each: set its `Status` to `[x] done`, add any new facts under "Execution log" (bottom of file), then **stop and wait for the user's review**.
3. Do not touch anything outside the workspace. The sibling project `pcdos11-hacking` (the style reference) was copied in temporarily and then **deleted by the user**; its relevant conventions are captured below, do not look for it.
4. Binary assets are the user's job (ROMs, master disks, vintage tools). Never fabricate them; if something is missing, say so.
5. Validation expected before reporting a sub-task done: the checks listed in that sub-task's "Expected outcomes" (e.g. `find` shows no uppercase names, no dangling references from the grep checklist, `gmake -n` parses).

### Progress so far
- Planning finished and the user approved the plan with all defaults (items a-d in the last question: `kernel/memm`, `commands/select`, launcher/config renamed `msdos40`/`msdos40.cfg`, ROM names fixed in the cfg, per-command duplicate headers left local) and confirmed `common/` and `sdk/`.
- The user asked to run **sub-task 1 only, then stop for review**.
- **No file has been modified by the agent yet** (only read-only investigation was done for sub-task 1; the user did the earlier directory reshuffle by hand).

### Environment facts (verified)
- Host: macOS arm64, **APFS, case-INSENSITIVE** filesystem. Consequences: renaming `Makefile` -> `makefile` must be a two-step `mv Makefile makefile.tmp && mv makefile.tmp makefile` (a direct `mv` is a no-op or an error); `find -name '*[A-Z]*'` is the reliable way to list uppercase names; a case-folding bug in the build will NOT show up on this host, so keep every reference lowercase anyway for Linux portability.
- The workspace is **not a git repository** (`git status` fails), so use plain `mv`, not `git mv`, unless the user runs `git init` first. Ask before running `git init`.
- Tools found on PATH (the user confirms "all commands are on the path"): `emu2` (wrapper to `~/.local.darwin/emulators/cpm86-crossdev/bin/emu2.alt`, the emu2-cpm86 fork), `pce-ibmpc` (`~/.local.darwin/emulators/pce/bin/pce-ibmpc`), mtools (`mcopy mformat mattrib mdir mdel` in `/opt/homebrew/bin`), `gmake` 4.4.1 (`/opt/homebrew/bin`), `/usr/bin/make` is **GNU Make 3.81** (macOS default), `git`, `python3`, `nasm`.
  Decision: write the Makefiles to be **compatible with GNU make 3.81** (no `.ONESHELL`, no grouped targets `&:`, no `$(file ...)`, no `!=`), so both `make` and `gmake` work.
- Main externals: **emu2** (runs all vintage DOS build tools) and **PCE** (runs the result). **All compilation tools are inside the project** under `tools/` (to become `bin/`): `masm.exe link.exe lib.exe exe2bin.exe cl.exe c1.exe c1l.exe c2.exe c3.exe exec.exe convert.exe exefix.exe exemod.exe exepack.exe dbof.exe nosrvbld.exe buildmsg.exe buildidx.exe menubld.exe asc2hlp.exe attrib.exe compress.com nmake.exe(unused)`, plus data files `c1.err c23.err cl.err cl.hlp tools.ini` and the C runtime in `tools/bld/inc` (headers) and `tools/bld/lib` (`slibce.lib` etc. + `setargv.obj`, `*varstck.obj`, `binmode.obj`).
- `lib/lib.exe` (46071 bytes) and `tools/lib.exe` (49661 bytes) **differ** (not duplicates). Plan: keep `tools/lib.exe` as `bin/lib.exe`; move the other to `bin/lib-old.exe` and mention it in the execution log. `lib/mem.lib` is 194437 bytes; `lib/Makefile` is empty.
- `rom` at the repo root is a **symlink** to `/Users/thierry/.local.darwin/emulators/share/pce/ibmpc` (do not copy or delete it; keep it ignored by git). Its content: `ibm-basic-1.10.rom ibm-ega-1984-09-13.rom ibm-vga-1986-10-27.rom ibm-xt-1982-11-08.rom ibmpc-pcex.rom ibmpc/` (a subdirectory, content not yet inspected) and `pceutils/` = `pceboot.com pceclock.sys pceemm.sys pceexit.com pcehimem.sys pcem24.com pcemnt.com pcemsg.com pcestop.com pcetime.com pcever.com`. **There is no `pceinit.com`** (the reference's `autoexec.bat` ran `PCEINIT`); use `pceexit`/`pcestop` instead, or check `rom/ibmpc/`.
- `media/` exists and is empty (no master disk images yet). The user will provide master/blank 1.44M images there; until then `mformat` from mtools can create blank 1.44M images (`mformat -C -f 1440 -i <img> ::`), but a bootable DOS 4 image needs the real boot sector from `boot/msboot.bin`.

### Current tree (at last check)
```
boot/ (Makefile boot.skl msboot.asm)   commands/ (Makefile + 38 command dirs, no select)   kernel/ (Makefile + bios dos ansi country display driver keyboard printer ramdrive smartdrv vdisk xma2ems xmaem)
h/ (19 .h + Makefile)   inc/ (~95 files + Makefile)   lib/ (lib.exe mem.lib Makefile)   mapper/   media/ (empty)   memm/ (Makefile emm/ memm/)   messages/ (Makefile usa-ms.msg usa-ms.idx)
select/   tools/ (+ bld/inc, bld/lib)   rom -> symlink   msdos (launcher)   msdos.cfg   Makefile (old nmake root)   LICENSE.md   cpy.bat runme.bat setenv.bat   msdos40-rebuild-plan.md
```
- Exactly **70 uppercase names** remain: `LICENSE.md` and **69 files named `Makefile`** (root, boot, commands + 38 commands, h, inc, kernel + 11 driver dirs incl. `kernel/display/{ega,lcd}` and `kernel/printer/{4201,4208,5202}`, lib, mapper, memm + `memm/emm` + `memm/memm`, messages, select). Everything else is already lowercase.
- Old `commands/Makefile` and `kernel/Makefile` are the merged nmake wrappers (build order below). `kernel/dos/` has no `msdos.lnk` any more (user removed it): recreate from the listing in Appendix A. `kernel/bios/` still has `msbio.lnk` and `locscr` (Appendix A). Stale prebuilt `.obj` files sit in `inc/` (`printf string nibdos const2 msdata dpb mstable`) and `mapper/` (about 34 `.obj`, `mapper.lib`, `mapper.lst`).

### Key facts about the original nmake build (needed to translate it)
- Environment from `setenv.bat`: `COUNTRY=usa-ms`, `INIT=<root>\tools`, `INCLUDE=<root>\tools\inc` (we use `sdk/include`), `LIB=<root>\tools\lib` (we use `sdk/lib`), `CL=` `LINK=` `MASM=` emptied, PATH += tools.
- Build order (root Makefile): `messages`, `mapper`, `boot`, `bios`, `dos`, `cmd`, `dev`, `select`, `memm`.
  `cmd` order: command attrib assign chkdsk debug edlin exe2bin find fc format join more print recover sort subst sys share nlsfunc ifsfunc mem filesys backup comp diskcomp diskcopy fdisk label mode restore tree replace xcopy graftabl fastopen append graphics keyb.
  `dev` order: country ansi keyboard display printer driver ramdrive smartdrv xma2ems vdisk xmaem.
- `tools/tools.ini` (`[nmake]`) built-in rules to reproduce in `mk/rules.mk`: `asm=masm`, `aflags=-Mx -t $(extasw)`, `ainc=-I. -I$(inc) -I$(dos)`; `cc=cl`, `cflags=-AS -Os -Zp $(extcsw)`, `cinc=-I. -I$(hinc)`; rules `.asm.obj: masm $(aflags) $(ainc) $*.asm,$*.obj;`  `.asm.lst: masm -l ...`  `.c.obj: cl -c $(cflags) $(cinc) -Fo$*.obj $*.c`  `.c.lst: cl -c ... -fc$*.cod -fo$*.obj`  `.exe.com: reloc $*.exe $*.com` (`reloc` is absent: use `convert`)  `.skl.cl1: nosrvbld $*.skl $(msg)\$(COUNTRY).msg`  `.skl.ctl: buildmsg $(msg)\$(COUNTRY) $*.skl`  `.msg.idx: buildidx $*.msg` (with `attrib -R/+R`).
- Typical component Makefile header: `msg=..\..\messages dos=..\..\dos inc=..\..\inc hinc=..\..\h` then `all: x.exe`, object dependency lists, and a final `link @x.lnk` (or `link a+b,...`) plus `convert x.exe [x.com]` / `exefix` for some. Others call `nosrvbld`, `menubld` (fdisk), `compress`/`asc2hlp` (select), `dbof` (boot).
- Output file names (from `cpy.bat`): `io.sys msdos.sys command.com` + every command (`.com` or `.exe` as listed there: append.exe assign.com attrib.exe backup.com chkdsk.com comp.com debug.com diskcomp.com diskcopy.com edlin.com exe2bin.exe fastopen.exe filesys.exe fdisk.exe find.exe fc.exe format.com graftabl.com graphics.com+graphics.pro ifsfunc.exe join.exe label.com mem.exe mode.com more.com nlsfunc.exe print.com recover.com replace.exe restore.com select.exe/.com/.dat/.prt/.hlp share.exe sort.exe sys.com subst.exe tree.com xcopy.exe keyb.com`) and drivers (`ansi.sys country.sys display.sys + ega.cpi lcd.cpi keyboard.sys printer.sys + 4201.cpi 4208.cpi 5202.cpi smartdrv.sys ramdrive.sys driver.sys xma2ems.sys xmaem.sys`, `memm/memm/emm386.sys`).
- Mixed spellings inside `.lnk`/Makefiles are upper and lower case (`ERRTST.OBJ`, `msDATA.OBJ`, `MAPPER.lib`); backslashes everywhere. 49 `.lnk` files exist. Makefile-level `cd ..\x; $(make)` chains must disappear (all dependencies in one GNU make graph).

### Reference conventions to copy (from the deleted `pcdos11-hacking`)
- Tool recipes: `emu2 bin/msmasm.exe a,a,a,a || rm -f a.obj` (delete the object when the tool fails, otherwise make thinks it is up to date), `emu2 bin/link.exe a,a,a,a,` , `echo 60|emu2 exe2bin.exe x.exe x.com` (feeds the answer to exe2bin's prompt; DOS 4's `locscr` file plays the same role with value `70`).
- Image rules (pattern): `cp disks/<master>.img $@; mattrib -i $@ -h -s ::COMMAND.COM ::IO.SYS ::MSDOS.SYS; mdel -i $@ ::...; mcopy -i $@ <file> ::NAME; mattrib -i $@ -a ::"*.*"; mattrib -i $@ +h +s ::IO.SYS; mdir -w -i $@ ::`. Image family `*_base.img` (system only), `*_dist.img`, `*_full.img`, `*_diag.img`; each later image starts by `cp` of the base.
- Run targets: `msdos: all` then `./msdos` (launcher: `#!/bin/sh` + `exec pce-ibmpc -c \`basename $0\`.cfg -g "vga" -r`).
- `msdos.cfg` (already in the repo root, copy of the reference) is a PCE `ibmpc` config: `path = "."` and `path = "rom"`; `system { model = "5150" ... floppy_disk_drives = 3 ... patch_bios_init = 1 patch_bios_int19 = 1 }`; `cpu { model = "8088" speed = 24 }`; `ram { size = 128K }` (**must become 640K**); `rom` 64K at `0xf0000`; `load` blocks: `rom/ibm-pc-1982-10-27.rom` at `0xfe000` (**file absent, `rom/ibm-xt-1982-11-08.rom` exists**), `rom/ibm-basic-1.10.rom` at `0xf6000`, `rom/ibmpc-pcex.rom` at `0xf0000`; `terminal` sdl (escape F12) then null; `video` blocks vga (`rom/ibm-vga.rom`, absent: `ibm-vga-1986-10-27.rom` exists), ega (`rom/ibm-ega.rom`, absent: `ibm-ega-1984-09-13.rom` exists), cga, hgc, mda; speaker, two serial, two parport; `fdc` drive0/drive1; three `disk` blocks: drive 0 `msdos_full.img` (not optional), drive 1 `turbo.img`, drive 2 `demos.img` (optional=1). To adapt: images `build/media/msdos40_*.img`, drop turbo/demos, RAM 640K, ROM names, and check the model (XT ROM implies model `5160`). PCE launches with `-g "vga" -r`.
- `.gitignore` of every build product (`*.obj *.lst *.map *.crf *.exe *.com *.sys *.img`, `rom`, `build/`) except tracked sources/binaries under `bin/`, `sdk/`, `media/`.

### Appendix A: link response files that were lost or must be regenerated
`kernel/bios/msbio.lnk` (exists, keep content): `msbio1+ msCON+ msAUX+ msLPT+ msCLOCK+ msDISK+ msBIO2+ mshard+ msinit+ sysinit1+ sysconf+ sysinit2+ sysimes,msbio,msBIO/M;` (one object per line, as written; output `msbio.exe`, map `msbio.map`). `kernel/bios/locscr` contains the single line `70`. io.sys recipe: `link @msbio.lnk` -> `exe2bin msbio.exe msbio.bin < locscr` -> `copy /b msload.com+msbio.bin io.sys` (`cat`), where `msload.com` = `link msload.obj,msload,,;` then `exe2bin msload.exe msload.com`.

`kernel/dos/msdos.lnk` (**missing, recreate**; object order, `+` continuation, shared units from `inc/` shown with their old `..\inc\` prefix = `build/common/` in the new layout):
```
nibdos.obj const2.obj msdata.obj mstable.obj   (common/)
msdisp.obj mscode.obj
msdosme.obj                                     (common/)
time getset parse misc misc2 crit cpmio cpmio2 fcbio fcbio2 search path ioctl delete rename finfo dup create open dinfo isearch abort close dircall disk disk2 disk3 dir dir2 dev mknode rom fcb msctrlc fat buf proc alloc srvcall util handle macro macro2 file lock share extattr ifs   (.obj each, in this order)
output MSDOS.EXE, map MSDOS.MAP /M ;
```
Then `exe2bin msdos.exe msdos.sys`, `del msdos.exe`. (`kernel/dos/Makefile` lists the same objects in its `msdos.sys:` rule and also references `msdos.cl1` built from `msdos.skl` + the country message file.)

### Gotchas already identified
- `kernel/dos/Makefile` sets `hinc=..\hinc` (typo, should be the C header dir).
- `inc/Makefile` has no rule for `comsubs.lib` (prebuilt, used by subst join fdisk replace restore backup).
- `commands/append/sysmac.lib` is really an assembler macro include (`include sysmac.lib` in `append.asm`), not a library: keep it in place and do NOT move it to `sdk/lib`.
- `select/Makefile` expects `..\shell` and `..\shell\cassfar` directories that do not exist in this tree (only `select/cassfar.lib` prebuilt); `asc2hlp` is in `tools/`. `select/select.mak` is an older makefile for the same.
- `memm/memm/Makefile` hard-codes `CONVERT = c:\dos\exe2bin`; `memm/memm/emm386.lnk` references `..\emm\emmlib.lib` and `..\deb386\buglib.lib` (the latter directory is not in the tree).
- Source files use bare names in `include`/`#include` (no directory), so moving headers needs no source edits; only Makefiles and `.lnk` files carry paths.
- `lib.exe`/MASM/LINK invoked via emu2 can need a DOS-style current directory; tools write outputs relative to cwd, so recipes `cd` into the source dir or pass explicit output paths (see decision 1).


## Confirmed decisions

- Build products go in a separate `build/` directory; sources stay clean.
- PCE: 640K RAM; floppy images are 1.44M.
- Pure GNU make (no nmake). Binary assets (ROMs, `pce/` helpers, master disks, vintage tools) are supplied by the user.
- Directory layout reorganised (see Target layout): `kernel/` (bios, dos, device drivers), `boot/`, `commands/`, `bin/`, `media/`.
- Renames: `h/` -> `include/` (project C headers), `inc/` -> `asminc/` (assembler includes). Shared compilation units, vendor files and prebuilt libraries
  are separated out by the "Headers, includes and libraries policy" below (today they are scattered over `h/`, `inc/`, `lib/`, `tools/bld/`, `mapper/`, `select/`, `commands/append/`).
- Device drivers live directly under `kernel/<driver>/` (already moved by the user; no `kernel/dev/` level). `memm` joins them as `kernel/memm/`.
- Everything lowercase.
- Already done by the user (state at last check): `kernel/{bios,dos,ansi,country,display,driver,keyboard,printer,ramdrive,smartdrv,vdisk,xma2ems,xmaem}`,
  `commands/<name>/` (all 38 commands incl. `command`), `boot/`, empty `media/`, top-level `rom/` (ROMs + `rom/pceutils/` + `rom/ibmpc`),
  `msdos` launcher and `msdos.cfg` copied from the reference at the root. Directory and file names are lowercase except `Makefile` files and `LICENSE.md`.
- Still to do in sub-task 1: `tools` -> `bin`, `memm` -> `kernel/memm`, `select` -> `commands/select`; rename `Makefile` -> lowercase; rename `msdos`/`msdos.cfg` -> `msdos40`/`msdos40.cfg` (or keep `msdos`, see decision 10).
- Still to do in sub-task 2: `h` -> `include`, `inc` -> `asminc` + `common`, `tools/bld/*`, `lib/*` and prebuilt `.lib` files -> `sdk/`.
- Execute one sub-task at a time and wait for user review before the next.
- Moves use `git mv` where the tree is under git, so history is kept.

## Overview

Turn this tree (the released MS-DOS 4.00 sources, originally built with `nmake` on DOS)
into a Unix-hosted, source-based rebuild, shaped like `pcdos11-hacking` (a sibling project that is no longer in the
workspace; its conventions are summarised below):

- **One GNU make build** (no nmake, no recursive `cd ..\x` chains, no `.bat` driver).
- **Everything lowercase** (files and directories, including `makefile`; no more `Makefile`/`MAKEFILE` mix).
- **Vintage tools run under `emu2`** (`masm`, `link`, `lib`, `cl`/`c1`/`c2`/`c3`, `exe2bin`,
  `convert`, `exefix`, `nosrvbld`, `buildmsg`, `buildidx`, `menubld`, ...) from `bin/`.
- **Generated floppy images** assembled with `mtools` (`mformat`/`mcopy`/`mattrib`/`mdir`), like the reference `msdos_base.img` etc.
- **Tested with PCE** (`pce-ibmpc`) through a `msdos40.cfg` machine config and a `msdos40` launcher script.
- Binary assets (ROMs, `pce/` helper `.com` files, master images, vintage tools) are **provided by the user**; the build never fabricates them.

Reference conventions from `pcdos11-hacking` (Makefile, `Makefile.dos`, `msdos.cfg`, `msdos` launcher, `.gitignore`,
`autoexec.bat`, README): `emu2 <tool> args || rm -f <obj>` recipes; image family `*_base/_dist/_full/_diag.img` built by
`cp` of a master image + `mcopy`/`mattrib`/`mdir`; `make msdos` = build + run launcher; `make clean`; `.gitignore` of every
build product; `msdos.cfg` = PCE `ibmpc` config (5150, 8088, ROM loads from `rom/`, video/serial/parport/fdc blocks,
`disk` blocks naming the images); launcher is `exec pce-ibmpc -c <name>.cfg -g "vga" -r`; `autoexec.bat` runs `PCEINIT`.

## Target layout

```
Makefile              single entry point (all, images, run, clean, check)
mk/                   shared make fragments (tools.mk, rules.mk, images.mk)
kernel/bios/          was bios/        -> io.sys
kernel/dos/           was dos/         -> msdos.sys
kernel/<driver>/      was dev/<driver>/ (ansi, country, display, driver, keyboard, printer, ramdrive, smartdrv, vdisk, xma2ems, xmaem)
kernel/memm/          was memm/        -> emm386.sys (see decision 8)
boot/                 boot sector sources (msboot.asm, boot.skl)
commands/<name>/      was cmd/<name>/  one directory per DOS command; commands/select/ was select/
asminc/               was inc/         project assembler include files and include-only .asm fragments (dossym.inc, devsym.inc, parse.asm, msgserv.asm, dosseg.asm, ...)
include/              was h/           project C headers (types.h, sysvar.h, dpb.h, ...)
common/               from inc/        shared compilation units linked into several programs (nibdos, const2, msdata, mstable, msdosme; errtst, sysvar, cds, dpb, kstring)
mapper/               unchanged        mapper.lib sources
messages/             unchanged        usa-ms.msg and generated index
bin/                  was tools/       vintage executables ONLY (masm, link, lib, cl, c1/c2/c3, exe2bin, convert, nosrvbld, ...)
sdk/include/          was tools/bld/inc  vendor C runtime headers (stdio.h, sys/stat.h, ...)
sdk/lib/              was tools/bld/lib, lib/mem.lib, inc/comsubs.lib, select/cassfar.lib   prebuilt libs and startup objects (no sources in the tree)
media/                inputs for image building: master/blank disks, autoexec.bat/config.sys, per-image file lists
                      (currently empty; pce helper .com files are in rom/pceutils)
rom/                  PCE ROMs and PCE utilities (ibm-pc/xt BIOS, basic, ega, vga, ibmpc-pcex, pceutils/); user provided; msdos.cfg uses path = "rom"
build/                all generated objects, listings, maps, binaries (mirrors the source tree) and images (build/media/);
                      build/lib/ = libraries built here (mapper.lib), build/gen/asminc/ = generated includes (boot.inc)
msdos.cfg             PCE machine configuration (copied from the reference; to be adapted: 640K RAM, new disk images, ROM names)
msdos                 launcher script (exec pce-ibmpc -c `basename $0`.cfg -g "vga" -r)
README.md  .gitignore  LICENSE.md
```

Per-component make logic lives in a lowercase `module.mk` next to each source directory (a direct translation of the old
`makefile`, with backslashes -> slashes and `$(inc)\x` -> `$(ASMINC)/x`, `$(hinc)\x` -> `$(INCLUDE_H)/x`), included from the top `Makefile`.

Findings that make the renames low-risk (verified by grep): no assembler `include` and no C `#include` in the sources uses a
directory path (they use bare names, resolved through `-I`/`INCLUDE`), so `inc` -> `asminc` and `h` -> `include` only affect
makefiles and `.lnk`/`.lbr` link response files (those use `..\`-relative paths such as `..\..\inc\comsubs.lib`,
`..\..\mapper\mapper.lib` and will be regenerated by make into `build/`).
Note the committed prebuilt objects in `inc/` and `mapper/` (`*.obj`) are stale artefacts: remove them from the tree and let the build recreate them.

## Headers, includes and libraries policy

Today (found by listing the tree): C headers live in `h/` (19 project headers), `tools/bld/inc` (32 vendor C runtime headers incl. `sys/`),
and privately in 11 command dirs (`attrib`, `mem`, `subst`, `restore`, `backup`, `replace`, `filesys`, `fc`, `join`, `fdisk`) plus `select`, `memm/emm`;
`inc/` mixes ~95 assembler includes, include-only `.asm` fragments, shared compilation units (`.asm` and `.c`), generated `boot.inc`, stale `.obj`
and a prebuilt `comsubs.lib`; libraries sit in `tools/bld/lib` (vendor), `lib/mem.lib`, `inc/comsubs.lib`, `select/cassfar.lib`, `mapper/mapper.lib`
(built) and `commands/append/sysmac.lib` (actually an assembler macro file pulled in with `include sysmac.lib`); `tools/` mixes executables with headers/libs.
One rule per kind of file instead:

| Kind | Home | Used through |
|------|------|--------------|
| Vintage executables | `bin/` | `$(EMU2) bin/<tool>.exe` |
| Vendor C runtime headers | `sdk/include/` | exported `INCLUDE` |
| Vendor/prebuilt libraries and startup objects (`slibce.lib`, `setargv.obj`, `comsubs.lib`, `cassfar.lib`, `mem.lib`) | `sdk/lib/` | exported `LIB` |
| Project C headers | `include/` | `-I include` |
| Project assembler includes and include-only fragments | `asminc/` | `-I asminc` (plus `-I` of the kernel `dos/` dir where the old `$(dos)` was used) |
| Shared compilation units (built once, linked by several programs) | `common/` | `build/common/*.obj` |
| Component-private headers/includes/macros (e.g. `commands/fdisk/*.h`, `mapper/macros.inc`, `commands/append/sysmac.lib`) | stay in the component directory | `-I.` |
| Libraries built here | `build/lib/` (`mapper.lib`) | `LIB` / explicit path |
| Generated includes (`boot.inc` from `dbof`) | `build/gen/asminc/` | `-I build/gen/asminc` ahead of `asminc` |
| Message sources and generated message files | `messages/`; per-component `.cl*`, `.ctl`, `fdiskm.c` in `build/<component>/` | `$(MSG)` |

Variable mapping used when translating each nmake makefile (all defined once in `mk/paths.mk`):
`$(msg)` -> `$(MSG)`, `$(inc)\*.inc|asm` -> `$(ASMINC)/`, `$(inc)\*.obj|c` -> `$(COMMON)/` or `$(BUILD)/common/`, `$(inc)\comsubs.lib` -> `$(SDKLIB)/comsubs.lib`,
`$(hinc)` -> `$(CINC)`, `$(map)` -> `$(BUILD)/lib`, `$(dos)` -> `$(KDOS)`, and the hard-coded `..\..\inc\...`, `..\..\mapper\...` paths in `.lnk` files disappear because
`.lnk` response files are generated by make with the right paths.

Facts this rests on: `inc/Makefile` builds `errtst.obj sysvar.obj cds.obj dpb.obj nibdos.obj const2.obj msdata.obj msdosme.obj mstable.obj` (compiled units);
`commands/fc/Makefile` builds `kstring.obj` from `inc/kstring.c`; `commands/subst`, `join`, `fdisk`, `replace`, `restore`, `backup` link `comsubs.lib` and `mapper.lib`; `inc/Makefile`
has no rule for `comsubs.lib` (so it is a prebuilt binary).

## Open decisions / risks (settle early, mainly in sub-task 3)

1. **`build/` output (decided).** MASM/LINK write to cwd and sources use relative lookups, so recipes run from the source dir and
   pass explicit output paths (`masm src,build/x/obj;`) or copy/`cd` into `build/`. Prove the approach in sub-task 3.
2. **Case sensitivity.** All names are lowercase now; on a case-sensitive host emu2 must resolve `include`/`link`/`lib` file names
   regardless of the case written inside sources and `.lnk` files (e.g. `ERRTST.OBJ`, `msDATA.OBJ`). Verify with a real `masm`/`link` run; if needed, add a case-folding step or lowercase the references.
3. **Path syntax passed to DOS tools.** nmake used `-I..\inc`; under emu2 `/` may be read as a switch. Prefer exporting
   `INCLUDE`, `LIB`, `INIT` (emu2 passes host env) and keep `-I` arguments in the form the tools accept (test both).
4. **Missing/unknown tools.** the old `tools.ini` references `reloc` (not in `tools/`); `convert.exe` probably replaces it for `.exe -> .com`. Confirm each tool runs under emu2.
5. **C compiler under emu2.** `cl.exe` (C 5.x, `-AS -Os -Zp`) is a multi-pass driver that spawns `c1/c2/c3`; confirm emu2 supports the spawn.
6. **Image geometry / RAM.** 1.44M images, 640K RAM (reference used 128K RAM, too small for DOS 4). The user supplies the master disks in `media/`; PCE fdc/floppy settings in `msdos40.cfg` to be checked on first boot.
7. **Environment variables** required by the sources: `COUNTRY=usa-ms`, `INIT`, `INCLUDE`, `LIB` (exported by the Makefile, replacing `setenv.bat`).
8. **Placement of `memm`.** Default: `kernel/memm` (it builds `emm386.sys`; its sub-makefiles in `memm/emm` and `memm/memm` use `..\emm` relative links, which stay valid). `select` -> `commands/select`.
9. **Old `lib/` directory** holds `lib.exe`, `mem.lib` and an empty makefile: `lib.exe` is a likely duplicate of `tools/lib.exe` (byte-compare first) -> `bin/`; `mem.lib` -> `sdk/lib` (no makefile references it; keep unless proven unused). `lib/` disappears.
10. **Launcher/config names.** The reference launcher derives the config name from its own name (`msdos` -> `msdos.cfg`). Default: keep that convention but name them `msdos40` / `msdos40.cfg` to avoid clashing with the `msdos` make target and to stay distinct from DOS files. `mapper/` and `messages/` stay top-level (they are shared inputs, not generic dirs) unless you say otherwise.
11. **ROM names.** `msdos.cfg` references `rom/ibm-pc-1982-10-27.rom` and `rom/ibm-vga.rom`/`rom/ibm-ega.rom`, but `rom/` actually contains `ibm-xt-1982-11-08.rom`, `ibm-vga-1986-10-27.rom`, `ibm-ega-1984-09-13.rom`, `ibm-basic-1.10.rom`, `ibmpc-pcex.rom`. The cfg must be updated to the files present (model 5160/XT vs 5150 to be decided with the BIOS ROM used).
12. **`common/` split (CONFIRMED by user).** Shared compiled units go to top-level `common/`; `asminc/` keeps only includes. Rejected alternatives: `kernel/common/`, or everything in `asminc/`.
13. **Duplicated per-command headers/sources.** `msgret.h` (attrib, filesys, fdisk), `parse.h` (attrib, mem, filesys, fdisk), `internat.h` (fc vs `include/`), many `_parse.asm`/`_msgret.asm` stubs. Default: leave them local; dedupe only byte-identical copies, and only after the build works.
14. **`sdk/` naming (CONFIRMED by user).** `sdk/include` + `sdk/lib` hold the Microsoft C 5.x runtime that `cl.exe` needs and the prebuilt libraries (vendor, no sources); `bin/` holds executables only.


## Sub-tasks

Each sub-task is independent and reviewable; do them in order.

### 1. Repo scaffolding, renames and lowercase normalisation
- **Intent:** Establish the project skeleton, naming convention and new directory layout.
- **Expected outcomes:** Every file/dir lowercase; remaining directory moves done: `tools` -> `sdk/bin`, `memm` -> `kernel/memm`, `select` -> `commands/select` (the other moves are already done; header/library directories are handled in sub-task 2); stale `*.obj` removed; nmake `Makefile` files renamed lowercase and left in place until each is translated, then removed (so the originals stay readable during the port); `.gitignore`, README skeleton, launcher/config (`msdos`/`msdos.cfg`), `media/` skeleton; legacy `setenv.bat`/`cpy.bat`/`runme.bat` retired last, once their content is in make/README.
- **Todo:**
  1. Inventory remaining uppercase names (found: `LICENSE.md`, `Makefile` files across the tree) and rename. Note the root `makefile`, `commands/makefile`, `kernel/makefile` are old nmake wrappers to be replaced by the GNU make root `makefile`.
  2. Perform the remaining directory moves: `tools` -> `sdk/bin`, `memm` -> `kernel/memm`, `select` -> `commands/select`.
  3. Check in-source references (`.lnk`, `.lbr`, `locscr`, message file names, mixed-case object names).
  4. Add `.gitignore` and `README.md`.
  5. Maintain `media/` skeleton with notes on user-provided assets.
- **Relevant context:** root listing; `kernel/bios/msbio.lnk`, `kernel/bios/locscr`, `kernel/dos/msdos.lnk`, `setenv.bat`, `cpy.bat`.
- **Status:** [x] done

### 2. Header, include and library consolidation
- **Intent:** Give every kind of header, include, shared source and library one documented home (see policy section), instead of the scattered `h/`, `inc/`, `lib/`, `tools/bld/` and per-directory copies.
- **Expected outcomes:** `include/`, `asminc/`, `common/`, `sdk/include/`, `sdk/lib/` populated per the policy table; `sdk/bin/` contains executables only; `lib/`, `h/`, `inc/`, `sdk/bin/bld/` gone; no generated or stale artefacts left in source dirs; paths defined clearly for autonomous makefiles.
- **Todo:**
  1. Classify every file in `inc/` and `h/` as include-only, compiled unit, generated, prebuilt or stale.
  2. Move `h/*.h` -> `include/`, `inc/` includes -> `asminc/`, and compiled units -> `common/`.
  3. Move `sdk/bin/bld/inc` -> `sdk/include`, `sdk/bin/bld/lib` -> `sdk/lib`; move `lib/mem.lib`, `inc/comsubs.lib`, `commands/select/cassfar.lib` to `sdk/lib`.
  4. Byte-compare `lib/lib.exe` with `sdk/bin/lib.exe` (kept `lib.exe` in `sdk/bin/`, saved `lib/lib.exe` as `sdk/bin/lib-old.exe`); deleted empty `lib/Makefile` and `h/Makefile`.
  5. Removed generated `boot.inc` and stale `.obj`/`.lib`/`.lst` artifacts.
  6. Compared duplicated headers across commands.
- **Relevant context:** listing of `include/`, `asminc/`, `common/`, `sdk/`; `common/Makefile`.
- **Status:** [x] done

### 3. Toolchain wrappers and smoke tests
- **Intent:** Prove each vintage tool in `sdk/bin/` works headless under emu2 and implement `tools-check` target in root `Makefile`.
- **Expected outcomes:** `make tools-check` assembles/links `.asm`, runs `exe2bin`, `lib`, `cl` (passes c1/c2/c3) on `.c`, `nosrvbld`, `buildmsg`, `buildidx`, `dbof`, `convert`, `exemod`, `exefix`, `exepack`, `asc2hlp`, `compress`.
- **Todo:**
  1. Define tool variables in `Makefile`: `EMU2`, `MASM`, `LINK`, `LIB`, `CL`, `EXE2BIN`, `CONVERT`, `NOSRVBLD`, `BUILDMSG`, `BUILDIDX`, `MENUBLD`, `DBOF`, `EXEFIX`, `EXEMOD`, `EXEPACK`, `ASC2HLP`, `COMPRESS`.
  2. Configure environment passing for `CL`: `INCLUDE=$(SDKINC)` and `PATH=$(SDKBIN)`.
  3. Verify all 15 vintage DOS tools under `emu2` via `make tools-check`.
  4. Normalized line endings of `.skl` files to standard DOS CRLF.
- **Relevant context:** `sdk/bin/*`, `Makefile`.
- **Status:** [x] done

### 4. Foundation: messages, common, mapper, boot
- **Intent:** Build the prerequisites everything else links against.
- **Expected outcomes:** `messages/usa-ms.idx`; `common/*.obj` (nibdos, const2, msdata, mstable, msdosme, plus C objects errtst, sysvar, cds, dpb, kstring, string); `mapper/mapper.lib`; `boot/msboot.bin` and generated `asminc/boot.inc` (via `dbof`).
- **Todo:** Implement clean root-orchestrated Makefiles for `messages`, `boot`, `common`, and `mapper`; build and verify all foundation targets.
- **Relevant context:** `messages/`, `boot/`, `common/`, `mapper/`, root `Makefile`.
- **Status:** [x] done

### 5. Kernel: `io.sys` and `msdos.sys`
- **Intent:** Produce the two system files.
- **Expected outcomes:** `build/kernel/bios/io.sys` (`link @msbio.lnk` -> `exe2bin msbio.exe msbio.bin <locscr` -> `msload.com + msbio.bin`) and `build/kernel/dos/msdos.sys` (`link @msdos.lnk` -> `exe2bin`), with all object dependencies expressed in GNU make (the `dos/makefile` has a ~60-object list plus a `dossym.inc` pseudo-target to replace with plain include dependencies).
- **Todo:** translate `kernel/bios/Makefile` and `kernel/dos/Makefile` (`make=nmake -i`, `copy /b` -> `cat`, `exe2bin ... <locscr` -> stdin redirect under emu2); keep object ordering from `msbio.lnk` and the object list in the dos Makefile.
- **Relevant context:** `kernel/bios/Makefile`, `kernel/bios/msbio.lnk`, `kernel/bios/locscr`, `kernel/dos/Makefile`.
- **Status:** [x] done

### 6. `command.com` and first bootable image under PCE (milestone)
- **Intent:** Reach an end-to-end boot: build, image, run in PCE.
- **Expected outcomes:** `build/commands/command/command.com`; `build/media/msdos40_base.img` (master from `media/` + boot sector + `io.sys`, `msdos.sys`, `command.com`, system files first and contiguous); `msdos40.cfg` and `msdos40` launcher; `make msdos40` boots to a prompt in PCE.
- **Todo:**
  1. Translate `commands/command/Makefile` (resident/transient parts, `.ctl` message file generation).
  2. Add `mk/images.mk`: copy of user-supplied master image from `media/`, boot sector from `build/boot/msboot.bin`, `mcopy` with `mattrib +h +s +r` handling, `mdir` listing.
  3. Adapt `msdos.cfg` (already at the root; 5150/8088, ROM loads from `rom/`, VGA/EGA/CGA/HGC/MDA video blocks, serial/parport/fdc): fix ROM file names (decision 11), RAM 640K, `disk` blocks pointing at `build/media/*.img`; keep the `msdos` launcher (or rename, decision 10).
  4. `make msdos40` = `all` + run.
- **Relevant context:** `commands/command/Makefile`; reference conventions in Overview; user-supplied `rom/`, `rom/pceutils/`, master disks in `media/`.
- **Status:** [x] done

### 7. External commands (`commands/*`), in batches
- **Intent:** Rebuild all the utilities listed in `cpy.bat`.
- **Expected outcomes:** all `commands/<util>` outputs (`.com`/`.exe`) build via the common pattern rules; batches: (a) asm-only (`append`, `assign`, `chkdsk`, `comp`, `diskcomp`, `diskcopy`, `edlin`, `exe2bin`, `fc`, `find`, `join`, `label`, `more`, `print`, `recover`, `sort`, `subst`, `sys`, `share`, `tree`, `xcopy`, `nlsfunc`, `ifsfunc`, `filesys`, `fastopen`, `graftabl`, `graphics`, `keyb`, `mem`); (b) C+asm (`attrib`, `backup`, `restore`, `replace`, `fdisk`, `format`, `mode`, `debug`). Exact asm/C split to be confirmed per makefile.
- **Todo:** one `module.mk` per utility (message `.skl` -> `.cl*`/`.ctl` generation, `.lnk` handling, `convert`/`exefix` post-steps); track failures per tool; do not hide errors.
- **Relevant context:** `commands/Makefile` (build order), each `commands/*/Makefile`, `cpy.bat`.
- **Status:** [ ] pending

### 8. Device drivers (`kernel/<driver>`), `select`, `memm`
- **Intent:** Complete the distribution content.
- **Expected outcomes:** `kernel/<driver>` outputs (`ansi.sys`, `country.sys`, `display.sys` + `.cpi`, `keyboard.sys`, `printer.sys` + `.cpi`, `smartdrv.sys`, `ramdrive.sys`, `driver.sys`, `vdisk`, `xma2ems.sys`, `xmaem.sys`); `commands/select` (`select.exe/.com/.dat/.prt/.hlp`, uses `asc2hlp`, `compress`); `kernel/memm` (`emm386.sys`).
- **Todo:** translate makefiles; handle `memm/memm` hard-coded `c:\dos\exe2bin`; isolate anything that cannot build and record it.
- **Relevant context:** `kernel/Makefile` (driver build order), `commands/select/Makefile` (after move), `kernel/memm/**/Makefile`.
- **Status:** [ ] pending

### 9. Distribution images, README, polish
- **Intent:** Mirror the reference's image family and docs.
- **Expected outcomes:** `msdos40_base.img`, `msdos40_dist.img` (core utilities), `msdos40_full.img` (+ drivers, select, memm, `config.sys`/`autoexec.bat` with `pceinit`), optional `msdos40_diag.img`; `make dist`, `make clean`, `make check`; README (build deps: emu2, mtools, pce; usage; tool findings); old nmake makefiles and `.bat` files removed.
- **Todo:** port the `cpy.bat` file list into image targets; document run commands; final full clean build + PCE boot verification.
- **Relevant context:** `cpy.bat`, reference conventions in Overview.
- **Status:** [ ] pending

### 10. Post-4.00 / 4.01 Maintenance & Known Bugfix Backports (Tracked Enhancements)
- **Intent:** Track known post-4.00 Microsoft / 4.01 maintenance improvements and edge-case fixes.
- **Expected outcomes:** Documented status, verification, and potential backports of 4.01 enhancements.
- **Todo:**
  1. [ ] **Version/Banner Alignment:** Track option to bump `minor_version equ 01` in `asminc/versiona.inc` and banner in `messages/usa-ms.msg`.
  2. [ ] **EMM386 / XMA2EMS Chipset Traps:** Track 80386 I/O port address decoding edge cases for non-IBM 386 motherboards (e.g. Compaq Deskpro / C&T NEAT).
  3. [ ] **SELECT Low-Memory Wizard Footprint:** Track memory reduction patches for the installation program on <640KB systems.
  4. [ ] **FDISK Large Partition Boundary Math:** Verify and test cluster calculation edge cases on 512MB–2GB FAT16 drives.
- **Status:** [ ] pending

## Execution log

### Sub-task 1 (completed)
- Standardized all 69 makefiles across the tree to standard capitalized `Makefile` (source files and directories remain lowercase).
- `LICENSE.md` retains uppercase naming.
- Moved `tools/` -> `sdk/bin/` (`sdk/` now groups vintage tools and vendor SDK assets).
- Moved `memm/` -> `kernel/memm/`.
- Moved `select/` -> `commands/select/`.
- Retained `msdos` launcher and `msdos.cfg` as requested.
- Untracked `rom` symlink left completely untouched.
- Removed stale prebuilt `.obj` and `.lib` artifacts from `inc/` (`dpb.obj`, `msdata.obj`, `const2.obj`, `nibdos.obj`, `string.obj`, `mstable.obj`, `printf.obj`) and `mapper/` (24 `.obj` files, `mapper.lib`, `mapper.lst`).
- Verified all 49 `.lnk` response files (including `kernel/dos/msdos.lnk` and `kernel/bios/msbio.lnk`).
- Created `.gitignore`, [`README.md`](README.md), and [`media/README.md`](media/README.md).
- User clarified preference for autonomous boilerplate makefiles (no `.mk` fragment chaining or macros).

### Sub-task 2 (completed)
- Moved all 19 project C headers from `h/` -> `include/`; removed empty `h/Makefile` and `h/`.
- Moved shared compiled units (`cds.c`, `dpb.c`, `errtst.c`, `kstring.c`, `string.c`, `sysvar.c`, `const2.asm`, `msdata.asm`, `msdata2.asm`, `msdosme.asm`, `mstable.asm`, `nibdos.asm`, `printf.asm`) to `common/`.
- Moved assembler include files and include fragments from `inc/` to `asminc/`; removed generated `boot.inc` and deleted `inc/`.
- Moved Microsoft C 5.x CRT headers (`sdk/bin/bld/inc`) to `sdk/include/`.
- Moved Microsoft C 5.x CRT libs/objects (`sdk/bin/bld/lib`), `lib/mem.lib`, `inc/comsubs.lib`, and `commands/select/cassfar.lib` to `sdk/lib/`.
- Compared `lib/lib.exe` vs `sdk/bin/lib.exe`: kept `sdk/bin/lib.exe` as primary, archived `lib/lib.exe` as `sdk/bin/lib-old.exe` to test later as requested; removed empty `lib/Makefile` and `lib/`.
- Compared duplicated headers: confirmed `include/internat.h` and `commands/fc/internat.h` are byte-identical; confirmed component-private variations for `parse.h` and `msgret.h`.
- Drafted autonomous dependency rules in `common/Makefile`.

### Sub-task 3 (completed)
- Defined toolchain variables in root [`Makefile`](Makefile:1) for all 15 vintage build tools.
- Tested and verified execution under `emu2`:
  - `masm.exe` (MASM 5.10) — assembled 8086 code
  - `link.exe` (Overlay Linker 3.65) — linked 16-bit executable
  - `exe2bin.exe` — converted `.exe` to binary
  - `cl.exe` (C 5.10 multi-pass with `c1.exe`, `c2.exe`, `c3.exe`) — compiled C code with `INCLUDE=sdk/include` and `PATH=sdk/bin`
  - `lib.exe` (Library Manager 3.10) — created library from object module
  - `buildidx.exe` — verified index generation for `messages/usa-ms.msg`
  - `nosrvbld.exe` — generated `.cl1` from `.skl` + `.msg`
  - `buildmsg.exe` — parsed skeleton and generated `.ctl` / `.cl*` tables
  - `dbof.exe` — extracted boot sector offsets into `.inc`
  - `convert.exe` — converted `.exe` to `.com`
  - `exemod.exe` / `exefix.exe` / `exepack.exe` — inspected, adjusted headers, and compressed executables
  - `asc2hlp.exe` — built `select.hlp` (28.7 KB) from `usa.txt`
  - `compress.com` — ran compression routine
- Normalized line terminators of all `.skl` files to DOS CRLF for vintage parser compatibility.
- Implemented and verified `make tools-check` target passing all checks.

### Sub-task 4 (completed)
- Built `messages/usa-ms.idx` via `buildidx.exe`.
- Built `boot/msboot.bin` (32,256 bytes) and generated `asminc/boot.inc` via `dbof.exe`.
- Built all 11 shared compiled units in `common/`:
  - ASM: `const2.obj`, `msdata.obj`, `msdosme.obj`, `mstable.obj`, `nibdos.obj`
  - C: `cds.obj`, `dpb.obj`, `errtst.obj`, `kstring.obj`, `string.obj`, `sysvar.obj`
- Built `mapper/mapper.lib` (19,289 bytes) packaging all 52 mapper object modules.
- Replaced UTF-8 box characters in `mapper/getmsg.asm` line 473 with ASCII to fix MASM line-length limit.
- Verified single-pass `make foundation` target building everything from a clean tree.

### Sub-task 5 (completed)
- Implemented autonomous `kernel/bios/Makefile` generating `io.sys` (33,321 bytes) via `link @msbio.lnk` -> `exe2bin msbio.exe msbio.bin < locscr` -> `cat msload.com msbio.bin > io.sys`.
- Implemented autonomous `kernel/dos/Makefile` generating `msdos.sys` (37,376 bytes) via `link @msdos.lnk` -> `exe2bin msdos.exe msdos.sys`, linking against `common/*.obj`.
- Standardized `export EMU2_DRIVE_C ?= $(ROOT)` and `C:\` references across kernel and common Makefiles.
- Wired `kernel` (`bios` and `dos`) into the top-level `Makefile`.

### Sub-task 6 (completed)
- Implemented autonomous `commands/command/Makefile` generating `command.com` (37,556 bytes) via `buildmsg` -> `masm` -> `link @command.lnk` -> `exe2bin`.
- Fixed `boot/msboot.asm` line 124 (`Phydrv db 00h` default for floppy boot instead of hard-coded `80h`).
- Updated `boot/Makefile` to generate 512-byte `bootsec.bin`.
- Adapted `msdos.cfg`: RAM set to 640K, exact ROM file paths (`rom/ibm-xt-1982-11-08.rom`, `rom/ibm-vga-1986-10-27.rom`, `rom/ibm-ega-1984-09-13.rom`), and disk drive 0 pointing to `media/msdos40_base.img`.
- Added image generation rules to root `Makefile` creating bootable `media/msdos40_base.img` (1.44M FAT12) containing `IO.SYS`, `MSDOS.SYS`, and `COMMAND.COM`.
