# Issue 9 — Lightweight text HELP

Proposed interface: HELP lists commands with one-line descriptions. HELP DIR prints DIR syntax, a short explanation and examples. HELP /? prints HELP's own usage. Output is ordinary DOS text, suitable for HELP DIR > DIR.TXT and HELP | MORE. No menu, resident component or kernel change.

## Implementation

Build an 8086 HELP.COM in commands/help. Generate one compact, alphabetically ordered text table at build time from a maintained source file, and embed it in the COM. Store the canonical name, aliases, one-line summary and detail text for each topic. Scan sequentially. Emit summaries for the index, or only the matching topic for a case-insensitive exact lookup. Map aliases such as ERASE to DEL without duplicating their text. Document the commands and switches actually shipped by this project. Embedding avoids runtime file searches and keeps the executable and reference text in sync.

Use handle writes for stdout and stderr. Page only when output goes to the interactive console. Borrow the screen-row handling and prompt behavior from commands/more/more.asm, including accounting for wrapped lines; verify narrow and standard screens. Keep the pager small and avoid spawning COMMAND or MORE. With a file or pipe as stdout, write continuously with no prompts, key reads or control sequences. Unknown topics should produce a short diagnostic and a nonzero exit code.

## Adding topics

Each command can add a topic independently of its own /? handling. An unknown topic produces a diagnostic. HELP never needs to execute the named command.

## Acceptance

Test index, internal and external topics, aliases, mixed case, /?, missing topic, redirection and HELP | MORE. Check that redirected bytes match the topic text and never prompt, and that an interactive long topic pauses and can quit. Build through commands/Makefile, ship through media/Makefile, update the README HELP row and check the image manifest. Report the linked COM size, topic-data size and allocated floppy clusters separately. Default boot RAM cost is zero. No strict byte target before measuring a prototype.
