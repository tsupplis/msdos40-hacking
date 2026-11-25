# Command review

Review findings for APPEND, ASSIGN and ATTRIB. The evidence column distinguishes observed behavior from source inspection. Each acceptance check describes the condition for closing the item.

## Requirements for each command review

- [ ] **Command line.** Run the installed command with an empty tail and with whitespace only. Preserve and document a meaningful default action, including any state it changes. When an operand is mandatory, print `COMMAND: Required parameters missing.` on standard error, using the actual command name and a controlled message from the utility's message catalog. Verify a nonzero ERRORLEVEL and that the command exits before performing the operation.
- [ ] **Parser and exit status.** Exercise a normal invocation, missing operands after a switch, invalid input, and supported aliases. Check the resulting files or system state as well as output and ERRORLEVEL. For resident commands, distinguish first installation from a later invocation.
- [ ] **Correctness and safety.** Trace buffer capacities including terminators, counted fields, DOS error paths, and ownership of allocated memory. At interrupt and C/assembler boundaries, check register, segment, flag and caller-data preservation. Validate compiler-specific idioms against the generated code before changing them.
- [ ] **Readability and consistency.** Follow the local MASM or C command template, message conventions and naming. Check that comments describe the current behavior, especially buffer sizes, register contracts and cleanup responsibilities.
- [ ] **DOSHELP correctness.** Compare the entry in `doshelp/doshelp.hlp` with the parser **and** the code that acts on each option. Check required and optional operands, aliases, defaults, switch values, combinations, and any filesystem or driver dependency. Run representative examples on the built media. Check `HELP command` and the command's supported `/?` path, and verify that the topic fits one 80-column screen with readable option rows.
- [ ] **Record evidence.** Give each finding a status and an acceptance check. Identify source inspection, compiler checks, fixtures and booted DOS results separately. Mark a finding `DONE` once its acceptance check passes.

## Implementation findings

| Command and finding | Evidence | Proposed change and acceptance check | Status |
|---|---|---| --- |
| APPEND · Resident path bounds | Source. In append.asm, get_fname can fill fname without a terminator. get_app_dir and append_fname write to try_dir without a destination limit. | Bound the directory, filename and joined path including the terminator. Skip an oversized candidate and continue the search. Verify the last valid fit, a rejected candidate followed by a valid one, and the original DOS error when none succeeds. | DONE |
| APPEND · Double-byte filenames | Source. get_fname reads the current byte into AH while Chk_DBCS tests AL. The backwards scan also remembers only the most recent lead byte. | Scan forward by complete characters, remembering the last actual separator. Test a double-byte character with a backslash trail byte and another double-byte character later in the filename. | DONE |
| ASSIGN · Environment ownership | Source. INITIALIZATION releases the PSP environment, then Set_Vectors calls Release_Environment using the same PSP field. No allocator corruption observed. | Release once on the first resident installation, clear the PSP environment pointer after success, and verify first install, subsequent updates and transient exits. | DONE |
| ASSIGN · Success ERRORLEVEL | Booted DOS. Status before and after mapping, and a successful reset, returned nonzero. | Set AL explicitly at successful termination and stay-resident exits. Keep parse failures nonzero. Test install, status, update, reset and invalid input. | DONE |
| ASSIGN · Caller FCB drive | Booted DOS. An FCB find-first on drive zero left the caller's byte at zero without ASSIGN and changed it to one with ASSIGN installed on default A:. | Save the original drive before substituting the logical default. Verify successful and failed searches, including reuse after a drive change. | DONE |
| ATTRIB · Counted extended attributes | Source. Get_far_str uses zero length to select NUL scanning. Print_ext_attrib passes provider lengths to a 129-byte destination. | Give counted and terminated fields separate contracts. Check field extent and destination capacity before copying. Verify empty, maximum and invalid fields with an EA-capable provider or fixture. | DONE |
| ATTRIB · Path splitting | Source. Make_fspec continues after a failed current-directory query. Its unsigned reverse scan has no lower bound. Check_DBCS indexes a 128-byte array using the supplied position. | Return the DOS error immediately and locate separators with a bounded forward character scan. Test invalid drives, root and drive-relative paths, and double-byte separators. | DONE |
| ATTRIB · Binary attribute width | Source. Print_ext_attrib stores a DWORD in a WORD and passes its address to a four-byte message substitution. | Match storage to the message width. Test values with a nonzero upper word, both narrower widths and unsupported lengths. | DONE |
| ATTRIB · ES restoration | Compiler and binary verified. Microsoft C 5.10 emits a near _strcpy call with source offset zero. In the linked executable DGROUP:0 starts with zero. _strcpy sets ES to DS and leaves it there. | Retain the idiom pending evidence for a replacement. For any cleanup, compare generated code at all 16 sites and exercise far-pointer paths with ES initially different from DS. | DONE |

## Style

APPEND and ASSIGN share MASM and DOS interrupt conventions. APPEND uses descriptive labels in its path routines. ASSIGN mixes macro dispatch tables, generated branch labels and commented pseudo-code. ATTRIB uses K&R C with assembler startup and DOS register interfaces. Keep local assembler and C conventions. In touched routines, document segment ownership, clobbered registers, buffer capacities and return status. Prioritize inaccurate comments over cosmetic alignment or historical annotations.

## ASSIGN environment lifetime — booted comparison

EXEC copies the explicit or inherited environment into child-owned storage
(kernel/dos/exec.asm, exec_check_environ through exec_save_environ).
exec_build_header assigns the child PSP as owner and stores the segment at
PSP:002Ch. FreeBlock (kernel/dos/alloc.asm) changes the arena owner without
updating the PSP field. ASSIGN used this field twice on first installation.

On scratch copies of the same full floppy, a DOS probe shrank its own block
to 128 paragraphs, found the resident segment with INT 2Fh/0601h and walked
the conventional MCB chain from the DOS list of lists. All sizes below are
hexadecimal paragraphs.

| Measurement | Original image | Rebuilt ASSIGN |
|---|---:|---:|
| Free before installation | 8D8C | 8D8C |
| Free after ASSIGN B=A | 8D29 | 8D29 |
| Resident-owned blocks and payload | 1 × 0062 | 1 × 0062 |
| Resident PSP environment segment | 11EF | 0000 |
| Free after two cycles of status, mapping and reset | 8D29 | 8D29 |

The install costs 98 payload paragraphs and one arena header. Both runs
showed stable free space. The observed defect was a stale PSP field and a
repeated free in the installation path. No leak was measured. This test did
not establish what happens if another allocator reuses the block between
the two original calls.

For future TSR reviews, record the owner and size of each surviving block,
the PSP environment field, and free paragraphs before install, after install,
and after transient invocations. Record empty-command-line behavior and
ERRORLEVEL separately. Stable memory use alone does not verify either.

## APPEND and ATTRIB boundary checks

- APPEND's assembled routines accepted a 14-byte filename and a 127-byte
  joined path including the separator, with a further byte for the terminator.
  They rejected one extra byte in either case. A fixture with a double-byte
  lead-byte table preserved a backslash trail byte followed by a second
  double-byte character. On booted DOS, an open through APPEND /E skipped a
  128-byte directory and found the file in the next directory. Removing the
  valid directory returned carry set and DOS error 2.
- ATTRIB's packed record validators, counted copy and display routine ran
  under Microsoft C 5.10 with fixture records. Checks covered empty and
  128-byte ASCII values, oversized and truncated fields, name-list counts
  and name lengths, and 1-, 2- and 4-byte binary values. The message
  substitution received the full 0xCDEF1234 value. A 3-byte binary was
  rejected. The fixture substituted the provider data and message sink.

On booted DOS, ASSIGN returned success for installation, status, mapping updates
and reset, and an error for an invalid switch. An FCB probe reused the same
default-drive FCB after changing drives. Both a successful and an unsuccessful
search preserved the caller’s zero drive byte.
ATTRIB resolved root-based and drive-relative paths on B: and rejected Z:.
A separator-scan fixture confirmed that a backslash in the trail byte of a
double-byte character is skipped, while a following separator is recognized.
