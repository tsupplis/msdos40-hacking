# EDIT for MS-DOS 4.01N

`EDIT` starts an untitled buffer. `EDIT filename` opens or creates a named file. The port derives from
Salvatore Sanfilippo's Kilo and its CP/M-86 adaptation. It uses the PC BIOS
for keyboard input and the active text display. No ANSI.SYS is required.
Press F1 while editing or searching for keyboard help. Esc or F1 returns
to the same position and selection. Run `EDIT /?` or `HELP EDIT` for command-line usage.

Hold Shift with arrows, Home, End, PgUp or PgDn to select text. Ctrl-C copies,
Ctrl-X cuts and Ctrl-V pastes. The clipboard lasts until EDIT exits.
Ctrl-Z undoes the last edit, up to five edits back. Each typed character,
line break, deletion, cut, paste or selection replacement counts as one edit.
Typing, Enter or paste replaces the selection. Esc clears it. Ctrl-F searches literally
and Ctrl-Shift-F folds case using the current DOS uppercase table.
The arrows in Find visit individual occurrences. After Enter, F3 repeats the
search forward and Shift-F3 repeats it backward, wrapping at the ends.
Ctrl-R replaces all literal matches throughout the file. Ctrl-Shift-R uses
the same DOS case folding. Enter the search text, then the replacement.
Find and both Replace fields accept up to 64 bytes. If you exceed the limit,
Enter or Esc dismisses the warning and cancels the operation. Accepting a
Find with no match restores the starting position. An empty replacement
deletes matches. Esc cancels either Replace prompt. One Ctrl-Z
undoes the entire operation. Ctrl-S saves. An untitled buffer prompts for a
filename. Ctrl-Shift-S saves under another name. Ctrl-O opens an existing file
and asks before discarding unsaved edits. If loading fails, the current
buffer and undo history remain available. Switching files needs enough memory
to hold both documents until the new one has loaded.

The editor reads DOS CRLF and Unix LF, including mixed files. Saving writes
CRLF for every line break, even without edits. A missing final newline, DOS
code-page bytes and an optional final Ctrl-Z are preserved. Enter inserts CRLF.
An embedded NUL or Ctrl-Z rejects the complete load. Saving needs enough
free disk space for a second copy in the target directory. A failed write
keeps the original and the edited buffer. If the final rename fails, EDIT
reports recovery filenames in the document directory. Ctrl-S leaves an
unchanged DOS-format document alone. If the destination appeared, disappeared,
or its contents changed since opening or saving, press Ctrl-S again to
confirm that version. Any other key cancels the confirmation.

## Build and capacity

Run `make -C edit` from the project root. Microsoft C 5.1 compact
model keeps code in one segment and allocates text on the far heap. Large
model would add far code calls without increasing the usable data space.
Each line stores its bytes once. Tabs expand for display only.

The limit is 32,766 text bytes per line. The contiguous row directory grows
in groups of 64 entries and must fit in one segment. Conventional memory,
line count, heap fragmentation and the space needed for an insertion
determine the usable document size.

| Measurement | Largest complete load | First refused |
|---|---:|---:|
| emu2, file-test build, 78 bytes plus CRLF per line | 450,480 bytes | 450,560 bytes |
| emu2, file-test build, 1,022 bytes plus CRLF per line | 580,608 bytes | 581,632 bytes |

The production executable also passed an interactive edit, find and save
of a 144,025-byte file under DOS 4.01N in a 640 KiB PCE machine.

## Verification

- `make -C edit test` exercises file loading, editing at allocation
  failure, streaming saves, replacement and rollback with the target runtime.
- `test/check_cmdhelp` compares the command's help with the shared viewer.
- `test/check_screenedit` boots the full floppy and checks BIOS keyboard
  input, screen output and the saved file on a scratch FAT floppy. Both this
  check and the command-line editing check (`test/check_edit`) use
  `pce-ibmpc` from PATH. Set `PCE_HEADLESS` to the headless executable if
  the default build needs a desktop session.
- The base, distribution and full images include EDIT.EXE and EDIT.LIC.
