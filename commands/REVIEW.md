# Command review

Check empty and invalid input, stderr, ERRORLEVEL, side effects, bounds,
resource ownership, local coding conventions and DOSHELP. Preserve meaningful
defaults. Use controlled diagnostics: `COMMAND: Required parameters missing.`
or `COMMAND: Invalid …`. Verify fixes before closing them.

## APPEND

| Issue | Status |
|---|---|
| Bound resident filenames, directories and joined paths | CLOSED |
| Preserve double-byte filename separators | CLOSED |
| Prefix parser errors and return failure after installation | CLOSED |
| Send empty and populated list queries to stdout | CLOSED |

## ASSIGN

| Issue | Status |
|---|---|
| Release the resident environment once and clear its PSP pointer | CLOSED |
| Return zero on successful installation, update, status and reset | CLOSED |
| Restore the caller's original FCB drive byte | CLOSED |
| Prefix invalid switch and mapping diagnostics | CLOSED |

## ATTRIB

| Issue | Status |
|---|---|
| Validate counted extended attributes and binary widths | CLOSED |
| Bound path splitting and propagate invalid-drive errors | CLOSED |
| Retain compiler-verified ES restoration | CLOSED |
| Distinguish missing operands, invalid switches and invalid parameters | CLOSED |

## FC

| Issue | Status |
|---|---|
| Bound operands and line-buffer allocations | CLOSED |
| Distinguish /N from /Dcount and validate complete switches | CLOSED |
| Preserve the final byte under /T | CLOSED |
| Skip blank lines under /W while retaining physical line numbers | CLOSED |
| Propagate read errors and differences after resynchronization | CLOSED |
| Send command-prefixed diagnostics to stderr and update DOSHELP | CLOSED |

## TREE

| Issue | Status |
|---|---|
| Command-prefixed invalid switch and parameter diagnostics | CLOSED |
| Exclude the path terminator from listing output | CLOSED |
| Default listing, case-insensitive /A and /F, and DOSHELP | CLOSED |

## EDLIN

| Issue | Status |
|---|---|
| Report missing filenames on stderr | CLOSED |
| Distinguish invalid switches and operands; exit on parser errors | CLOSED |
| Case-insensitive /B and DOSHELP | CLOSED |

## DELTREE

| Issue | Status |
|---|---|
| Skip unrelated floppy drives before confirmation | CLOSED |
| Protect an active SUBST root and current-directory ancestors before descent | CLOSED |
| Report missing and invalid operands on stderr and fail on unmatched targets | CLOSED |
| Document wildcards, confirmation and rejected root or dot operands in DOSHELP | CLOSED |
| Preserve double-byte trailing 5Ch in path splitting and separator trimming | CLOSED |
| Reject explicit UNC share roots, including repeated separators | CLOSED |
| Protect the current directory and its ancestors across two NetMount drive letters for the same share | CLOSED |

## MOVE

| Issue | Status |
|---|---|
| Distinguish missing operands from invalid syntax on stderr | CLOSED |
| Preserve source and original destination on disk-full and failed rename | CLOSED |
| Report retained destination and preserve read-only source after failed deletion | CLOSED |

## LABEL

| Issue | Status |
|---|---|
| Accept a space after the drive and reject invalid command-line labels | CLOSED |
| Handle redirected Yes, No and EOF without unintended deletion | CLOSED |
| Check deletion and close errors and restore the previous label on failed replacement | CLOSED |

## SYS

| Issue | Status |
|---|---|
| Propagate transfer failures to ERRORLEVEL, including target close and boot-sector write failures | CLOSED |
| Reject overlong source paths and document the optional source operand | CLOSED |
| Boot-record preparation can continue after a failed device-parameter or media-ID query | CLOSED |
| Missing target uses the generic parser diagnostic without the command name | CLOSED |

## FDISK

| Issue | Status |
|---|---|
| Reject a zero-cylinder allocation before writing the partition table | CLOSED |
| Report failed disk discovery during command-line partition creation | CLOSED |
| Document partition creation and the effect of /MBR on an unsigned sector | CLOSED |

## FORMAT

| Issue | Status |
|---|---|
| Propagate resident system-file write and close failures through /S and return a fatal status | CLOSED |
| Target timestamp failure can be masked by a successful close | CLOSED |

## FIND

| Issue | Status |
|---|---|
| Distinguish no match from I/O errors and preserve earlier failures across files | CLOSED |
| Reset both bytes of the per-file match and line counters | CLOSED |

## SORT

| Issue | Status |
|---|---|
| Report failed input reads and output writes | CLOSED |
| Produce no output for empty input or a leading Ctrl+Z | CLOSED |
| Keep large column offsets out of the blank comparison buffer | CLOSED |
| Preserve the final record without CRLF and move long records within the buffer | CLOSED |

## MORE

| Check | Status |
|---|---|
| Verify file and piped input, extra operands, missing files and read failures | CLOSED |

## MEM

| Issue | Status |
|---|---|
| Return zero after a successful report, as in DOS 6.0 | CLOSED |
| Honor the PSP command-tail length and report invalid input on stderr | CLOSED |
| Read the environment segment from PSP:2Ch and bound the /D owner-name lookup by the environment MCB | CLOSED |
| Send /C allocation failures to stderr and return failure while preserving the summary | CLOSED |

## EXE2BIN

| Issue | Status |
|---|---|
| Convert paragraph-aligned MZ images using the exact header length | CLOSED |
| Validate file length, COM origin, relocation table and fixup targets before creating output | CLOSED |
| Return failure on parser, conversion and DOS errors and prefix diagnostics | CLOSED |
| Discard a partially parsed relocation segment before retrying | CLOSED |

## CHKDSK

| Issue | Status |
|---|---|
| Apply DOS 6.0 fix M106 to the FAT-copy count. Verify a two-copy, 256-sector FAT repair byte for byte | CLOSED |
| Propagate directory and individual FAT write failures to ERRORLEVEL | CLOSED |
| Return immediately on failed intermediate reads and writes so the caller can use the alternate FAT | CLOSED |
| Reject invalid switches and drives with command-prefixed errors on stderr | CLOSED |
| Count only recovered files with successful directory writes and keep orphan clusters allocated in the free-space report | CLOSED |

## FASTOPEN

| Issue or check | Status |
|---|---|
| Conventional cache on eight physical disks and EMS cache on eight logical volumes with EMM386 | VERIFIED |
| Size and copy the parameter table for all 24 letters. Verify persisted writes to C: through Z: on eight physical disks | CLOSED |
| Walk mixed name-only and extent-enabled entries correctly and restrict extent lookup and purge to configured volumes | CLOSED |
| Honor EMS mapping failures and unwind the handle and saved mapping after failed installation | CLOSED |
| Clear the resident PSP environment pointer after releasing the environment | CLOSED |
| Send prefixed diagnostics to stderr and document required drive and optional cache counts in DOSHELP | CLOSED |
| Suppress consecutive purges only when they address the same drive | CLOSED |

DOS 6.0 retains the PSP environment lookup error in MEM, the page-rounded MZ
header in EXE2BIN, the intermediate I/O error branches in CHKDSK and the
50-byte initialization table in FASTOPEN. These paths use local corrections.
