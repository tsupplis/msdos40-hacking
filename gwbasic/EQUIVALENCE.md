# GW-BASIC 3.23 equivalence inventory

Target: the project’s 3.23 DOS binary and 4.01N under identical inputs. The alphabetical reference supplies the named language entries. Additional rows cover editor operations, program startup, operators, interchange and adapter configurations. A row is one work item. Compound operands, boundary values and device profiles require further cases within it.

Sources: [Microsoft GW-BASIC User’s Reference and Guide, July 1987](https://bitsavers.computerhistory.org/pdf/microsoft/msdos_3.3/MS-DOS_GW-BASIC_198707.pdf), [1989 guide and command-line reference](https://bitsavers.trailing-edge.com/pdf/microsoft/gw-basic/Microsoft_GW-BASIC_Users_Guide_and_Reference_1989.pdf). Supplementary syntax must be verified against the project’s executable.

402 work items: 143 matched, 241 untested, 15 different, 3 intentional.

## Evidence

Matched records an observed matching case. It does not qualify the entire form or its error paths. Untested means a direct behavioral comparison has not been recorded here. The default guest is MS-DOS 4.01N. Display work uses PCE EGA/VGA or QEMU VGA. Event tests require the corresponding event source, file locking requires a SHARE-enabled configuration for successful operations, and printer and serial tests require a captured output device.

- A — [arithmetic and language probes](../test/gwmatrix.bas), checked against the optional reference.
- L — [shared language assertions](../test/gwlang.bas), executed by [check_gwbasic](../test/check_gwbasic) on both interpreters.
- P — [shared program-management session](../test/gwprog.txt), with output and listing assertions in check_gwbasic.
- F — [bidirectional DOS file tests](../test/check_gwcompat).
- X — prior two-way 13×3 sprite experiment, 39 pixels and 28 payload bytes per color mode. A permanent oracle for the cross-interpreter experiment remains to be added.
- [4.01N graphics regression](../test/gwvideo.bas) exercises additional forms. Local-only results leave the direct comparison open.

## Numbered matrix

| ID | Behavior | Configuration | Status | Evidence or observed difference |
|---:|---|---|---|---|
| 001 | `ABS` | DOS | Matched | L |
| 002 | `ASC` | DOS | Matched | A |
| 003 | `ATN` | DOS | Matched | A |
| 004 | `AUTO` | DOS | Untested | — |
| 005 | `BEEP` | DOS | Untested | — |
| 006 | `BLOAD` | DOS | Matched | F |
| 007 | `BSAVE` | DOS | Matched | F |
| 008 | `CALL` | DOS | Untested | — |
| 009 | `CDBL` | DOS | Matched | A |
| 010 | `CHAIN` | DOS | Matched | P |
| 011 | `CHAIN MERGE` | DOS | Untested | — |
| 012 | `CHAIN ALL` | DOS | Untested | — |
| 013 | `CHAIN MERGE DELETE` | DOS | Untested | — |
| 014 | `CHDIR` | DOS | Matched | L |
| 015 | `CHR$` | DOS | Matched | A |
| 016 | `CINT` | DOS | Matched | A |
| 017 | `CLEAR` | DOS | Untested | — |
| 018 | `CLOSE` | DOS | Matched | L |
| 019 | `COMMON` | DOS | Matched | P |
| 020 | `CONT` | DOS | Untested | — |
| 021 | `COS` | DOS | Matched | A |
| 022 | `CSNG` | DOS | Matched | A |
| 023 | `CVD` | DOS | Matched | L |
| 024 | `CVI` | DOS | Matched | L |
| 025 | `CVS` | DOS | Matched | L |
| 026 | `DATA` | DOS | Matched | L |
| 027 | `DATE$ read` | DOS | Untested | — |
| 028 | `DATE$ assignment` | DOS | Untested | — |
| 029 | `DEF FN` | DOS | Matched | L |
| 030 | `DEFINT` | DOS | Untested | — |
| 031 | `DEFDBL` | DOS | Untested | — |
| 032 | `DEFSNG` | DOS | Untested | — |
| 033 | `DEFSTR` | DOS | Untested | — |
| 034 | `DEF SEG` | DOS | Untested | — |
| 035 | `DEF USR` | DOS | Untested | — |
| 036 | `DELETE` | DOS | Matched | P |
| 037 | `DIM` | DOS | Matched | L |
| 038 | `EDIT` | DOS | Untested | — |
| 039 | `END` | DOS | Untested | — |
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
| 053 | `FILES` | DOS | Untested | — |
| 054 | `FIX` | DOS | Matched | L |
| 055 | `FOR … NEXT` | DOS | Matched | L |
| 056 | `NEXT multi-variable` | DOS | Matched | L |
| 057 | `FRE(number)` | DOS | Untested | — |
| 058 | `FRE(string)` | DOS | Untested | — |
| 059 | `GET record` | DOS | Matched | L |
| 060 | `GET next record` | DOS | Matched | L |
| 061 | `GOSUB` | DOS | Untested | — |
| 062 | `RETURN` | DOS | Matched | A |
| 063 | `RETURN line` | DOS | Untested | — |
| 064 | `GOTO` | DOS | Matched | P |
| 065 | `HEX$` | DOS | Matched | A |
| 066 | `IF THEN statement` | DOS | Matched | L |
| 067 | `IF THEN line` | DOS | Matched | A |
| 068 | `IF GOTO` | DOS | Untested | — |
| 069 | `IF THEN ELSE` | DOS | Untested | — |
| 070 | `INPUT` | DOS | Untested | — |
| 071 | `INPUT#` | DOS | Matched | L |
| 072 | `INPUT$(console)` | DOS | Untested | — |
| 073 | `INPUT$(file)` | DOS | Untested | — |
| 074 | `INSTR` | DOS | Matched | L |
| 075 | `INT` | DOS | Matched | L |
| 076 | `KILL` | DOS | Matched | L |
| 077 | `LEFT$` | DOS | Matched | L |
| 078 | `LEN` | DOS | Matched | L |
| 079 | `LET explicit` | DOS | Matched | A |
| 080 | `LET implicit` | DOS | Matched | L |
| 081 | `LINE INPUT` | DOS | Untested | — |
| 082 | `LINE INPUT#` | DOS | Matched | L |
| 083 | `LIST` | DOS | Untested | — |
| 084 | `LIST to file` | DOS | Untested | — |
| 085 | `LOAD` | DOS | Matched | P |
| 086 | `LOAD ,R` | DOS | Untested | — |
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
| 098 | `NAME` | DOS | Untested | — |
| 099 | `NEW` | DOS | Matched | P |
| 100 | `OCT$` | DOS | Matched | A |
| 101 | `ON ERROR GOTO` | DOS | Matched | L |
| 102 | `ON ERROR GOTO 0` | DOS | Untested | — |
| 103 | `ON … GOSUB` | DOS | Matched | A |
| 104 | `ON … GOTO` | DOS | Matched | A |
| 105 | `OPEN INPUT` | DOS | Untested | — |
| 106 | `OPEN OUTPUT` | DOS | Matched | P |
| 107 | `OPEN APPEND` | DOS | Matched | P |
| 108 | `OPEN RANDOM` | DOS | Untested | — |
| 109 | `OPEN legacy mode string` | DOS | Matched | L |
| 110 | `OPEN ACCESS and sharing` | DOS | Untested | — |
| 111 | `OPTION BASE 0` | DOS | Untested | — |
| 112 | `OPTION BASE 1` | DOS | Matched | L |
| 113 | `PRINT` | DOS | Untested | — |
| 114 | `PRINT USING` | DOS | Untested | — |
| 115 | `PRINT#` | DOS | Matched | L |
| 116 | `PRINT# USING` | DOS | Matched | L |
| 117 | `PUT record` | DOS | Matched | L |
| 118 | `PUT next record` | DOS | Untested | — |
| 119 | `RANDOMIZE seed` | DOS | Untested | — |
| 120 | `RANDOMIZE prompt` | DOS | Untested | — |
| 121 | `READ` | DOS | Matched | L |
| 122 | `REM` | DOS | Untested | — |
| 123 | `apostrophe comment` | DOS | Untested | — |
| 124 | `RENUM` | DOS | Matched | P |
| 125 | `RESET` | DOS | Untested | — |
| 126 | `RESTORE` | DOS | Matched | L |
| 127 | `RESTORE line` | DOS | Matched | A |
| 128 | `RESUME` | DOS | Untested | — |
| 129 | `RESUME NEXT` | DOS | Matched | L |
| 130 | `RESUME line` | DOS | Matched | L |
| 131 | `RIGHT$` | DOS | Matched | L |
| 132 | `RMDIR` | DOS | Matched | L |
| 133 | `RND negative` | DOS | Untested | — |
| 134 | `RND zero` | DOS | Untested | — |
| 135 | `RND positive or omitted` | DOS | Untested | — |
| 136 | `RSET` | DOS | Matched | L |
| 137 | `RUN` | DOS | Matched | P |
| 138 | `RUN line` | DOS | Untested | — |
| 139 | `RUN file` | DOS | Untested | — |
| 140 | `RUN file,R` | DOS | Untested | — |
| 141 | `SAVE tokenized` | DOS | Matched | P |
| 142 | `SAVE ASCII` | DOS | Matched | P |
| 143 | `SAVE protected` | DOS | Matched | F |
| 144 | `SGN` | DOS | Matched | A |
| 145 | `SHELL command` | DOS | Different | echo did not create file |
| 146 | `SHELL interactive` | DOS | Untested | — |
| 147 | `SIN` | DOS | Matched | L |
| 148 | `SPACE$` | DOS | Matched | A |
| 149 | `SPC` | DOS | Untested | — |
| 150 | `SQR` | DOS | Matched | A |
| 151 | `STOP` | DOS | Untested | — |
| 152 | `STR$` | DOS | Matched | A |
| 153 | `STRING$ numeric` | DOS | Matched | L |
| 154 | `STRING$ string` | DOS | Matched | A |
| 155 | `SWAP` | DOS | Matched | L |
| 156 | `SYSTEM` | DOS | Matched | L |
| 157 | `TAB` | DOS | Untested | — |
| 158 | `TAN` | DOS | Matched | A |
| 159 | `TIME$ read` | DOS | Matched | L |
| 160 | `TIME$ assignment` | DOS | Untested | — |
| 161 | `TIMER function` | DOS | Matched | L |
| 162 | `TROFF` | DOS | Untested | — |
| 163 | `TRON` | DOS | Untested | — |
| 164 | `USR` | DOS | Untested | — |
| 165 | `VAL` | DOS | Matched | L |
| 166 | `VARPTR(variable)` | DOS | Untested | — |
| 167 | `VARPTR(file)` | DOS | Untested | — |
| 168 | `VARPTR$` | DOS | Untested | — |
| 169 | `WHILE … WEND` | DOS | Matched | A |
| 170 | `WRITE` | DOS | Untested | — |
| 171 | `WRITE#` | DOS | Matched | L |
| 172 | `CIRCLE` | Display | Untested | — |
| 173 | `CLS` | Display | Untested | — |
| 174 | `CLS 0/1/2` | Display | Untested | — |
| 175 | `COLOR text` | Display | Untested | — |
| 176 | `COLOR CGA` | Display | Untested | — |
| 177 | `COLOR EGA` | Display | Untested | — |
| 178 | `CSRLIN` | Display | Untested | — |
| 179 | `DRAW` | Display | Untested | — |
| 180 | `GET graphics` | Display | Matched | X |
| 181 | `INKEY$` | Display | Untested | — |
| 182 | `KEY definition` | Display | Untested | — |
| 183 | `KEY ON` | Display | Untested | — |
| 184 | `KEY OFF` | Display | Untested | — |
| 185 | `KEY LIST` | Display | Untested | — |
| 186 | `LINE` | Display | Untested | — |
| 187 | `LINE B` | Display | Untested | — |
| 188 | `LINE BF` | Display | Untested | — |
| 189 | `LOCATE` | Display | Untested | — |
| 190 | `PAINT solid` | Display | Untested | — |
| 191 | `PAINT tile` | Display | Untested | — |
| 192 | `PALETTE reset` | Display | Untested | — |
| 193 | `PALETTE attribute,color` | Display | Different | syntax error |
| 194 | `PALETTE USING` | Display | Untested | — |
| 195 | `PCOPY` | Display | Matched | Reference page-copy probe and [independent page checks](../test/gwvideo.bas) |
| 196 | `PMAP` | Display | Different | error 9 for PMAP(23,0) |
| 197 | `POINT(x,y)` | Display | Matched | X |
| 198 | `POINT(selector)` | Display | Untested | — |
| 199 | `POS` | Display | Untested | — |
| 200 | `PRESET` | Display | Untested | — |
| 201 | `PSET` | Display | Matched | X |
| 202 | `PUT graphics PSET` | Display | Matched | X |
| 203 | `PUT graphics PRESET` | Display | Untested | — |
| 204 | `PUT graphics AND` | Display | Untested | — |
| 205 | `PUT graphics OR` | Display | Untested | — |
| 206 | `PUT graphics XOR` | Display | Untested | — |
| 207 | `SCREEN(row,col)` | Display | Untested | — |
| 208 | `SCREEN(row,col,1)` | Display | Untested | — |
| 209 | `SCREEN 0` | Display | Untested | — |
| 210 | `SCREEN 1` | Display | Untested | — |
| 211 | `SCREEN 2` | Display | Untested | — |
| 212 | `SCREEN 7` | Display | Matched | X |
| 213 | `SCREEN 8` | Display | Matched | X |
| 214 | `SCREEN 9` | Display | Matched | X |
| 215 | `SCREEN 10` | Display | Untested | — |
| 216 | `SCREEN active and visible pages` | Display | Untested | — |
| 217 | `VIEW graphics` | Display | Different | syntax error |
| 218 | `VIEW SCREEN` | Display | Untested | — |
| 219 | `VIEW reset` | Display | Untested | — |
| 220 | `VIEW PRINT range` | Display | Different | syntax error |
| 221 | `VIEW PRINT reset` | Display | Untested | — |
| 222 | `WIDTH screen` | Display | Untested | — |
| 223 | `WINDOW` | Display | Different | syntax error |
| 224 | `WINDOW SCREEN` | Display | Untested | — |
| 225 | `WINDOW reset` | Display | Untested | — |
| 226 | `INP` | Devices | Untested | — |
| 227 | `OUT` | Devices | Untested | — |
| 228 | `WAIT` | Devices | Untested | — |
| 229 | `PEEK` | Devices | Untested | — |
| 230 | `POKE` | Devices | Untested | — |
| 231 | `IOCTL` | Devices | Untested | — |
| 232 | `IOCTL$` | Devices | Untested | — |
| 233 | `OPEN COM` | Devices | Untested | — |
| 234 | `OPEN device` | Devices | Untested | — |
| 235 | `LPOS` | Devices | Untested | — |
| 236 | `LLIST` | Devices | Untested | — |
| 237 | `LPRINT` | Devices | Untested | — |
| 238 | `LPRINT USING` | Devices | Untested | — |
| 239 | `WIDTH device` | Devices | Untested | — |
| 240 | `WIDTH file` | Devices | Untested | — |
| 241 | `PEN function` | Devices | Untested | — |
| 242 | `STICK` | Devices | Untested | — |
| 243 | `STRIG function` | Devices | Untested | — |
| 244 | `STRIG ON` | Devices | Untested | — |
| 245 | `STRIG OFF` | Devices | Untested | — |
| 246 | `PLAY music` | Devices | Untested | — |
| 247 | `PLAY(n) queue` | Devices | Untested | — |
| 248 | `SOUND` | Devices | Untested | — |
| 249 | `LOCK` | DOS + SHARE | Different | error 2 versus 70 |
| 250 | `UNLOCK` | DOS + SHARE | Different | error 2 versus 70 |
| 251 | `ON COM(n) GOSUB` | Event source | Untested | — |
| 252 | `COM(n) ON` | Event source | Untested | — |
| 253 | `COM(n) OFF` | Event source | Untested | — |
| 254 | `COM(n) STOP` | Event source | Untested | — |
| 255 | `ON KEY(n) GOSUB` | Event source | Untested | — |
| 256 | `KEY(n) ON` | Event source | Untested | — |
| 257 | `KEY(n) OFF` | Event source | Untested | — |
| 258 | `KEY(n) STOP` | Event source | Untested | — |
| 259 | `ON PEN GOSUB` | Event source | Untested | — |
| 260 | `PEN ON` | Event source | Untested | — |
| 261 | `PEN OFF` | Event source | Untested | — |
| 262 | `PEN STOP` | Event source | Untested | — |
| 263 | `ON PLAY(n) GOSUB` | Event source | Untested | — |
| 264 | `PLAY ON` | Event source | Untested | — |
| 265 | `PLAY OFF` | Event source | Untested | — |
| 266 | `PLAY STOP` | Event source | Untested | — |
| 267 | `ON STRIG(n) GOSUB` | Event source | Untested | — |
| 268 | `STRIG(n) ON` | Event source | Untested | — |
| 269 | `STRIG(n) OFF` | Event source | Untested | — |
| 270 | `STRIG(n) STOP` | Event source | Untested | — |
| 271 | `ON TIMER(n) GOSUB` | Event source | Different | error 6 |
| 272 | `TIMER ON` | Event source | Different | error 73 |
| 273 | `TIMER OFF` | Event source | Different | error 73 |
| 274 | `TIMER STOP` | Event source | Untested | — |
| 275 | `Program filename` | DOS startup | Untested | — |
| 276 | `Interactive start` | DOS startup | Untested | — |
| 277 | `stdin redirection` | DOS startup | Untested | — |
| 278 | `stdout redirection` | DOS startup | Untested | — |
| 279 | `stdout append` | DOS startup | Untested | — |
| 280 | `/D` | DOS startup | Untested | — |
| 281 | `/I` | DOS startup | Untested | — |
| 282 | `/C:n` | DOS startup | Untested | — |
| 283 | `/F:n` | DOS startup | Untested | — |
| 284 | `/S:n` | DOS startup | Untested | — |
| 285 | `/M:n` | DOS startup | Untested | — |
| 286 | `/M:n,maximum block` | DOS startup | Untested | — |
| 287 | `Startup banner` | DOS startup | Intentional | 4.01N startup extension |
| 288 | `/NOBANNER` | DOS startup | Intentional | 4.01N startup extension |
| 289 | `/NORUN` | DOS startup | Intentional | 4.01N startup extension |
| 290 | `Enter numbered line` | Screen editor | Untested | — |
| 291 | `Replace numbered line` | Screen editor | Untested | — |
| 292 | `Delete numbered line` | Screen editor | Untested | — |
| 293 | `Direct command` | Screen editor | Untested | — |
| 294 | `Cursor left/right/up/down` | Screen editor | Untested | — |
| 295 | `Word left/right` | Screen editor | Untested | — |
| 296 | `Home and End` | Screen editor | Untested | — |
| 297 | `Insert and Delete` | Screen editor | Untested | — |
| 298 | `Backspace` | Screen editor | Untested | — |
| 299 | `Escape line cancellation` | Screen editor | Untested | — |
| 300 | `Tab and backtab` | Screen editor | Untested | — |
| 301 | `Function keys F1–F10` | Screen editor | Untested | — |
| 302 | `Ctrl-Break and continuation` | Screen editor | Untested | — |
| 303 | `Control-key editing shortcuts` | Screen editor | Untested | — |
| 304 | `Logical line wrapping` | Screen editor | Untested | — |
| 305 | `Integer, single and double literals` | Language | Untested | — |
| 306 | `Hex and octal constants` | Language | Matched | L |
| 307 | `String literals` | Language | Untested | — |
| 308 | `Variable type suffixes and defaults` | Language | Untested | — |
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
| 328 | `Overflow, rounding and coercion` | Language | Untested | — |
| 329 | `Line numbers and references` | Language | Untested | — |
| 330 | `Colon statement separator` | Language | Matched | L |
| 331 | `Question mark PRINT shorthand` | Language | Untested | — |
| 332 | `ASCII program interchange` | DOS files | Matched | F |
| 333 | `Tokenized program interchange` | DOS files | Matched | F |
| 334 | `Protected program interchange` | DOS files | Matched | F |
| 335 | `Sequential data interchange` | DOS files | Matched | F |
| 336 | `Random MBF record interchange` | DOS files | Matched | F |
| 337 | `BSAVE block interchange` | DOS files | Matched | F |
| 338 | `EGA graphics-array interchange SCREEN 7` | Display files | Matched | X |
| 339 | `EGA graphics-array interchange SCREEN 8` | Display files | Matched | X |
| 340 | `EGA graphics-array interchange SCREEN 9` | Display files | Matched | X |
| 341 | `EGA graphics-array interchange SCREEN 10` | Display files | Untested | — |
| 342 | `64 KB physical EGA addressing` | Display files | Untested | — |
| 343 | `Runtime error numbers, messages and recovery` | DOS | Untested | — |
| 344 | `DOS device errors and extended errors` | DOS | Untested | — |
| 345 | `DRAW movement U/D/L/R/E/F/G/H` | Display | Untested | — |
| 346 | `DRAW M absolute/relative` | Display | Untested | — |
| 347 | `DRAW B and N prefixes` | Display | Untested | — |
| 348 | `DRAW A and TA rotation` | Display | Untested | — |
| 349 | `DRAW C and S` | Display | Untested | — |
| 350 | `DRAW X substring` | Display | Untested | — |
| 351 | `DRAW P fill` | Display | Untested | — |
| 352 | `DRAW variable substitution` | Display | Untested | — |
| 353 | `CIRCLE arc and aspect` | Display | Untested | — |
| 354 | `LINE styled segments` | Display | Untested | — |
| 355 | `STEP relative coordinates` | Display | Untested | — |
| 356 | `PAINT background tile` | Display | Untested | — |
| 357 | `COLOR foreground/background/border` | Display | Untested | — |
| 358 | `KEY user-defined event key` | Display | Untested | — |
| 359 | `KEY macros` | Display | Untested | — |
| 360 | `SCREEN color switch` | Display | Untested | — |
| 361 | `PLAY note and accidental` | Sound | Untested | — |
| 362 | `PLAY octave and octave shifts` | Sound | Untested | — |
| 363 | `PLAY note number and rest` | Sound | Untested | — |
| 364 | `PLAY length and dotted note` | Sound | Untested | — |
| 365 | `PLAY tempo` | Sound | Untested | — |
| 366 | `PLAY articulation` | Sound | Untested | — |
| 367 | `PLAY foreground/background` | Sound | Untested | — |
| 368 | `PLAY X substring and variable substitution` | Sound | Untested | — |
| 369 | `PRINT zones and separators` | DOS | Untested | — |
| 370 | `PRINT USING numeric masks` | DOS | Matched | L (file output) |
| 371 | `PRINT USING string fields` | DOS | Matched | L (file output) |
| 372 | `PRINT USING literal escapes` | DOS | Untested | — |
| 373 | `OPEN LEN` | DOS | Untested | — |
| 374 | `LOCK whole file` | DOS | Untested | — |
| 375 | `LOCK record range` | DOS | Untested | — |
| 376 | `UNLOCK whole file` | DOS | Untested | — |
| 377 | `UNLOCK record range` | DOS | Untested | — |
| 378 | `CLEAR string space, memory limit and stack` | DOS | Untested | — |
| 379 | `DEF FN arguments and result type` | DOS | Untested | — |
| 380 | `INSTR with start offset` | DOS | Matched | L |
| 381 | `MID$ optional length` | DOS | Untested | — |
| 382 | `LIST line ranges` | DOS | Untested | — |
| 383 | `LIST current line` | DOS | Untested | — |
| 384 | `RENUM reference rewriting` | DOS | Matched | P |
| 385 | `Implicit and explicit line-number references` | DOS | Untested | — |
| 386 | `DATA quoted strings and empty fields` | DOS | Untested | — |
| 387 | `Integer division rounding` | DOS | Untested | — |
| 388 | `Single versus double precision promotion` | DOS | Untested | — |
| 389 | `Clear to end of line` | Screen editor | Untested | — |
| 390 | `Clear screen and home cursor` | Screen editor | Untested | — |
| 391 | `Insert logical line break` | Screen editor | Untested | — |
| 392 | `Pause and resume` | Screen editor | Untested | — |
| 393 | `Printer echo and print screen` | Screen editor | Untested | — |
| 394 | `Bell` | Screen editor | Untested | — |
| 395 | `COM port, baud, parity, data and stop bits` | RS-232 | Untested | — |
| 396 | `COM RS, CS, DS and CD options` | RS-232 | Untested | — |
| 397 | `COM LF and PE options` | RS-232 | Untested | — |
| 398 | `Serial receive overflow and timeout` | RS-232 | Untested | — |
| 399 | `CALLS` | Reference dictionary | Untested | — |
| 400 | `LCOPY` | Reference dictionary | Untested | — |
| 401 | `MOTOR` | Reference dictionary | Untested | — |
| 402 | `GO TO spelling` | Reference dictionary | Untested | — |

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
