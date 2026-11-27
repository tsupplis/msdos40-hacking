# Microsoft GW-BASIC Interpreter Source Code

## Source credits

This port combines Microsoft's 1983 interpreter with the MASM compatibility changes and PC-specific routines from TK Chia's fork of Diomidis Spinellis's reconstruction. [Microsoft GW-BASIC](https://github.com/microsoft/GW-BASIC) · [Diomidis Spinellis's reconstruction](https://github.com/dspinellis/GW-BASIC) · [TK Chia's fork](https://codeberg.org/tkchia/GW-BASIC)

Stjepan Gros wrote `oem.asm`. TK Chia wrote or reconstructed additional routines in that module and supplied `oemcbk.asm` (Ctrl-Break and Pause), `oemev.asm` (peripheral events) and `oemsnd.asm` (sound). The source comments identify routines reconstructed from Microsoft's MS-DOS 1.25 `BASICA.COM`.

The OEM startup banner credits D. Spinellis, S. Gros and T.K. Chia, 2020–2022. Retain that credit, the source attribution comments and the MIT notice when modifying or redistributing this port. [MIT license](LICENSE.md)

## Build and run

The interpreter sources follow TK Chia's `tkchia/devel` at [1432e385](https://codeberg.org/tkchia/GW-BASIC/commit/1432e385776554e43784b411eda7b8b2a9709e73) (5 October 2026). This build targets `GWBASIC.EXE`. The internal label for `INSTR` avoids a reserved name in the SDK's MASM. The OEM keyboard, sound and joystick routines poll for progress because emu2 treats a guest HLT instruction as program termination.

Run `make gwbasic` at the repository root. On the full DOS floppy, type `GWBASIC` for the editor or `GWBASIC DEMO.BAS` to run a file. Type `SYSTEM` to return to DOS. On the host, run `emu2 gwbasic/gwbasic.exe`. Run `make -C gwbasic check` for the emu2 regressions.

The shared language regressions adapt cases from `cpm86-msbasic/tests`. They check arithmetic, strings, arrays, error recovery, DOS files and program editing. If `gwbasic/gwbasic.ref` is present, the emu2 check runs the same cases with the reference interpreter in a separate directory. The PCE suite runs them against the executable on the full DOS floppy.

With the 3.23 reference present, `make check` also exchanges ASCII, tokenized and protected programs, sequential data, random records and BSAVE blocks in both directions. The check covers the shared language subset. The suite checks matching physical file lengths. The directory commands and `TIMER` keyword use the 3.23 token values. Their implementation draws on TK Chia's GWBASICA updates.

### GW-BASIC 3.23 compatibility work

The [numbered 3.23 equivalence inventory](EQUIVALENCE.md) records observed matches, known differences, untested behavior, and intentional startup changes.

## Startup and display

`GWBASIC /NOB /NOR DEMO.BAS` loads the program and stops at the editor's `Ok` prompt. Type `LIST` to inspect it or `RUN` to execute it. The switches follow the CP/M-86 MBASIC 5.50 command-line extensions. They accept mixed case and may appear before or after the filename.

| Switch | Effect |
|---|---|
| `/NOB[ANNER]` | Suppresses the heading, free-memory count and function-key labels. |
| `/NOR[UN]` | Loads the named program and waits for an editor command. |
| `/M:n` | Limits the data segment. Accepts decimal or hexadecimal, e.g. `/M:&HC000`. |
| `/C:n` | Sets the serial buffer size. |
| `/F:n`, `/S:n` | Accepts the MBASIC file-count and record-size options. This build allocates files and records dynamically. |

Redirected startup preserves the existing display. For example, `GWBASIC DEMO.BAS >RESULT.TXT` sends ordinary `PRINT` output to the DOS handle. A short write raises BASIC error 61 (disk full), and other write failures raise error 57. Unhandled write errors go to standard error.

Use `GWBASIC /NOB <COMMANDS.TXT` to execute commands from a DOS text file. `INPUT`, `LINE INPUT` and `INPUT$` also read redirected stdin. End of file at the command prompt returns to DOS. A program that requests more input at EOF can trap BASIC error 62.

An explicit `SCREEN` or `CLS` in the program still operates on the display.

The EGA graphics modes are `SCREEN 7` (320 × 200), `SCREEN 8` (640 × 200), `SCREEN 9` (640 × 350 color), and `SCREEN 10` (640 × 350 monochrome). Active and visible pages can be selected independently within the adapter's reported memory. Graphics array `GET` and `PUT` use scan lines stored as byte-aligned bit planes. On PCE, both 3.23 and 4.01N select `SCREEN 9` on a color EGA and `SCREEN 10` on a monochrome EGA. With 64 KB, each uses four attributes and one page. With 256 KB, each has two pages and the color mode has sixteen attributes. On the tested VGA, `SCREEN 9` succeeds and `SCREEN 10` returns error 5.

## Original Microsoft release notes

This repo contains the original source-code for Microsoft's GW-BASIC interpreter, as of 1983.

## Announcement blog
https://devblogs.microsoft.com/commandline/microsoft-open-sources-gw-basic/

## Information

This repo:

1. Is being released for historical reference/interest purposes, and reflects the state of the GW-BASIC interpreter source code as it was in 1983
1. Will not be modified - please do not submit PR's or request changes
1. Contains no build scripts, makefiles, or tools required to generate executable binaries, nor does it contain any pre-built binaries / executables

## License

All files within this repo are released under the [MIT (OSI) License]( https://en.wikipedia.org/wiki/MIT_License) as per the [LICENSE file](https://github.com/Microsoft/GW-BASIC/blob/master/LICENSE) stored in the root of this repo.

## Contributing

The source files in this repo are for historical reference and will remain read-only and unmodified in their original state. Please  **do not** send Pull Requests suggesting any modifications to the source files.  

Further contribution guidance can be found in the [Contributor's Guide](https://github.com/Microsoft/GW-BASIC/blob/master/CONTRIBUTING.md) stored in the root of this repo.

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).  For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
