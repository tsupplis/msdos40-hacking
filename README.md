# MS-DOS 4.01 rebuild

MS-DOS 4.01 rebuilt on Unix with GNU make and the original tools under `emu2`. The goal is a usable replacement for DOS 3.3.

| Goal | Details |
|---|---|
| **Stability** | Apply the documented Microsoft and IBM fixes and regression-test the rebuilt system. |
| **Memory** | Surpass DOS 3.3 and approach DOS 5.0, targeting 610 Kbytes free. UMB allocation and XMS reporting are available. Selected kernel services can run in the HMA. |
| **Usability** | Command-line editing and recall, clearer memory diagnostics, BASIC (`mbasic.com`) and a screen editor (`vi.exe`) on the full floppy. |

![MS-DOS 4.01 running in PCE with upper memory enabled](images/mem.png)

## Sources

Based on hharte’s [4.01 reconstruction](https://github.com/lotharsm/MS-DOS/tree/dos-4.01-reconstructed) of the [released MS-DOS sources](https://github.com/microsoft/MS-DOS).

| Directory | Contents |
|---|---|
| `boot/`, `kernel/` | Boot sector, `io.sys`, `msdos.sys`, drivers and code pages |
| `commands/` | `command.com`, external commands and `select` |
| `common/`, `mapper/`, `messages/` | Shared objects, libraries and messages |
| `asminc/`, `include/`, `sdk/` | Headers and vintage build tools |
| `media/` | Floppy image rules and startup files |

## Historical changes

The 4.01 reconstruction changes 12 source files and corrects encoding in 17 others.

| Component | 4.01 change |
|---|---|
| `command.com`, messages | Display 4.01 at startup and in `ver`. |
| `msdos.sys`, `format` | Use the high word of disk sector numbers. |
| `fastopen` | Follow the extent chain on truncation. |
| `msdos.sys` | Remove the EMS map restore from the Ctrl-C path. |
| `io.sys` | Accept another boot-sector OEM name pattern. |
| `select` | Restore CP437 panel borders. |
| `setenv.bat` | Update original tool paths. This tree uses makefiles. |

| Later patch | Component | Fix |
|---|---|---|
| Microsoft PD0255 | `msdos.sys` | Correct directory creation and file appends near 32 MB boundaries. |
| Microsoft PD0255 | `graphics.com` | Avoid the `mscdex` multiplex number. |
| IBM UR31300, IR80263 | `ansi.sys` | Fix Shift-PrtSc above 25 rows. |

## Command-line editing

| Key | Action |
|---|---|
| Left, Right / Home, End | Move one character / move to either end. |
| Ins | Toggle insert (default) and overwrite. |
| Del / Backspace, Ctrl-H | Delete under / before the cursor. |
| Up / Down | Recall the previous line on an empty prompt / ignore. |
| Esc / Enter | Discard / submit the whole line. |

Applies to `command.com` and DOS buffered console input. Cooked handle reads support editing without recall. For historical editing, set `LINEEDIT EQU 0` in `kernel/dos/editsw.inc` and rebuild. Test with `test/check_edit`.

## Command enhancements

| Command | MS-DOS 5.0 comparison | Enhancement | Missing MS-DOS 5.0 features |
|---|---|---|---|
| `append` | No known gaps |  |  |
| `assign` | No known gaps |  |  |
| `attrib` | Gaps identified |  | `+H` / `-H` set or clear hidden, and `+S` / `-S` set or clear system. File selection must include files that already have these attributes. |
| `backup` | Pending |  |  |
| `break` | Pending |  |  |
| `call` | Pending |  |  |
| `cd` (`chdir`) | Pending |  |  |
| `chcp` | Pending |  |  |
| `chkdsk` | Pending |  |  |
| `cls` | Pending |  |  |
| `command.com` | Pending |  |  |
| `comp` | No known gaps | `/D` reports decimal bytes, `/A` shows characters, `/L` reports line numbers, `/N=n` limits comparison to the first *n* lines, and `/C` ignores ASCII letter case. |  |
| `copy` | No known gaps | `/Y` allows overwriting. `/-Y` prompts before overwriting. `COPYCMD` presets either switch. The last explicit overwrite switch wins. |  |
| `ctty` | Pending |  |  |
| `date` | Pending |  |  |
| `debug` | Pending |  |  |
| `del` (`erase`) | No known gaps | `/Q` skips the bulk-delete confirmation. An explicit `/P` still prompts for each file. |  |
| `dir` | Gaps identified | `/B` prints bare names, one per line. `/L` displays ASCII letters in filenames in lowercase. `/A[:]` filters by D, R, H, S, or A. `/O[:]` orders by N (name), E (extension), S (size), D (date), or G (directories first). Prefix a letter with `-` to exclude an attribute or reverse a key. `/P` pages console output. `DIRCMD` presets switches, and `/-` disables a preset switch on the command line. | `/S` recursion. |
| `diskcomp` | No known gaps |  |  |
| `diskcopy` | Gaps identified |  | `/V` verifies the destination copy. |
| `echo` | Pending |  |  |
| `edlin` | No known gaps |  |  |
| `exe2bin` | No known gaps |  |  |
| `exit` | Pending |  |  |
| `fastopen` | No known gaps |  |  |
| `fc` | No known gaps |  |  |
| `fdisk` | Gaps identified |  | `/STATUS` displays a partition summary. The undocumented `/MBR` rewrites master boot code while retaining an existing valid partition table. |
| `filesys` | Pending |  |  |
| `find` | Pending |  |  |
| `for` | Pending |  |  |
| `format` | Gaps identified |  | `/Q` quick format, recoverable formatting and its `/U` unconditional option, and the 2.88 MB size for `/F`. |
| `goto` | Pending |  |  |
| `graftabl` | Pending |  |  |
| `graphics` | Pending |  |  |
| `if` | No known gaps | `IF [NOT] DIREXIST path command` tests for a directory. Wildcards match directories only. |  |
| `ifsfunc` | Pending |  |  |
| `join` | No known gaps |  |  |
| `keyb` | Pending |  |  |
| `label` | No known gaps |  |  |
| `loadhigh` (`lh`) | No known gaps | Run an external program in upper memory when it fits. |  |
| `mbasic.com` | Project extra | BASIC interpreter on the full floppy. |  |
| `md` (`mkdir`) | Pending |  |  |
| `mem` | Gaps identified | Show total, used, and free memory by pool and the largest usable blocks. `/C` (`/CLASSIFY`) groups modules by memory usage. Combine `/P` with `/C` or `/D` (`/DEBUG`) to page console output. Alone, `/P` pages the summary. | `/PROGRAM` lists loaded programs. |
| `mode` | Pending |  |  |
| `more [filename]` | No known gaps | Page a file by name. |  |
| `nlsfunc` | Pending |  |  |
| `path` | Pending |  |  |
| `pause` | Pending |  |  |
| `print` | Pending |  |  |
| `prompt` | Pending |  |  |
| `rd` (`rmdir`) | Pending |  |  |
| `recover` | Pending |  |  |
| `rem` | Pending |  |  |
| `ren` (`rename`) | Pending |  |  |
| `replace` | No known gaps |  |  |
| `restore` | Pending |  |  |
| `select` | Pending |  |  |
| `set` | Pending |  |  |
| `share` | Pending |  |  |
| `shift` | Pending |  |  |
| `sort` | No known gaps |  |  |
| `subst` | No known gaps |  |  |
| `sys` | Gaps identified |  | Transfer `COMMAND.COM`, recognize both IBM and Microsoft system-file names when replacing an installation, and allow the first three contiguous sectors of `IO.SYS` to reside later in the data area. The placement change also requires boot-loader support. |
| `time` | Pending |  |  |
| `tree` | No known gaps |  |  |
| `truename` | Pending |  |  |
| `type` | Pending |  |  |
| `ver` | No known gaps | Displays the project version as `4.01N`. |  |
| `verify` | Pending |  |  |
| `vi.exe` | Project extra | Screen editor on the full floppy. |  |
| `vol` | Pending |  |  |
| `xcopy` | No known gaps | `XCOPYCMD` presets XCOPY switches. Explicit switches take precedence. For example, `SET XCOPYCMD=/S /E` includes empty subdirectories and `XCOPY source dest /-S /-E` copies only the top level. |  |
| `device=umbs.sys start-end [start-end ...]` | Project extra | Supply unused, mapped RAM as UMBs. Use four-digit hex segments with an exclusive end. Each range is granted whole. |  |

## Configuration enhancements

| Directive | Enhancement | Conventional bytes saved on PCE¹ |
|---|---|---:|
| `dos=high` | Place filename parsing, directory search, local pathname lookup and file I/O in the HMA when available. Combine with `dos=high,umb` for UMBs. | 7,504 with the PCE configuration below |
| `dos=umb` | Enable upper memory blocks (UMBs) from an XMS provider. | — |
| `devicehigh=driver [arguments]` | Try upper memory first, then conventional memory if the image cannot fit. | 4,544 with `ansi.sys` |
| `shellhigh=interpreter [arguments]` | Try upper memory for the shell and, for permanent `command.com`, its `/e:bytes` environment. Each falls back independently. | 6,096 with `command.com /p /e:160` |
| `buffers=` | Place the primary buffer pool in one UMB when it fits. | 10,640 with `buffers=20` |
| `stacks=` | Place interrupt handlers and stacks together in one UMB when they fit. | 3,296 with `stacks=9,128` |
| `fcbs=n,m` | Place the FCB table in one UMB when it fits. | 272 with `fcbs=4,1` |
| `lastdrive=` | Place the permanent current-directory table in one UMB when it fits. | 464 with `lastdrive=e`, 2,304 with `lastdrive=z` |
| `files=` | Place the file table extension in one UMB when it fits. The first five entries stay in the kernel. | 912 with `files=20` |

PCE example for `config.sys`

```dos
dos=high,umb
files=20
buffers=20
fcbs=4,1
lastdrive=e
device=pcehimem.sys
devicehigh=ansi.sys
shellhigh=command.com /p /e:160
```

¹ PCE XT with 512-byte floppy sectors. With 88 Kbytes of UMB and the HMA enabled, the example above gives a 614,448-byte largest executable (600 KiB plus 48 bytes). The launcher configuration in `pceconfig.sys` gives the same result.

For a machine with unused RAM mapped from segment `ca00` up to `e000` (exclusive), use `umbs.sys` as the provider.

```dos
dos=umb
device=umbs.sys ca00-e000
devicehigh=ansi.sys
shellhigh=command.com /p
```

Programs can link UMBs with `int 21h/5803h` and select upper-only or upper-first allocation with `5801h`.

## Companion projects

| Project | Description |
|---------|-------------|
| [ccpm86-kernel](https://github.com/tsupplis/ccpm86-kernel)         | CCP/M-86 3.1 distribution rebuilt from patched and reconstituted sources |
| [cdos41-kernel](https://github.com/tsupplis/cdos41-kernel)         | Concurrent DOS 4.1 distribution rebuilt from patched and reconstituted sources |
| [cpm86-kernel](https://github.com/tsupplis/cpm86-kernel)     | CP/M-86 1.1 distribution rebuilt from patched and reconstituted sources |
| [cpm86-crossdev](https://github.com/tsupplis/cpm86-crossdev) | Unix CP/M-86 cross development project (compilers, emulation and tools) |
| [cpm86-hacking](https://github.com/tsupplis/cpm86-hacking)   | CP/M-86 miscellaneous tools and PCE emulator helpers |
| [cpm86-cmdtools](https://github.com/tsupplis/cpm86-cmdtools) | CP/M-86 `.cmd` file manipulation tools |
| [cpm86-ports](https://github.com/tsupplis/cpm86-ports)       | CP/M-86 application ports in C and assembler |
| [cpm86-vi](https://github.com/tsupplis/cpm86-vi)             | STevie vi port for CP/M-86 and PC-DOS |
| [cpm86-msbasic](https://github.com/tsupplis/cpm86-msbasic)   | A recreation of msbasic-86 for CP/M-86 and PC-DOS 1.1 from gwbasic sources |
| [cpm86-menu](https://github.com/tsupplis/cpm86-menu)   | A submit replacement and a menu system for submit orchestration for CP/M-86 1.1 |
| [cpm86-make](https://github.com/tsupplis/cpm86-make)   | A simple submit based make tool for CP/M-86 |
| [pcdos11-hacking](https://github.com/tsupplis/pcdos11-hacking) | PC-DOS 1.1 distribution, tools and notes |
| [msdos40-hacking](https://github.com/tsupplis/msdos40-hacking) | MS-DOS 4.0 distribution, tools and notes |

---

## License

MIT unless a subdirectory specifies otherwise. [license.md](LICENSE.md)
