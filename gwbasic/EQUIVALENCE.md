# GW-BASIC 3.23 equivalence inventory

Target: the project’s 3.23 DOS binary and 4.01N under identical inputs. The alphabetical reference supplies the named language entries. Additional rows cover editor operations, program startup, operators, interchange and adapter configurations. A row is one work item. Inconclusive means the probe ran but could not isolate the intended behavior. Compound operands, boundary values and device profiles require further cases within it.

Sources: [Microsoft GW-BASIC User’s Reference and Guide, July 1987](https://bitsavers.computerhistory.org/pdf/microsoft/msdos_3.3/MS-DOS_GW-BASIC_198707.pdf), [1989 guide and command-line reference](https://bitsavers.trailing-edge.com/pdf/microsoft/gw-basic/Microsoft_GW-BASIC_Users_Guide_and_Reference_1989.pdf). Supplementary syntax must be verified against the project’s executable.

402 work items: 319 matched, 74 different, 6 inconclusive, 3 intentional.

## Evidence

Matched records an observed matching case. It does not qualify the entire form or its error paths. Untested means a direct behavioral comparison has not been recorded here. The default guest is MS-DOS 4.01N. Display work uses PCE EGA/VGA or QEMU VGA. Event tests require the corresponding event source, file locking requires a SHARE-enabled configuration for successful operations, and printer and serial tests require a captured output device.

- Q — [paired DOS observations](../test/gwaudit.jsonl) from [check_gwaudit](../test/check_gwaudit) and [probe inputs](../test/gwcases.txt). Each interpreter runs its probes in one QEMU guest. Results retain the reference and build outputs. Statement acceptance alone leaves device delivery, audio, timing and underlying limits unqualified.
- A — [arithmetic and language probes](../test/gwmatrix.bas), checked against the optional reference.
- L — [shared language assertions](../test/gwlang.bas), executed by [check_gwbasic](../test/check_gwbasic) on both interpreters.
- P — [shared program-management session](../test/gwprog.txt), with output and listing assertions in check_gwbasic.
- F — [bidirectional DOS file tests](../test/check_gwcompat).
- X — prior two-way 13×3 sprite experiment, 39 pixels and 28 payload bytes per color mode. A permanent oracle for the cross-interpreter experiment remains to be added.
- [4.01N graphics regression](../test/gwvideo.bas) exercises additional forms. Local-only results leave the direct comparison open.

## Running the paired regression

With `gwbasic/gwbasic.ref` present, root `make check` invokes `test/check_gwaudit --quick --check`. This runs 62 probes on both binaries in one headless PCE boot, using the project's `test/run_tests` runner. Select a headless `pce-ibmpc` via PATH. Each interpreter runs the BASIC fixtures in succession and writes one report on the scratch floppy.

The explicit full command `test/check_gwaudit --check` uses QEMU for all 239 probes, with one boot per interpreter. It batches the same 62 fixtures and restores booted DOS for individual cases requiring separate observations, including BIOS keyboard and cursor capture. Use `test/check_gwaudit --check 373` for an isolated selection or omit `--check` for JSONL output.

The gate enforces the 175 QEMU cases marked **Matched** against both the live 3.23 run and its recorded output. Incomplete observations fail in every category. The summary counts the 58 known differences and six inconclusive probes separately. A known difference that now matches is reported for review. After verifying a fix, update that case’s JSONL record, matrix status and counts together. The remaining inventory rows use the other evidence listed above.

## Differences by work area

Each row below groups failed observations for investigation. The count measures inventory coverage; shared causes and the number of required changes still need diagnosis. Input echo, printer formatting and adapter selection can differ even when a program computes the same value.

| Work area | Rows | Inventory IDs |
|---|---:|---|
| DOS environment and command execution | 3 | 40, 145, 146 |
| DOS error information and device control | 5 | 45, 46, 51, 231, 232 |
| Disk files, sharing and locking | 8 | 53, 110, 249, 250, 374, 375, 376, 377 |
| Command streams, prompts and diagnostics | 6 | 70, 81, 102, 120, 151, 277 |
| Keyboard, editor and function keys | 12 | 182, 185, 294, 295, 297, 299, 301, 358, 359, 389, 390, 393 |
| Coordinates, viewports and text windows | 10 | 196, 198, 217, 218, 219, 220, 221, 223, 224, 225 |
| Palette, drawing and tiled fill | 8 | 191, 192, 193, 194, 348, 351, 354, 356 |
| Video modes, pages and EGA memory | 3 | 215, 216, 342 |
| Serial I/O | 4 | 233, 395, 396, 397 |
| Timer events | 4 | 271, 272, 273, 274 |
| Music queue, events and PLAY syntax | 5 | 247, 263, 264, 265, 266 |
| Startup switches | 3 | 280, 281, 286 |
| Joystick, printer and cassette | 3 | 242, 400, 401 |

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
| 040 | `ENVIRON assignment` | DOS | Different | assignment returned different errors |
| 041 | `ENVIRON$(name)` | DOS | Matched | L |
| 042 | `ENVIRON$(index)` | DOS | Matched | L |
| 043 | `EOF` | DOS | Matched | L |
| 044 | `ERASE` | DOS | Matched | L |
| 045 | `ERDEV` | DOS | Different | reference token saved as ASCII identifier in 4.01N |
| 046 | `ERDEV$` | DOS | Different | reference token saved as ASCII identifier in 4.01N |
| 047 | `ERL` | DOS | Matched | L |
| 048 | `ERR` | DOS | Matched | L |
| 049 | `ERROR` | DOS | Matched | L |
| 050 | `EXP` | DOS | Matched | L |
| 051 | `EXTERR` | DOS | Different | reference token saved as ASCII identifier in 4.01N |
| 052 | `FIELD` | DOS | Matched | L |
| 053 | `FILES` | DOS | Different | Q, case 53; output differs |
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
| 070 | `INPUT` | DOS | Different | Q, case 70; output differs |
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
| 081 | `LINE INPUT` | DOS | Different | Q, case 81; output differs |
| 082 | `LINE INPUT#` | DOS | Matched | L |
| 083 | `LIST` | DOS | Matched | Q, case 83 |
| 084 | `LIST to file` | DOS | Matched | Q, case 84 |
| 085 | `LOAD` | DOS | Matched | P |
| 086 | `LOAD ,R` | DOS | Matched | Q, case 86 |
| 087 | `LOC` | DOS | Matched | L |
| 088 | `LOF` | DOS | Matched | L |
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
| 102 | `ON ERROR GOTO 0` | DOS | Different | Q, case 102; output differs |
| 103 | `ON … GOSUB` | DOS | Matched | A |
| 104 | `ON … GOTO` | DOS | Matched | A |
| 105 | `OPEN INPUT` | DOS | Matched | Q, case 105 |
| 106 | `OPEN OUTPUT` | DOS | Matched | P |
| 107 | `OPEN APPEND` | DOS | Matched | P |
| 108 | `OPEN RANDOM` | DOS | Matched | Q, case 108 |
| 109 | `OPEN legacy mode string` | DOS | Matched | L |
| 110 | `OPEN ACCESS and sharing` | DOS | Different | Q, case 110; 3.23 ALPHA / DONE, 4.01N ERROR 2  100 |
| 111 | `OPTION BASE 0` | DOS | Matched | Q, case 111 |
| 112 | `OPTION BASE 1` | DOS | Matched | L |
| 113 | `PRINT` | DOS | Matched | Q, case 113 |
| 114 | `PRINT USING` | DOS | Matched | Q, case 114 |
| 115 | `PRINT#` | DOS | Matched | L |
| 116 | `PRINT# USING` | DOS | Matched | L |
| 117 | `PUT record` | DOS | Matched | L |
| 118 | `PUT next record` | DOS | Matched | Q, case 118 |
| 119 | `RANDOMIZE seed` | DOS | Matched | Q, case 119 |
| 120 | `RANDOMIZE prompt` | DOS | Different | Q, case 120; output differs |
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
| 145 | `SHELL command` | DOS | Different | echo did not create file |
| 146 | `SHELL interactive` | DOS | Different | Q, case 146; 3.23 BACK / DONE, 4.01N ERROR 2  100 |
| 147 | `SIN` | DOS | Matched | L |
| 148 | `SPACE$` | DOS | Matched | A |
| 149 | `SPC` | DOS | Matched | Q, case 149 |
| 150 | `SQR` | DOS | Matched | A |
| 151 | `STOP` | DOS | Different | Q, case 151; 3.23 see transcript, 4.01N CONTINUED / DONE |
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
| 182 | `KEY definition` | Display | Different | Q, case 182; output differs |
| 183 | `KEY ON` | Display | Matched | Q, case 183; statement accepted and returned |
| 184 | `KEY OFF` | Display | Matched | Q, case 184; statement accepted and returned |
| 185 | `KEY LIST` | Display | Different | Q, case 185; output differs |
| 186 | `LINE` | Display | Matched | Q, case 186 |
| 187 | `LINE B` | Display | Matched | Q, case 187 |
| 188 | `LINE BF` | Display | Matched | Q, case 188 |
| 189 | `LOCATE` | Display | Matched | Q, case 189 |
| 190 | `PAINT solid` | Display | Matched | Q, case 190 |
| 191 | `PAINT tile` | Display | Different | Q, case 191; 3.23 1  / DONE, 4.01N ERROR 13  100 |
| 192 | `PALETTE reset` | Display | Different | Q, case 192; 3.23 DONE, 4.01N ERROR 2  100 |
| 193 | `PALETTE attribute,color` | Display | Different | syntax error |
| 194 | `PALETTE USING` | Display | Different | Q, case 194; 3.23 DONE, 4.01N ERROR 2  100 |
| 195 | `PCOPY` | Display | Matched | Reference page-copy probe and [independent page checks](../test/gwvideo.bas) |
| 196 | `PMAP` | Display | Different | error 9 for PMAP(23,0) |
| 197 | `POINT(x,y)` | Display | Matched | X |
| 198 | `POINT(selector)` | Display | Different | Q, case 198; 3.23 11            12  / DONE, 4.01N ERROR 2  100 |
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
| 209 | `SCREEN 0` | Display | Matched | Q, case 209 |
| 210 | `SCREEN 1` | Display | Matched | Q, case 210 |
| 211 | `SCREEN 2` | Display | Matched | Q, case 211 |
| 212 | `SCREEN 7` | Display | Matched | X |
| 213 | `SCREEN 8` | Display | Matched | X |
| 214 | `SCREEN 9` | Display | Matched | X |
| 215 | `SCREEN 10` | Display | Different | Q, case 215; 3.23 ERROR 5  100, 4.01N 3  / DONE |
| 216 | `SCREEN active and visible pages` | Display | Different | Q, case 216; 3.23 0  /  3  / DONE, 4.01N 3  /  3  / DONE |
| 217 | `VIEW graphics` | Display | Different | syntax error |
| 218 | `VIEW SCREEN` | Display | Different | Q, case 218; 3.23 3  / DONE, 4.01N ERROR 2  100 |
| 219 | `VIEW reset` | Display | Different | Q, case 219; 3.23 3  / DONE, 4.01N ERROR 2  100 |
| 220 | `VIEW PRINT range` | Display | Different | syntax error |
| 221 | `VIEW PRINT reset` | Display | Different | Q, case 221; 3.23 1  / DONE, 4.01N ERROR 2  100 |
| 222 | `WIDTH screen` | Display | Matched | Q, case 222 |
| 223 | `WINDOW` | Display | Different | syntax error |
| 224 | `WINDOW SCREEN` | Display | Different | Q, case 224; 3.23 319  / DONE, 4.01N ERROR 2  100 |
| 225 | `WINDOW reset` | Display | Different | Q, case 225; 3.23 1  / DONE, 4.01N ERROR 2  100 |
| 226 | `INP` | Devices | Matched | Q, case 226 |
| 227 | `OUT` | Devices | Matched | Q, case 227 |
| 228 | `WAIT` | Devices | Matched | Q, case 228 |
| 229 | `PEEK` | Devices | Matched | Q, case 229 |
| 230 | `POKE` | Devices | Matched | Q, case 230 |
| 231 | `IOCTL` | Devices | Different | Q, case 231; 3.23 ERROR 5  100, 4.01N ERROR 73  100 |
| 232 | `IOCTL$` | Devices | Different | Q, case 232; 3.23 ERROR 5  100, 4.01N ERROR 2  100 |
| 233 | `OPEN COM` | Devices | Different | Q, case 233; 3.23 DONE, 4.01N ERROR 57  100 |
| 234 | `OPEN device` | Devices | Matched | Q, case 234; statement accepted and returned |
| 235 | `LPOS` | Devices | Matched | Q, case 235 |
| 236 | `LLIST` | Devices | Matched | Q, case 236 |
| 237 | `LPRINT` | Devices | Matched | Q, case 237 |
| 238 | `LPRINT USING` | Devices | Matched | Q, case 238 |
| 239 | `WIDTH device` | Devices | Matched | Q, case 239 |
| 240 | `WIDTH file` | Devices | Matched | Q, case 240; statement accepted and returned |
| 241 | `PEN function` | Devices | Matched | Q, case 241 |
| 242 | `STICK` | Devices | Different | Q, case 242; 3.23 0  / DONE, 4.01N 32767  / DONE |
| 243 | `STRIG function` | Devices | Matched | Q, case 243 |
| 244 | `STRIG ON` | Devices | Matched | Q, case 244; statement accepted and returned |
| 245 | `STRIG OFF` | Devices | Matched | Q, case 245; statement accepted and returned |
| 246 | `PLAY music` | Devices | Matched | Q, case 246; statement accepted and returned |
| 247 | `PLAY(n) queue` | Devices | Different | Q, case 247; 3.23 0  / DONE, 4.01N ERROR 2  100 |
| 248 | `SOUND` | Devices | Matched | Q, case 248; statement accepted and returned |
| 249 | `LOCK` | DOS + SHARE | Different | error 2 versus 70 |
| 250 | `UNLOCK` | DOS + SHARE | Different | error 2 versus 70 |
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
| 263 | `ON PLAY(n) GOSUB` | Event source | Different | Q, case 263; 3.23 DONE, 4.01N ERROR 2  100 |
| 264 | `PLAY ON` | Event source | Different | Q, case 264; 3.23 DONE, 4.01N ERROR 2  100 |
| 265 | `PLAY OFF` | Event source | Different | Q, case 265; 3.23 DONE, 4.01N ERROR 2  100 |
| 266 | `PLAY STOP` | Event source | Different | Q, case 266; 3.23 DONE, 4.01N ERROR 2  100 |
| 267 | `ON STRIG(n) GOSUB` | Event source | Matched | Q, case 267; statement accepted and returned |
| 268 | `STRIG(n) ON` | Event source | Matched | Q, case 268; statement accepted and returned |
| 269 | `STRIG(n) OFF` | Event source | Matched | Q, case 269; statement accepted and returned |
| 270 | `STRIG(n) STOP` | Event source | Matched | Q, case 270; statement accepted and returned |
| 271 | `ON TIMER(n) GOSUB` | Event source | Different | error 6 |
| 272 | `TIMER ON` | Event source | Different | error 73 |
| 273 | `TIMER OFF` | Event source | Different | error 73 |
| 274 | `TIMER STOP` | Event source | Different | Q, case 274; 3.23 DONE, 4.01N ERROR 73  100 |
| 275 | `Program filename` | DOS startup | Matched | Q, case 275 |
| 276 | `Interactive start` | DOS startup | Matched | Q, case 276 |
| 277 | `stdin redirection` | DOS startup | Different | Q, case 277; output differs |
| 278 | `stdout redirection` | DOS startup | Matched | Q, case 278 |
| 279 | `stdout append` | DOS startup | Matched | Q, case 279 |
| 280 | `/D` | DOS startup | Different | Q, case 280; 3.23 RUNNING / DONE, 4.01N see transcript |
| 281 | `/I` | DOS startup | Different | Q, case 281; 3.23 RUNNING / DONE, 4.01N see transcript |
| 282 | `/C:n` | DOS startup | Matched | Q, case 282 |
| 283 | `/F:n` | DOS startup | Matched | Q, case 283 |
| 284 | `/S:n` | DOS startup | Matched | Q, case 284 |
| 285 | `/M:n` | DOS startup | Matched | Q, case 285 |
| 286 | `/M:n,maximum block` | DOS startup | Different | Q, case 286; 3.23 RUNNING / DONE, 4.01N see transcript |
| 287 | `Startup banner` | DOS startup | Intentional | 4.01N startup extension |
| 288 | `/NOBANNER` | DOS startup | Intentional | 4.01N startup extension |
| 289 | `/NORUN` | DOS startup | Intentional | 4.01N startup extension |
| 290 | `Enter numbered line` | Screen editor | Matched | Q, case 290 |
| 291 | `Replace numbered line` | Screen editor | Matched | Q, case 291 |
| 292 | `Delete numbered line` | Screen editor | Matched | Q, case 292 |
| 293 | `Direct command` | Screen editor | Matched | Q, case 293 |
| 294 | `Cursor left/right/up/down` | Screen editor | Different | Q, case 294; screen or cursor differs |
| 295 | `Word left/right` | Screen editor | Different | Q, case 295; screen or cursor differs |
| 296 | `Home and End` | Screen editor | Matched | Q, case 296 |
| 297 | `Insert and Delete` | Screen editor | Different | Q, case 297; screen or cursor differs |
| 298 | `Backspace` | Screen editor | Matched | Q, case 298 |
| 299 | `Escape line cancellation` | Screen editor | Different | Q, case 299; screen or cursor differs |
| 300 | `Tab and backtab` | Screen editor | Matched | Q, case 300 |
| 301 | `Function keys F1–F10` | Screen editor | Different | Q, case 301; screen or cursor differs |
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
| 342 | `64 KB physical EGA addressing` | Display files | Different | DOSBox-X experimental 64 KB EGA model, SCREEN 9. Reference recovered all 1,050 sampled pixels; 4.01N failed the readback in [gw64k.bas](../test/gw64k.bas) line 30. Physical hardware remains untested. |
| 343 | `Runtime error numbers, messages and recovery` | DOS | Matched | Q, case 343 |
| 344 | `DOS device errors and extended errors` | DOS | Matched | Q, case 344 |
| 345 | `DRAW movement U/D/L/R/E/F/G/H` | Display | Matched | Q, case 345 |
| 346 | `DRAW M absolute/relative` | Display | Matched | Q, case 346 |
| 347 | `DRAW B and N prefixes` | Display | Matched | Q, case 347 |
| 348 | `DRAW A and TA rotation` | Display | Different | Q, case 348; 3.23 0             0  / DONE, 4.01N ERROR 5  100 |
| 349 | `DRAW C and S` | Display | Matched | Q, case 349 |
| 350 | `DRAW X substring` | Display | Matched | Q, case 350 |
| 351 | `DRAW P fill` | Display | Different | Q, case 351; 3.23 2  / DONE, 4.01N ERROR 5  100 |
| 352 | `DRAW variable substitution` | Display | Matched | Q, case 352 |
| 353 | `CIRCLE arc and aspect` | Display | Matched | Q, case 353 |
| 354 | `LINE styled segments` | Display | Different | Q, case 354; 3.23 3             0  / DONE, 4.01N ERROR 2  100 |
| 355 | `STEP relative coordinates` | Display | Matched | Q, case 355 |
| 356 | `PAINT background tile` | Display | Different | Q, case 356; 3.23 1  / DONE, 4.01N ERROR 13  100 |
| 357 | `COLOR foreground/background/border` | Display | Matched | Q, case 357 |
| 358 | `KEY user-defined event key` | Display | Different | Q, case 358; 3.23 DONE, 4.01N ERROR 5  100 |
| 359 | `KEY macros` | Display | Different | Q, case 359; output differs |
| 360 | `SCREEN color switch` | Display | Matched | Q, case 360 |
| 361 | `PLAY note and accidental` | Sound | Matched | Q, case 361; statement accepted and returned |
| 362 | `PLAY octave and octave shifts` | Sound | Matched | Q, case 362; both accept relative octave shifts. Speaker output uncaptured. |
| 363 | `PLAY note number and rest` | Sound | Matched | Q, case 363; statement accepted and returned |
| 364 | `PLAY length and dotted note` | Sound | Matched | Q, case 364; statement accepted and returned |
| 365 | `PLAY tempo` | Sound | Matched | Q, case 365; statement accepted and returned |
| 366 | `PLAY articulation` | Sound | Matched | Q, case 366; statement accepted and returned |
| 367 | `PLAY foreground/background` | Sound | Matched | Q, case 367; statement accepted and returned |
| 368 | `PLAY X substring and variable substitution` | Sound | Matched | Q, case 368; statement accepted and returned |
| 369 | `PRINT zones and separators` | DOS | Matched | Q, case 369 |
| 370 | `PRINT USING numeric masks` | DOS | Matched | L (file output) |
| 371 | `PRINT USING string fields` | DOS | Matched | L (file output) |
| 372 | `PRINT USING literal escapes` | DOS | Matched | Q, case 372 |
| 373 | `OPEN LEN` | DOS | Matched | Q, case 373 (8-byte record); L (reopen and read a sparse 20-byte record file) |
| 374 | `LOCK whole file` | DOS | Different | Q, case 374; 3.23 ERROR 70  100, 4.01N ERROR 2  100 |
| 375 | `LOCK record range` | DOS | Different | Q, case 375; 3.23 ERROR 70  100, 4.01N ERROR 2  100 |
| 376 | `UNLOCK whole file` | DOS | Different | Q, case 376; 3.23 ERROR 70  100, 4.01N ERROR 2  100 |
| 377 | `UNLOCK record range` | DOS | Different | Q, case 377; 3.23 ERROR 70  100, 4.01N ERROR 2  100 |
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
| 389 | `Clear to end of line` | Screen editor | Different | Q, case 389; screen or cursor differs |
| 390 | `Clear screen and home cursor` | Screen editor | Different | Q, case 390; screen or cursor differs |
| 391 | `Insert logical line break` | Screen editor | Matched | Q, case 391 |
| 392 | `Pause and resume` | Screen editor | Inconclusive | Ctrl-S entered at the Ok prompt produced the same cells. This does not demonstrate suspension of a running program. |
| 393 | `Printer echo and print screen` | Screen editor | Different | Q, case 393; screen or cursor differs |
| 394 | `Bell` | Screen editor | Inconclusive | Q, case 394; speaker output uncaptured |
| 395 | `COM port, baud, parity, data and stop bits` | RS-232 | Different | Q, case 395; 3.23 DONE, 4.01N ERROR 57  100 |
| 396 | `COM RS, CS, DS and CD options` | RS-232 | Different | Q, case 396; 3.23 DONE, 4.01N ERROR 57  100 |
| 397 | `COM LF and PE options` | RS-232 | Different | Q, case 397; 3.23 DONE, 4.01N ERROR 64  100 |
| 398 | `Serial receive overflow and timeout` | RS-232 | Inconclusive | Q, case 398; serial open differs before overflow or timeout |
| 399 | `CALLS` | Reference dictionary | Matched | Q, case 399 |
| 400 | `LCOPY` | Reference dictionary | Different | Q, case 400; 3.23 DONE, 4.01N ERROR 5  100 |
| 401 | `MOTOR` | Reference dictionary | Different | Q, case 401; 3.23 DONE, 4.01N ERROR 68  100 |
| 402 | `GO TO spelling` | Reference dictionary | Matched | Q, case 402 |

## Tokenizer cross-check

Both alphabetic keyword dictionaries in the 3.23 executable were decoded (173 spellings including aliases and grammatical tokens). Both executables loaded the same ASCII lines and saved tokenized programs under emu2. Of 187 distinct spellings from those dictionaries, the inventory and the Q/QF tables in [ibmres.asm](ibmres.asm), 10 emitted different byte sequences. Equal bytes can also represent ordinary variable names. Runtime status requires a separate probe. These byte sequences exclude the record header and terminator.

| Spelling | 3.23 hex | 4.01N hex |
|---|---|---|
| `ERDEV` | `fe 95` | `45 52 44 45 56` |
| `ERDEV$` | `fe 95 24` | `45 52 44 45 56 24` |
| `EXTERR` | `fd 8b` | `45 58 54 45 52 52` |
| `LOCK` | `fe a7` | `4c 4f 43 4b` |
| `PALETTE` | `fe 9f` | `50 41 4c 45 54 54 45` |
| `PMAP` | `fe 9e` | `50 4d 41 50` |
| `SHELL` | `fe 9a` | `53 48 45 4c 4c` |
| `UNLOCK` | `fe a8` | `55 4e 4c 4f 43 4b` |
| `VIEW` | `fe 9c` | `56 49 45 57` |
| `WINDOW` | `fe 9d` | `57 49 4e 44 4f 57` |
