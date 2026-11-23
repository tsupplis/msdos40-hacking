## IFSFUNC removal assessment

Normal FAT operation needs no replacement. The compatibility loss is DOS 4 installable filesystem drivers, their CONFIG.SYS loading interface and FILESYS assignments.

### Distribution and startup

- Remove IFSFUNC.EXE and FILESYS.EXE from commands/Makefile, media/Makefile, SELECT's sel_file.inc, test/cases/c_misc.bat and the README inventory. Rebuild all distribution images.
- Retire IFS= in kernel/bios/sysconf.asm, sysinit1.asm and sysinit2.asm. Remove its configuration pass, request packet, driver initialization, callback publication to drivers and chain linking. Preserve DEVICE=, INSTALL= and shared loader logic. Verify an old IFS= line receives the unsupported-directive diagnostic.

### DOS kernel

| Interface | Implementation |
|---|---|
| INT 21h AH=6Bh | Keep the numbered slot in ms_table.asm. Use the existing CPMFunc stub for an AL=0 return. Remove the old forwarding to INT 2Fh AX=112Fh. Preserve AH=6Ch extended open. |
| AX=5D0Bh | Remove the special case before the server table in srvcall.asm which publishes SWAP_AREA_TABLE. Return invalid function. |
| AX=5D06h | Preserve this service before deleting swap descriptors or startup initialization. Derive DS:SI, CX and DX from SWAP_START, Swap_Always and SWAP_END. Check rounding against the existing DOS 4 implementation. |
| AH=5Fh | Keep redirection and redirector forwarding, including 5F07h/08h drive-in-use operations. Removing the FILESYS caller needs no 5F06h blacklist. |
| AH=44h and 69h | Audit ioctl.asm's callifs path to INT 2Fh AX=112Bh case by case. Retain local driver IOCTL, media ID and supported redirector behavior. |

Remove ifs.obj from kernel/dos/Makefile and msdos.lnk after eliminating both references (IFS_DOSCALL in msinit.asm and the 6Bh handler). Preserve the layout and strides of DOS system variables, CDS and SFT structures. Check other readers before removing swap descriptors. Code marked IFS can implement live extended-open or remote-handle behavior.

### COMMAND.COM and SHARE.EXE

- COMMAND's rucode.asm should retain INT 2Fh AX=0500h/0501h for redirector critical-error text and the absent-provider fallback. Clarify the comment.
- In SHARE's gshare2.asm, explicitly chain the retired AX=1040h installation probe. Simply deleting the AL=40h comparison can enter Freeze. Preserve the DOS 4 /NC private calls and ordinary installation check.
- Keep SHARE's three active SFT update calls through Call_IFS (INT 2Fh AX=112Ch). Preserve the flag branches that govern FAT cluster-field copying.

### Size and verification

The assessed build has a 38,800-byte MSDOS.SYS and 53,153-byte IO.SYS. Omitting IFSFUNC.EXE (21,787 bytes) and FILESYS.EXE (11,129 bytes) frees 32,916 bytes of file content per image and zero default-boot RAM. The dedicated ifs.obj contributes 327 linked code bytes, including the 6Bh handler. Additional net kernel and IO.SYS reductions remain unmeasured. SYSINIT savings are primarily boot-image savings.

Compare before/after maps, binary sizes and largest free conventional block with identical FILES, BUFFERS and LASTDRIVE settings under DOS-low and DOS=HIGH. Exercise 5D06h register results, distinct 6Bh and 5D0Bh return behavior, 6Ch extended open, local 440Dh and 69h, DEVICE=/INSTALL= boot, SHARE with and without /NC, file locking, local and redirected handles, and COMMAND's error fallback. This is an implementation assessment; no modified build or runtime savings have been verified.
