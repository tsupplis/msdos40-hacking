# Issue 10 — MOVE and UNDELETE external commands

Assessment against msdos40-hacking at 1dd1ef4. Both commands can ship independently as DOS executables. Neither first release needs changes to MSDOS.SYS, IO.SYS or COMMAND.COM, or adds default resident memory. Measure executable sizes after linking.

## MOVE — implement first

The DOS 4 kernel already moves regular files between directories on one volume with INT 21h AH=56h. In kernel/dos/rename.asm it explicitly rejects a directory changing parents and allows a same-parent rename. Keep that boundary for the first release.

1. Start with one file, an explicit destination name or an existing directory, plus same-parent directory renames. Resolve drive-relative names and reject devices and source/destination aliases before mutation. Report DOS errors. Test same drive, alternate directories, existing target, sharing violation, and attempted directory relocation.
2. Add cross-volume file moves. Trigger the copy path on a genuine cross-device result. Copy to a uniquely created temporary file on the destination volume, check short writes and close errors, preserve timestamps and applicable attributes, and publish before deleting the source. On a source-delete failure report that both copies exist. For overwrite, preserve the existing target through publication and handle rollback failures explicitly. FAT provides no transaction across these steps.
3. Add wildcards and multiple sources targeting a directory, overwrite prompting and /Y. Snapshot matches before mutations can affect enumeration. Test collisions, declined overwrite, same-file aliases, read-only files, disk full and interrupted operations. Check that batch files can detect failures through ERRORLEVEL.

## UNDELETE — establish recovery bounds first

Build a FAT12/FAT16 directory-entry recovery tool. Tracking modes would require recording information before deletion and are a separate deliverable.

1. Ship a read-only listing first. Parse the BPB, validate geometry and region bounds, walk the fixed root or a live subdirectory chain, and identify deleted short-name file entries. Show surviving name bytes, size, date and recovery confidence. Use commands/recover/recproc.asm for DOS 4 packet-form absolute sector I/O and commands/chkdsk for FAT handling. Keep listing free of writes.
2. Recover to a different volume first. Ask for the missing first filename character or a destination name. Zero-length files require no clusters. For a one-cluster file check bounds, FAT copies and allocation state. A free cluster may have been reused and freed again. For multi-cluster files the original chain is lost; label contiguous reconstruction as an explicit guess and decline ambiguous cases by default. Never silently join arbitrary free clusters or overwrite an existing destination.
3. Treat in-place undelete as a separate milestone. On a disposable local image, revalidate the directory slot, filename uniqueness, FAT mirrors and candidate clusters immediately before writing. Resolve DOS buffer/cache coherence and exclusive access before enabling writes. Preserve the adjacent packed FAT12 entry, including sector-boundary cases. Write the chain to each FAT before publishing the live directory entry. Specify recovery from partial writes and interruption; an allocated orphan may require CHKDSK. Exclude directory-tree restoration and redirected volumes from this milestone.

## Integration and acceptance

Register each executable in commands/Makefile and media/Makefile. Reconcile the README's existing UNDELETE “won't implement” row with the delivered scope. Use fresh scratch images with the existing test/check_fat16 and test/fatseed.asm patterns. For UNDELETE cover FAT12 and FAT16, root and subdirectory, empty and single-cluster files, fragmented or reused clusters, inconsistent FAT copies and malformed geometry. Compare recovered bytes with known originals, assert the source image is byte-identical for listing and export, and check all FAT mirrors and CHKDSK results after in-place tests. For MOVE verify file contents and metadata as well as the final source and target names after each injected failure.

Recommended delivery order is same-volume MOVE, full file MOVE, UNDELETE listing/export, then in-place UNDELETE after the cache and failure tests pass.
