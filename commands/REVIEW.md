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
| Path splitting and trailing separator removal are byte-based on double-byte code pages | OPEN |
| Verify redirector aliases and UNC share-root protection on a network drive | OPEN |
