# GW-BASIC 3.23 equivalence inventory

Target: the project’s 3.23 DOS binary and 4.01N under identical inputs. The alphabetical reference supplies the named language entries. Additional rows cover editor operations, program startup, operators, interchange and adapter configurations. A row is one work item. Inconclusive means the probe ran but could not isolate the intended behavior. Compound operands, boundary values and device profiles require further cases within it.

Sources: [Microsoft GW-BASIC User’s Reference and Guide, July 1987](https://bitsavers.computerhistory.org/pdf/microsoft/msdos_3.3/MS-DOS_GW-BASIC_198707.pdf), [1989 guide and command-line reference](https://bitsavers.trailing-edge.com/pdf/microsoft/gw-basic/Microsoft_GW-BASIC_Users_Guide_and_Reference_1989.pdf). Supplementary syntax must be verified against the project’s executable.

399 work items: 378 matched, 12 different, 6 inconclusive, 3 intentional.

## Evidence

Matched applies to the input, configuration and observations listed in the row. A matching error or successful statement return establishes only that outcome. The default guest is MS-DOS 4.01N. Display work uses PCE EGA/VGA or QEMU VGA. Event tests require the corresponding event source, file locking requires a SHARE-enabled configuration for successful operations, and printer and serial tests require a captured output device.

- Q — [paired DOS observations](../test/gwaudit.jsonl) from [check_gwaudit](../test/check_gwaudit) and [probe inputs](../test/gwcases.txt). Q entries record historical QEMU runs. Case 216 was rechecked on both PCE adapters. Results retain the reference and build outputs. Statement acceptance alone leaves device delivery, audio, timing and underlying limits unqualified.
- PCE — paired observations recorded on headless PCE with the same runner and JSONL format. Palette registers return the programmed values on VGA. PCE EGA returns FFh on that port, so the EGA cases verify statement execution only.
- A — [arithmetic and language probes](../test/gwmatrix.bas), checked against the optional reference.
- L — [shared language assertions](../test/gwlang.bas), executed by [check_gwbasic](../test/check_gwbasic) on both interpreters.
- P — [shared program-management session](../test/gwprog.txt), with output and listing assertions in check_gwbasic.
- F — [bidirectional DOS file tests](../test/check_gwcompat).
- X — prior two-way 13×3 sprite experiment, 39 pixels and 28 payload bytes per color mode. A permanent oracle for the cross-interpreter experiment remains to be added.
- [4.01N graphics regression](../test/gwvideo.bas) exercises additional forms. Local-only results leave the direct comparison open.

## Running the paired regression

With `gwbasic/gwbasic.ref` present, root `make check` invokes `test/check_gwaudit --quick --check`. This runs 106 probes on both binaries in one headless PCE boot, using the project's `test/run_tests` runner. Select a headless `pce-ibmpc` via PATH. Set `IMG` to pin all comparisons to a private DOS boot image. Each interpreter runs the BASIC fixtures in succession and writes its observations on the scratch floppy. Root checks also run `test/check_gwaudit --editor --check`: eight interactive comparisons share a second PCE boot. They record VGA text cells and the BIOS cursor at the live Ok prompt. Case 301 also records all ten macro expansions through INKEY$.

Root checks repeat case 110 and run two locking fixtures together with DOS SHARE installed (`test/check_gwaudit --share --check`). Cases 374–377 exercise whole-file and range operations with SHARE absent. Ordinary disk I/O uses DOS handles in both configurations. The separate 4.01N regression `test/check_gwbasic --pce` checks handle exhaustion (BASIC error 67, DOS error 4), protection against deleting an open file, and byte-exact recovery after a disk-full write and RESUME.

PCE is the default for the paired audit, including timer and PLAY handler delivery and single cases such as `test/check_gwaudit --check 216`. For program probes, `PCE_VIDEO=ega` or `PCE_VIDEO=vga` selects the adapter. Interactive editor probes use VGA. The remaining historical probe runner requires explicit `--qemu`; it covers additional observations such as BIOS keyboard input and cursor position.

For the selected IDs, the gate checks each case marked **Matched** against both the live 3.23 run and its recorded output. Incomplete observations fail in every category. The three default PCE batches rerun 116 of the 250 recorded case IDs. The other 134 retain earlier observations. Across all 250 records the matrix lists 233 matched, 11 different and 6 inconclusive cases. The 12 Different rows count classified probes. Additional differences described within rows include the mode change after case 216 and extended-error state after case 46. A known difference that now matches is reported for review. After verifying a fix, update that case’s JSONL record, matrix status and counts together. Root checks also run `test/check_gwega` on both binaries with four EGA profiles (64K/256K, color/monochrome) and VGA. This requires a PCE build with configurable EGA memory. The remaining inventory rows use the other evidence listed above.

Case 46 exercises both a write-protected floppy and a DOS character driver that rejects writes. Under RESUME NEXT both interpreters report out of paper at PRINT and again at explicit CLOSE, with matching ERL, ERR, ERDEV, ERDEV$ and EXTERR(0). When the active handler issues an unqualified CLOSE, both invoke it again with ERL = 65535 and error 27. The paired regression checks both forms.

A separate handler using `IF ERL=65535 THEN RESUME 140` produced syntax diagnostics in both versions. The transcripts differed in their line numbers and Ok prompts. That compound error path remains open.

Starting another program with RUN after the nested fault also leaves EXTERR(0) at 28 in 3.23 and 0 in 4.01N. The audit starts a fresh interpreter after case 46 so later fixtures have independent initial conditions.

Additional paired PCE startup probes found that 3.23 prints .8414709848078965 for SIN(1#) under /D and .841471 without it. The historical case 280 uses MKS$, which forces single precision. With /I/F:2/S:64, 3.23 rejects file number 7 with error 52 and random record length 129 with error 5. With /M:49152,3071 it reports out of memory, while /M:49152,3072 starts successfully. 4.01N matches that /M boundary. With the byte count omitted, a small program starts with /M:,300 in 4.01N and gives Out of memory in 3.23. Both execute it with /M:,384. The /D and /I switch probes remain different.

Supplementary PCE VGA probes for cases 196 and 223 compared 3.23 with 4.01N before and after the graphics parser move. Both 4.01N builds produced identical reports. The numbered cases cover the successful graphics-mode forms. Two additional behaviors remain open.

| Input | 3.23 | 4.01N |
|---|---|---|
| In `SCREEN 7`, set `VIEW (10,20)-(40,80)` and `WINDOW (-1,-2)-(3,6)` before each attempt. Try `WINDOW (1,2)-(1,3)` or `WINDOW (1,2)-(3,2)`, then inspect `PMAP(0,0)` and `PMAP(0,1)` after `RESUME NEXT`. | Error 5, then (−8, −15) | Error 5, then the previous mapping (8, 45) |
| With the same starting bounds, try `WINDOW (1,2)-(3,4) JUNK`. | Error 2, then (−15, 120) | Error 2, then (8, 45) |
| After the preceding sequence, issue `WINDOW` and `SCREEN 0`, then evaluate `PMAP(7,I)` for selectors 0 through 3. | 7 for each selector | 0 for each selector |

A fresh interpreter in `SCREEN 0` returned 0 for `PMAP(7,3)` in both versions.

## Differences by work area

Each row below groups failed observations for investigation. The count measures inventory coverage; shared causes and the number of required changes still need diagnosis. Input echo, printer formatting and adapter selection can differ even when a program computes the same value.

| Work area | Rows | Inventory IDs |
|---|---:|---|
| DOS environment and command execution | 3 | 40, 145, 146 |
| Command streams, prompts and diagnostics | 1 | 277 |
| Keyboard, editor and function keys | 1 | 393 |
| Serial I/O | 4 | 233, 395, 396, 397 |
| Startup switches | 3 | 280, 281, 286 |

## Numbered matrix

| ID | Behavior | Configuration | Status | Evidence or observed difference |
|---:|---|---|---|---|
| 001 | `ABS` | DOS | Matched | L |
| 002 | `ASC` | DOS | Matched | A |
| 003 | `ATN` | DOS | Matched | A |
| 004 | `AUTO` | DOS | Matched | Q, case 4 |
| 005 | `BEEP` | DOS | Matched | Q, case 5; statement accepted and returned |
| 006 | `BLOAD` | DOS | Matched | F |
| 007 | `BSAVE` | DOS | Matched | F |
| 008 | `CALL` | DOS | Matched | Q, case 8 |
| 009 | `CDBL` | DOS | Matched | A |
| 010 | `CHAIN` | DOS | Matched | P |
| 011 | `CHAIN MERGE` | DOS | Matched | Q, case 11 |
| 012 | `CHAIN ALL` | DOS | Matched | Q, case 12 |
| 013 | `CHAIN MERGE DELETE` | DOS | Matched | Q, case 13 |
| 014 | `CHDIR` | DOS | Matched | L |
| 015 | `CHR$` | DOS | Matched | A |
| 016 | `CINT` | DOS | Matched | A |
| 017 | `CLEAR` | DOS | Matched | Q, case 17 |
| 018 | `CLOSE` | DOS | Matched | L |
| 019 | `COMMON` | DOS | Matched | P |
| 020 | `CONT` | DOS | Matched | Q, case 20 |
| 021 | `COS` | DOS | Matched | A |
| 022 | `CSNG` | DOS | Matched | A |
| 023 | `CVD` | DOS | Matched | L |
| 024 | `CVI` | DOS | Matched | L |
| 025 | `CVS` | DOS | Matched | L |
| 026 | `DATA` | DOS | Matched | L |
| 027 | `DATE$ read` | DOS | Matched | Q, case 27 |
| 028 | `DATE$ assignment` | DOS | Matched | Q, case 28 |
| 029 | `DEF FN` | DOS | Matched | L |
| 030 | `DEFINT` | DOS | Matched | Q, case 30 |
| 031 | `DEFDBL` | DOS | Matched | Q, case 31 |
| 032 | `DEFSNG` | DOS | Matched | Q, case 32 |
| 033 | `DEFSTR` | DOS | Matched | Q, case 33 |
| 034 | `DEF SEG` | DOS | Matched | Q, case 34 |
| 035 | `DEF USR` | DOS | Matched | Q, case 35; statement accepted and returned |
| 036 | `DELETE` | DOS | Matched | P |
| 037 | `DIM` | DOS | Matched | L |
| 038 | `EDIT` | DOS | Matched | Q, case 38 |
| 039 | `END` | DOS | Matched | Q, case 39 |
| 040 | `ENVIRON assignment` | DOS | Different | PCE, case 40. 3.23 replaces, adds and deletes variables in its child environment. It reports error 7 on growth past capacity, preserves the old value, and rejects an empty name with error 5. 4.01N reports error 73 on every assignment. |
| 041 | `ENVIRON$(name)` | DOS | Matched | L |
| 042 | `ENVIRON$(index)` | DOS | Matched | L |
| 043 | `EOF` | DOS | Matched | L |
| 044 | `ERASE` | DOS | Matched | L |
| 045 | `ERDEV` | DOS | Matched | PCE, case 45. Write-protected floppy: BASIC error 70 and ERDEV 512, cleared by RESUME. |
| 046 | `ERDEV$` | DOS | Matched | PCE, case 46. ERDEV$ identifies the write-protected drive and failing character device. PRINT and CLOSE fault at the same lines after RESUME NEXT. |
| 047 | `ERL` | DOS | Matched | L |
| 048 | `ERR` | DOS | Matched | L |
| 049 | `ERROR` | DOS | Matched | L |
| 050 | `EXP` | DOS | Matched | L |
| 051 | `EXTERR` | DOS | Matched | PCE, case 51. DOS code, class, action and locus after failed OPEN and CHDIR, invalid selector and RESUME. The cross-program case following a nested device error is described above. |
| 052 | `FIELD` | DOS | Matched | L |
| 053 | `FILES` | DOS | Matched | PCE, case 53. Directory header, padded listing and free-byte count for A:CONFIG.SYS. The runner independently checks the count against the boot volume. |
| 054 | `FIX` | DOS | Matched | L |
| 055 | `FOR … NEXT` | DOS | Matched | L |
| 056 | `NEXT multi-variable` | DOS | Matched | L |
| 057 | `FRE(number)` | DOS | Matched | Q, case 57 |
| 058 | `FRE(string)` | DOS | Matched | Q, case 58 |
| 059 | `GET record` | DOS | Matched | L |
| 060 | `GET next record` | DOS | Matched | L |
| 061 | `GOSUB` | DOS | Matched | Q, case 61 |
| 062 | `RETURN` | DOS | Matched | A |
| 063 | `RETURN line` | DOS | Matched | Q, case 63 |
| 064 | `GOTO` | DOS | Matched | P |
| 065 | `HEX$` | DOS | Matched | A |
| 066 | `IF THEN statement` | DOS | Matched | L |
| 067 | `IF THEN line` | DOS | Matched | A |
| 068 | `IF GOTO` | DOS | Matched | Q, case 68 |
| 069 | `IF THEN ELSE` | DOS | Matched | Q, case 69 |
| 070 | `INPUT` | DOS | Matched | PCE, case 70. Redirected numeric and string input, prompt, echo and stored values. |
| 071 | `INPUT#` | DOS | Matched | L |
| 072 | `INPUT$(console)` | DOS | Matched | Q, case 72 |
| 073 | `INPUT$(file)` | DOS | Matched | Q, case 73 |
| 074 | `INSTR` | DOS | Matched | L |
| 075 | `INT` | DOS | Matched | L |
| 076 | `KILL` | DOS | Matched | L |
| 077 | `LEFT$` | DOS | Matched | L |
| 078 | `LEN` | DOS | Matched | L |
| 079 | `LET explicit` | DOS | Matched | A |
| 080 | `LET implicit` | DOS | Matched | L |
| 081 | `LINE INPUT` | DOS | Matched | PCE, case 81. Redirected line containing a comma, including echo and stored text. |
| 082 | `LINE INPUT#` | DOS | Matched | L |
| 083 | `LIST` | DOS | Matched | Q, case 83 |
| 084 | `LIST to file` | DOS | Matched | Q, case 84 |
| 085 | `LOAD` | DOS | Matched | P |
| 086 | `LOAD ,R` | DOS | Matched | Q, case 86 |
| 087 | `LOC` | DOS | Matched | L. PCE case 231 also checks byte position on NUL before and after 133 bytes. |
| 088 | `LOF` | DOS | Matched | L. PCE case 231 also checks NUL reports length 1 on open for append and 133 after writing 133 bytes. |
| 089 | `LOG` | DOS | Matched | L |
| 090 | `LSET` | DOS | Matched | L |
| 091 | `MERGE` | DOS | Matched | P |
| 092 | `MID$ function` | DOS | Matched | L |
| 093 | `MID$ assignment` | DOS | Matched | L |
| 094 | `MKDIR` | DOS | Matched | L |
| 095 | `MKD$` | DOS | Matched | L |
| 096 | `MKI$` | DOS | Matched | L |
| 097 | `MKS$` | DOS | Matched | L |
| 098 | `NAME` | DOS | Matched | Q, case 98 |
| 099 | `NEW` | DOS | Matched | P |
| 100 | `OCT$` | DOS | Matched | A |
| 101 | `ON ERROR GOTO` | DOS | Matched | L |
| 102 | `ON ERROR GOTO 0` | DOS | Matched | PCE, case 102. Disabling the error handler in a redirected program prints Illegal function call and returns to DOS. |
| 103 | `ON … GOSUB` | DOS | Matched | A |
| 104 | `ON … GOTO` | DOS | Matched | A |
| 105 | `OPEN INPUT` | DOS | Matched | Q, case 105 |
| 106 | `OPEN OUTPUT` | DOS | Matched | P |
| 107 | `OPEN APPEND` | DOS | Matched | P |
| 108 | `OPEN RANDOM` | DOS | Matched | Q, case 108 |
| 109 | `OPEN legacy mode string` | DOS | Matched | L |
| 110 | `OPEN ACCESS and sharing` | DOS | Matched | PCE, case 110. OPEN FOR INPUT ACCESS READ SHARED reads ALPHA from an existing file. |
| 111 | `OPTION BASE 0` | DOS | Matched | Q, case 111 |
| 112 | `OPTION BASE 1` | DOS | Matched | L |
| 113 | `PRINT` | DOS | Matched | Q, case 113 |
| 114 | `PRINT USING` | DOS | Matched | Q, case 114 |
| 115 | `PRINT#` | DOS | Matched | L |
| 116 | `PRINT# USING` | DOS | Matched | L |
| 117 | `PUT record` | DOS | Matched | L |
| 118 | `PUT next record` | DOS | Matched | Q, case 118 |
| 119 | `RANDOMIZE seed` | DOS | Matched | Q, case 119 |
| 120 | `RANDOMIZE prompt` | DOS | Matched | PCE, case 120. Prompt, redirected seed 203 and resulting RND value. |
| 121 | `READ` | DOS | Matched | L |
| 122 | `REM` | DOS | Matched | Q, case 122 |
| 123 | `apostrophe comment` | DOS | Matched | Q, case 123 |
| 124 | `RENUM` | DOS | Matched | P |
| 125 | `RESET` | DOS | Matched | Q, case 125 |
| 126 | `RESTORE` | DOS | Matched | L |
| 127 | `RESTORE line` | DOS | Matched | A |
| 128 | `RESUME` | DOS | Matched | Q, case 128 |
| 129 | `RESUME NEXT` | DOS | Matched | L |
| 130 | `RESUME line` | DOS | Matched | L |
| 131 | `RIGHT$` | DOS | Matched | L |
| 132 | `RMDIR` | DOS | Matched | L |
| 133 | `RND negative` | DOS | Matched | Q, case 133 |
| 134 | `RND zero` | DOS | Matched | Q, case 134 |
| 135 | `RND positive or omitted` | DOS | Matched | Q, case 135 |
| 136 | `RSET` | DOS | Matched | L |
| 137 | `RUN` | DOS | Matched | P |
| 138 | `RUN line` | DOS | Matched | Q, case 138 |
| 139 | `RUN file` | DOS | Matched | Q, case 139 |
| 140 | `RUN file,R` | DOS | Matched | Q, case 140 |
| 141 | `SAVE tokenized` | DOS | Matched | P |
| 142 | `SAVE ASCII` | DOS | Matched | P |
| 143 | `SAVE protected` | DOS | Matched | F |
| 144 | `SGN` | DOS | Matched | A |
| 145 | `SHELL command` | DOS | Different | Manual PCE comparison. SHELL with an ECHO command created the requested file in 3.23. In 4.01N it raised syntax error 2 and the file was absent. |
| 146 | `SHELL interactive` | DOS | Different | Q, case 146; 3.23 BACK / DONE, 4.01N ERROR 2  100 |
| 147 | `SIN` | DOS | Matched | L |
| 148 | `SPACE$` | DOS | Matched | A |
| 149 | `SPC` | DOS | Matched | Q, case 149 |
| 150 | `SQR` | DOS | Matched | A |
| 151 | `STOP` | DOS | Matched | PCE, case 151. STOP in a redirected program prints Break and returns to DOS before a queued CONT. |
| 152 | `STR$` | DOS | Matched | A |
| 153 | `STRING$ numeric` | DOS | Matched | L |
| 154 | `STRING$ string` | DOS | Matched | A |
| 155 | `SWAP` | DOS | Matched | L |
| 156 | `SYSTEM` | DOS | Matched | L |
| 157 | `TAB` | DOS | Matched | Q, case 157 |
| 158 | `TAN` | DOS | Matched | A |
| 159 | `TIME$ read` | DOS | Matched | L |
| 160 | `TIME$ assignment` | DOS | Inconclusive | Q, case 160; RTC tick boundary |
| 161 | `TIMER function` | DOS | Matched | L |
| 162 | `TROFF` | DOS | Matched | Q, case 162 |
| 163 | `TRON` | DOS | Matched | Q, case 163 |
| 164 | `USR` | DOS | Matched | Q, case 164 |
| 165 | `VAL` | DOS | Matched | L |
| 166 | `VARPTR(variable)` | DOS | Matched | Q, case 166 |
| 167 | `VARPTR(file)` | DOS | Matched | Q, case 167 |
| 168 | `VARPTR$` | DOS | Matched | Q, case 168 |
| 169 | `WHILE … WEND` | DOS | Matched | A |
| 170 | `WRITE` | DOS | Matched | Q, case 170 |
| 171 | `WRITE#` | DOS | Matched | L |
| 172 | `CIRCLE` | Display | Matched | Q, case 172 |
| 173 | `CLS` | Display | Matched | Q, case 173 |
| 174 | `CLS 0/1/2` | Display | Matched | Q, case 174 |
| 175 | `COLOR text` | Display | Matched | Q, case 175 |
| 176 | `COLOR CGA` | Display | Matched | Q, case 176 |
| 177 | `COLOR EGA` | Display | Matched | Q, case 177 |
| 178 | `CSRLIN` | Display | Matched | Q, case 178 |
| 179 | `DRAW` | Display | Matched | Q, case 179 |
| 180 | `GET graphics` | Display | Matched | X |
| 181 | `INKEY$` | Display | Matched | Q, case 181 |
| 183 | `KEY ON` | Display | Matched | Q, case 183; statement accepted and returned |
| 184 | `KEY OFF` | Display | Matched | Q, case 184; statement accepted and returned |
| 186 | `LINE` | Display | Matched | Q, case 186 |
| 187 | `LINE B` | Display | Matched | Q, case 187 |
| 188 | `LINE BF` | Display | Matched | Q, case 188 |
| 189 | `LOCATE` | Display | Matched | Q, case 189 |
| 190 | `PAINT solid` | Display | Matched | Q, case 190 |
| 191 | `PAINT tile` | Display | Matched | PCE, case 191. CGA alternating tile rows, the 64-row CGA limit and EGA bit-plane colors. |
| 192 | `PALETTE reset` | Display | Matched | PCE, case 192, reset restores attribute 1 |
| 193 | `PALETTE attribute,color` | Display | Matched | PCE, case 193, color 15 maps to 1Fh and -1 preserves it |
| 194 | `PALETTE USING` | Display | Matched | PCE, case 194, integer array starting at index 2 sets attribute 1 |
| 195 | `PCOPY` | Display | Matched | Reference page-copy probe and [independent page checks](../test/gwvideo.bas) |
| 196 | `PMAP` | Display | Matched | PCE, case 196, four mapping selectors, inverse fractions, and default rounding. See the supplementary text-mode probe above. |
| 197 | `POINT(x,y)` | Display | Matched | X |
| 198 | `POINT(selector)` | Display | Matched | PCE, case 198, selectors 0–3 and pixel readback in SCREEN 7. Both preserve the cursor after SCREEN 0 and a chained RUN |
| 199 | `POS` | Display | Matched | Q, case 199 |
| 200 | `PRESET` | Display | Matched | Q, case 200 |
| 201 | `PSET` | Display | Matched | X |
| 202 | `PUT graphics PSET` | Display | Matched | X |
| 203 | `PUT graphics PRESET` | Display | Matched | Q, case 203 |
| 204 | `PUT graphics AND` | Display | Matched | Q, case 204 |
| 205 | `PUT graphics OR` | Display | Matched | Q, case 205 |
| 206 | `PUT graphics XOR` | Display | Matched | Q, case 206 |
| 207 | `SCREEN(row,col)` | Display | Matched | Q, case 207 |
| 208 | `SCREEN(row,col,1)` | Display | Matched | Q, case 208 |
| 209 | `SCREEN 0` | Display | Matched | Q, case 209. PCE case 221 checks BIOS mode 3 at 80 columns and preservation of the text window on repeated SCREEN 0. |
| 210 | `SCREEN 1` | Display | Matched | Q, case 210 |
| 211 | `SCREEN 2` | Display | Matched | Q, case 211 |
| 212 | `SCREEN 7` | Display | Matched | X |
| 213 | `SCREEN 8` | Display | Matched | X |
| 214 | `SCREEN 9` | Display | Matched | [Paired PCE display regression](../test/check_gwega). Available on 64K/256K color EGA and VGA. Both return error 5 on monochrome EGA. |
| 215 | `SCREEN 10` | Display | Matched | PCE, case 215 and paired display regression. Available on 64K/256K monochrome EGA (0x0a). Both return error 5 on color EGA (0x09) and VGA. |
| 216 | `SCREEN active and visible pages` | Display | Matched | PCE EGA and VGA, case 216; both read 0 on page 0 and 3 on page 1. After this page-1 sequence, a subsequent SCREEN 1 with omitted pages raises error 5 in 3.23 and succeeds in 4.01N. Case 217 explicitly selects page zero. |
| 217 | `VIEW graphics` | Display | Matched | PCE, case 217, reversed viewport corners, fill, border and bounded CGA flood fill |
| 218 | `VIEW SCREEN` | Display | Matched | PCE, case 218, absolute screen coordinates and clipping |
| 219 | `VIEW reset` | Display | Matched | PCE, case 219, viewport clear and clipped diagonal, followed by full-screen reset |
| 220 | `VIEW PRINT range` | Display | Matched | PCE, case 220. Clearing and scrolling rows 5–10 preserve sentinel characters on rows 4 and 11. |
| 221 | `VIEW PRINT reset` | Display | Matched | PCE, case 221. A single-row window scrolls in place. Reset homes the cursor and releases the LOCATE range restriction. |
| 222 | `WIDTH screen` | Display | Matched | Q, case 222 |
| 223 | `WINDOW` | Display | Matched | PCE, case 223, Cartesian Y, fractional STEP and physical pixel readback. See the supplementary rejected-WINDOW probes above. |
| 224 | `WINDOW SCREEN` | Display | Matched | PCE, case 224, screen-oriented Y on a relative viewport |
| 225 | `WINDOW reset` | Display | Matched | PCE, case 225, reset preserves pixel cursor and restores identity mapping |
| 226 | `INP` | Devices | Matched | Q, case 226 |
| 227 | `OUT` | Devices | Matched | Q, case 227 |
| 228 | `WAIT` | Devices | Matched | Q, case 228 |
| 229 | `PEEK` | Devices | Matched | Q, case 229 |
| 230 | `POKE` | Devices | Matched | Q, case 230 |
| 231 | `IOCTL` | Devices | Matched | PCE, case 231. Sends FFh to the control device and reads it back. A regular file raises error 5. |
| 232 | `IOCTL$` | Devices | Matched | PCE, case 232. Reads a one-byte control reply containing NUL. A regular file raises error 5. |
| 233 | `OPEN COM` | Devices | Different | Q, case 233; 3.23 DONE, 4.01N ERROR 57  100 |
| 234 | `OPEN device` | Devices | Matched | Q, case 234; statement accepted and returned |
| 235 | `LPOS` | Devices | Matched | Q, case 235 |
| 236 | `LLIST` | Devices | Matched | Q, case 236 |
| 237 | `LPRINT` | Devices | Matched | Q, case 237 |
| 238 | `LPRINT USING` | Devices | Matched | Q, case 238 |
| 239 | `WIDTH device` | Devices | Matched | Q, case 239 |
| 240 | `WIDTH file` | Devices | Matched | Q, case 240; statement accepted and returned |
| 241 | `PEN function` | Devices | Matched | Q, case 241 |
| 242 | `STICK` | Devices | Matched | PCE, case 242. Four disconnected axes return zero. Selector 4 raises error 5. |
| 243 | `STRIG function` | Devices | Matched | Q, case 243 |
| 244 | `STRIG ON` | Devices | Matched | Q, case 244; statement accepted and returned |
| 245 | `STRIG OFF` | Devices | Matched | Q, case 245; statement accepted and returned |
| 246 | `PLAY music` | Devices | Matched | Q, case 246; statement accepted and returned |
| 247 | `PLAY(n) queue` | Devices | Matched | PCE, case 247, queued notes counted for both selector values tested |
| 248 | `SOUND` | Devices | Matched | Q, case 248; statement accepted and returned |
| 249 | `LOCK` | DOS + SHARE | Matched | PCE, case 249. Whole-file and large record locks, owner GET/PUT, disjoint and overlapping locks through another handle. |
| 250 | `UNLOCK` | DOS + SHARE | Matched | PCE, case 250. CLOSE releases outstanding locks. Unlocking two separately locked records as one range raises error 70. |
| 251 | `ON COM(n) GOSUB` | Event source | Matched | Q, case 251; statement accepted and returned |
| 252 | `COM(n) ON` | Event source | Matched | Q, case 252; statement accepted and returned |
| 253 | `COM(n) OFF` | Event source | Matched | Q, case 253; statement accepted and returned |
| 254 | `COM(n) STOP` | Event source | Matched | Q, case 254; statement accepted and returned |
| 255 | `ON KEY(n) GOSUB` | Event source | Matched | Q, case 255; statement accepted and returned |
| 256 | `KEY(n) ON` | Event source | Matched | Q, case 256; statement accepted and returned |
| 257 | `KEY(n) OFF` | Event source | Matched | Q, case 257; statement accepted and returned |
| 258 | `KEY(n) STOP` | Event source | Matched | Q, case 258; statement accepted and returned |
| 259 | `ON PEN GOSUB` | Event source | Matched | Q, case 259; statement accepted and returned |
| 260 | `PEN ON` | Event source | Matched | Q, case 260; statement accepted and returned |
| 261 | `PEN OFF` | Event source | Matched | Q, case 261; statement accepted and returned |
| 262 | `PEN STOP` | Event source | Matched | Q, case 262; statement accepted and returned |
| 263 | `ON PLAY(n) GOSUB` | Event source | Matched | PCE, case 263, background queue crossing invokes handler |
| 264 | `PLAY ON` | Event source | Matched | PCE, case 264, event control accepted |
| 265 | `PLAY OFF` | Event source | Matched | PCE, case 265, OFF suppresses handler |
| 266 | `PLAY STOP` | Event source | Matched | PCE, case 266, STOP defers one handler until ON |
| 267 | `ON STRIG(n) GOSUB` | Event source | Matched | Q, case 267; statement accepted and returned |
| 268 | `STRIG(n) ON` | Event source | Matched | Q, case 268; statement accepted and returned |
| 269 | `STRIG(n) OFF` | Event source | Matched | Q, case 269; statement accepted and returned |
| 270 | `STRIG(n) STOP` | Event source | Matched | Q, case 270; statement accepted and returned |
| 271 | `ON TIMER(n) GOSUB` | Event source | Matched | PCE, case 271, timer expiration invokes handler |
| 272 | `TIMER ON` | Event source | Matched | PCE, case 272, event control accepted |
| 273 | `TIMER OFF` | Event source | Matched | PCE, case 273, OFF suppresses handler |
| 274 | `TIMER STOP` | Event source | Matched | PCE, case 274, STOP defers one handler until ON |
| 275 | `Program filename` | DOS startup | Matched | Q, case 275 |
| 276 | `Interactive start` | DOS startup | Matched | Q, case 276 |
| 277 | `stdin redirection` | DOS startup | Different | Q, case 277; output differs |
| 278 | `stdout redirection` | DOS startup | Matched | Q, case 278 |
| 279 | `stdout append` | DOS startup | Matched | Q, case 279 |
| 280 | `/D` | DOS startup | Different | Q, case 280; 3.23 RUNNING / DONE, 4.01N see transcript |
| 281 | `/I` | DOS startup | Different | Q, case 281; 3.23 RUNNING / DONE, 4.01N see transcript |
| 282 | `/C:n` | DOS startup | Matched | Q, case 282. Both accepted /C:256 and ran the program. Serial buffer capacity was not measured. |
| 283 | `/F:n` | DOS startup | Matched | Q, case 283. Both accepted /F:6 and ran the program. This probe never reaches the file-number limit. |
| 284 | `/S:n` | DOS startup | Matched | Q, case 284. Both accepted /S:256 and ran the program. This probe never opens a random file. |
| 285 | `/M:n` | DOS startup | Matched | Q, case 285. Both accepted /M:49152 and ran the program. This probe does not measure available memory. |
| 286 | `/M:n,maximum block` | DOS startup | Different | PCE, case 286. With a 49152-byte workspace, 3071 paragraphs give Out of memory. Both 3072 and 4096 paragraphs start the program. With /M:,300, 3.23 rejects the small PRINT fixture and 4.01N runs it. |
| 287 | `Startup banner` | DOS startup | Intentional | 4.01N startup extension |
| 288 | `/NOBANNER` | DOS startup | Intentional | 4.01N startup extension |
| 289 | `/NORUN` | DOS startup | Intentional | 4.01N startup extension |
| 290 | `Enter numbered line` | Screen editor | Matched | Q, case 290 |
| 291 | `Replace numbered line` | Screen editor | Matched | Q, case 291 |
| 292 | `Delete numbered line` | Screen editor | Matched | Q, case 292 |
| 293 | `Direct command` | Screen editor | Matched | Q, case 293 |
| 294 | `Cursor left/right/up/down` | Screen editor | Matched | PCE, case 294. Arrow sequence, including the cursor before and after Up. |
| 295 | `Word left/right` | Screen editor | Matched | PCE, case 295. Word navigation and overwrite within ABC DEF. |
| 296 | `Home and End` | Screen editor | Matched | Q, case 296 |
| 297 | `Insert and Delete` | Screen editor | Matched | PCE, case 297. Intermediate ABCXDE after Insert and final ABCXE after Delete. |
| 298 | `Backspace` | Screen editor | Matched | Q, case 298 |
| 299 | `Escape line cancellation` | Screen editor | Matched | PCE, case 299. Esc discards ABCDE before entering XYZ. |
| 300 | `Tab and backtab` | Screen editor | Matched | Q, case 300 |
| 301 | `Function keys F1–F10` | Screen editor | Matched | PCE, case 301. All ten default macro byte strings and the final Ok screen after F10. |
| 302 | `Ctrl-Break and continuation` | Screen editor | Inconclusive | Ctrl-Pause produced a break in 4.01N. The reference had not reached a prompt at the snapshot; repeat with a guest-side completion marker. |
| 303 | `Control-key editing shortcuts` | Screen editor | Matched | Q, case 303 |
| 304 | `Logical line wrapping` | Screen editor | Inconclusive | Input and cursor snapshots did not establish that the intended full-length logical line was received. Repeat with BIOS-buffer synchronization. |
| 305 | `Integer, single and double literals` | Language | Matched | Q, case 305 |
| 306 | `Hex and octal constants` | Language | Matched | L |
| 307 | `String literals` | Language | Matched | Q, case 307 |
| 308 | `Variable type suffixes and defaults` | Language | Matched | Q, case 308 |
| 309 | `Array dimensions and subscripts` | Language | Matched | L |
| 310 | `Addition` | Language | Matched | L |
| 311 | `Subtraction` | Language | Matched | L |
| 312 | `Multiplication` | Language | Matched | L |
| 313 | `Floating division` | Language | Matched | L |
| 314 | `Integer division` | Language | Matched | A |
| 315 | `Exponentiation` | Language | Matched | A |
| 316 | `Unary signs` | Language | Matched | L |
| 317 | `MOD` | Language | Matched | L |
| 318 | `Numeric comparisons` | Language | Matched | L |
| 319 | `String comparisons` | Language | Matched | L |
| 320 | `String concatenation` | Language | Matched | L |
| 321 | `NOT` | Language | Matched | A |
| 322 | `AND` | Language | Matched | L |
| 323 | `OR` | Language | Matched | L |
| 324 | `XOR` | Language | Matched | A |
| 325 | `EQV` | Language | Matched | A |
| 326 | `IMP` | Language | Matched | A |
| 327 | `Precedence and parentheses` | Language | Matched | A |
| 328 | `Overflow, rounding and coercion` | Language | Matched | Q, case 328 |
| 329 | `Line numbers and references` | Language | Matched | Q, case 329 |
| 330 | `Colon statement separator` | Language | Matched | L |
| 331 | `Question mark PRINT shorthand` | Language | Matched | Q, case 331 |
| 332 | `ASCII program interchange` | DOS files | Matched | F |
| 333 | `Tokenized program interchange` | DOS files | Matched | F |
| 334 | `Protected program interchange` | DOS files | Matched | F |
| 335 | `Sequential data interchange` | DOS files | Matched | F |
| 336 | `Random MBF record interchange` | DOS files | Matched | F |
| 337 | `BSAVE block interchange` | DOS files | Matched | F |
| 338 | `EGA graphics-array interchange SCREEN 7` | Display files | Matched | X |
| 339 | `EGA graphics-array interchange SCREEN 8` | Display files | Matched | X |
| 340 | `EGA graphics-array interchange SCREEN 9` | Display files | Matched | X |
| 341 | `EGA graphics-array interchange SCREEN 10` | Display files | Matched | PCE monochrome EGA switches 0x0A and 0x0B. Each interpreter saved a 13×3 four-attribute sprite and read all 39 pixels from the other interpreter’s saved array. |
| 342 | `64 KB EGA addressing` | Display files | Matched | [Paired PCE fixture](../test/gw64k.bas). SCREEN 9 on color and SCREEN 10 on monochrome each recover 1,050 sampled pixels and the bottom-right corner, match plane bytes, and reject page 1. Physical hardware remains untested. |
| 343 | `Runtime error numbers, messages and recovery` | DOS | Matched | Q, case 343. ERROR 52 was trapped at line 100 in both. The probe records ERR and ERL only. |
| 344 | `DOS device errors and extended errors` | DOS | Matched | Q, case 344. Opening a missing file raised BASIC error 53 at line 100 in both. See case 51 for the EXTERR fields. |
| 345 | `DRAW movement U/D/L/R/E/F/G/H` | Display | Matched | Q, case 345 |
| 346 | `DRAW M absolute/relative` | Display | Matched | Q, case 346 |
| 347 | `DRAW B and N prefixes` | Display | Matched | Q, case 347 |
| 348 | `DRAW A and TA rotation` | Display | Matched | PCE, case 348. Rotation, accumulated fractional movement, aspect correction and angle limits. A separate degree sweep matched 722 endpoints in SCREEN 7 and SCREEN 2. |
| 349 | `DRAW C and S` | Display | Matched | Q, case 349 |
| 350 | `DRAW X substring` | Display | Matched | Q, case 350 |
| 351 | `DRAW P fill` | Display | Matched | PCE, case 351, fill color, border and exterior pixels checked |
| 352 | `DRAW variable substitution` | Display | Matched | Q, case 352 |
| 353 | `CIRCLE arc and aspect` | Display | Matched | Q, case 353 |
| 354 | `LINE styled segments` | Display | Matched | PCE, case 354, alternating mask checked across five pixels |
| 355 | `STEP relative coordinates` | Display | Matched | Q, case 355 |
| 356 | `PAINT background tile` | Display | Matched | PCE, case 356. CGA background byte controls fill across matching rows. A solid tile identical to its background raises error 5. |
| 357 | `COLOR foreground/background/border` | Display | Matched | Q, case 357 |
| 358 | `KEY user-defined event key` | Display | Matched | PCE, case 358. The first A triggers KEY(15). The handler disables the trap and INKEY$ receives the second A. Slots 15 and 20 and Shift definitions 1, 2 and 3 also matched in supplementary PCE runs. |
| 360 | `SCREEN color switch` | Display | Matched | Q, case 360 |
| 361 | `PLAY note and accidental` | Sound | Matched | Q, case 361; statement accepted and returned |
| 362 | `PLAY octave and octave shifts` | Sound | Matched | Q, case 362; both accept relative octave shifts. Speaker output uncaptured. |
| 363 | `PLAY note number and rest` | Sound | Matched | Q, case 363; statement accepted and returned |
| 364 | `PLAY length and dotted note` | Sound | Matched | Q, case 364; statement accepted and returned |
| 365 | `PLAY tempo` | Sound | Matched | Q, case 365; statement accepted and returned |
| 366 | `PLAY articulation` | Sound | Matched | Q, case 366; statement accepted and returned |
| 367 | `PLAY foreground/background` | Sound | Matched | Q, case 367; statement accepted and returned |
| 368 | `PLAY X substring and variable substitution` | Sound | Matched | Q, case 368; statement accepted and returned |
| 369 | `PRINT zones and separators` | DOS | Matched | Q, case 369. A separate comma-delimited PRINT #1 of four PMAP results differed in spacing before the final field. The numeric fields matched. |
| 370 | `PRINT USING numeric masks` | DOS | Matched | L (file output) |
| 371 | `PRINT USING string fields` | DOS | Matched | L (file output) |
| 372 | `PRINT USING literal escapes` | DOS | Matched | Q, case 372 |
| 373 | `OPEN LEN` | DOS | Matched | Q, case 373 (8-byte record); L (reopen and read a sparse 20-byte record file) |
| 374 | `LOCK whole file` | DOS | Matched | PCE, case 374. Returns error 70 when SHARE is absent. |
| 375 | `LOCK record range` | DOS | Matched | PCE, case 375. Returns error 70 when SHARE is absent. |
| 376 | `UNLOCK whole file` | DOS | Matched | PCE, case 376. Returns error 70 when SHARE is absent. |
| 377 | `UNLOCK record range` | DOS | Matched | PCE, case 377. Returns error 70 when SHARE is absent. |
| 378 | `CLEAR string space, memory limit and stack` | DOS | Matched | Q, case 378 |
| 379 | `DEF FN arguments and result type` | DOS | Matched | Q, case 379 |
| 380 | `INSTR with start offset` | DOS | Matched | L |
| 381 | `MID$ optional length` | DOS | Matched | Q, case 381 |
| 382 | `LIST line ranges` | DOS | Matched | Q, case 382 |
| 383 | `LIST current line` | DOS | Matched | Q, case 383 |
| 384 | `RENUM reference rewriting` | DOS | Matched | P |
| 385 | `Implicit and explicit line-number references` | DOS | Matched | Q, case 385 |
| 386 | `DATA quoted strings and empty fields` | DOS | Matched | Q, case 386 |
| 387 | `Integer division rounding` | DOS | Matched | Q, case 387 |
| 388 | `Single versus double precision promotion` | DOS | Matched | Q, case 388 |
| 389 | `Clear to end of line` | Screen editor | Matched | PCE, case 389. Ctrl-End truncates ABCDE at column four. |
| 390 | `Clear screen and home cursor` | Screen editor | Matched | PCE, case 390. Ctrl-Home clears the screen and homes the cursor before typing Q. |
| 391 | `Insert logical line break` | Screen editor | Matched | Q, case 391 |
| 392 | `Pause and resume` | Screen editor | Inconclusive | Ctrl-S entered at the Ok prompt produced the same cells. This does not demonstrate suspension of a running program. |
| 393 | `Printer echo and print screen` | Screen editor | Different | Q, case 393. After Ctrl-Print and ABC, the screen and cursor differed. Both printer captures were empty. Printer delivery remains unverified. |
| 394 | `Bell` | Screen editor | Inconclusive | Q, case 394; speaker output uncaptured |
| 395 | `COM port, baud, parity, data and stop bits` | RS-232 | Different | Q, case 395; 3.23 DONE, 4.01N ERROR 57  100 |
| 396 | `COM RS, CS, DS and CD options` | RS-232 | Different | Q, case 396; 3.23 DONE, 4.01N ERROR 57  100 |
| 397 | `COM LF and PE options` | RS-232 | Different | Q, case 397; 3.23 DONE, 4.01N ERROR 64  100 |
| 398 | `Serial receive overflow and timeout` | RS-232 | Inconclusive | Q, case 398; serial open differs before overflow or timeout |
| 399 | `CALLS` | Reference dictionary | Matched | Q, case 399 |
| 400 | `LCOPY` | Reference dictionary | Matched | PCE, case 400, optional byte accepted and negative argument gives error 5 |
| 401 | `MOTOR` | Reference dictionary | Matched | PCE, case 401, toggle and explicit byte accepted and 256 gives error 5. Physical motor untested |
| 402 | `GO TO spelling` | Reference dictionary | Matched | Q, case 402 |

## Tokenizer cross-check

The original comparison covered 187 spellings from the 3.23 dictionaries, the inventory, and the Q/QF tables in [ibmres.asm](ibmres.asm). Six spellings differed. The bidirectional file regression now checks their token bytes and exchanges saved programs containing them, including quoted names in REM text. Each consumer reproduces the original ASCII lines.

| Spelling | Token bytes in both versions |
|---|---|
| `ERDEV` | `fe 95` |
| `ERDEV$` | `fe 95 24` |
| `EXTERR` | `fd 8b` |
| `LOCK` | `fe a7` |
| `SHELL` | `fe 9a` |
| `UNLOCK` | `fe a8` |

See the statement rows above for execution coverage.
