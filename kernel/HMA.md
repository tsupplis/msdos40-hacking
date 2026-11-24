# DOS kernel HMA standard

**Progress — Four modules use DOSCODE: PROC, ALLOC, CLOSE and BUF.**

Count the assembly input that produces the object file. Track included sources under their owning module. The inventory lists the affected service sources since v1.2.0. Update the progress line and inventory together after verification.

## Rules for every module

| Area | Convention |
|---|---|
| Ownership | Keep each service and its implementation in its owning assembly module. Put shared declarations in includes. Assemble and link executable routines from source modules. Use 8.3 filenames for DOS build inputs. |
| Placement | Follow the DOS 6.0 code/data split. Use a shared public code segment named `DOSCODE` for converted routines and keep resident data below A20. LINK establishes internal offsets. Boot initialization chooses high or conventional memory, preserves those offsets, and rebinds the declared external entry pointers. |
| Naming | Keep the established public name and spelling, including DOS service names such as `$OPEN`. Refer to an internal routine by its operation, e.g. `PackName`. Use the same symbol in both placements. Retire its `HMA_` alias, numeric selector and placement vector when the last dependent caller is converted. Name a necessary resident entry for the interface it serves. |
| Internal calls | Within the same linked code segment, use the project's near procedure, call and return conventions across file boundaries. Declare external symbols with the correct distance. A tail jump is valid only when the callee accepts the caller's stack frame and return convention. |
| Data access | Treat CS as the executing code segment. State how DS, ES or SS reaches each resident object. Use SS for kernel data only on paths whose ABI guarantees a DOS stack. Preserve caller-supplied far pointers, including device packets and buffers. |
| Entry and return | Preserve the existing ABI at each public entry: register inputs and outputs, preserved registers, flags (especially carry), stack ownership and return distance. Near calls return near, far calls return far, and interrupt entries follow their documented interrupt-return path. Document exceptions such as consuming a caller's return address. |
| External calls and A20 | Keep resident entry code for interfaces that can execute while A20 is off. Give interrupts, SHARE, redirectors, FASTOPEN and device callbacks an explicit A20 and stack contract. Account for re-entry, error exits and callbacks that abandon a frame. Keep A20 and placement decisions out of service bodies. |
| Build | Use MASM symbols and LINK fixups for internal calls. Each converted group must build without instruction-byte rewriting or a packer selector for those calls. Remove obsolete entries and generated data as their consumers disappear. |

## Conversion procedure

1. Record the existing service name, callers, callees, and ABI. Include indirect and error exits. For EXEC, trace the caller’s BP frame, relocation-table reads, and carry on seek/read failure. Run the behavioral baseline before editing.
2. Decide each call from its endpoints. If both ends move together in `DOSCODE`, declare the callee `NEAR` and use its ordinary name. If an interrupt, driver, or caller outside that segment can enter the service, identify the resident entry and its A20, register, and stack contracts first.
3. Keep the routine in its owning module. Use its existing operation name in both placements (for example, `RelocateExe`). Preserve an established exported name such as `$EXEC`. Use `Ptr` for a new stored pointer when that distinction is needed; reserve `Entry` for an actual entry point. Follow existing public spellings. A numbered selector or an `HMA_` prefix is never the name of a new internal call.
4. Check every segment assumption. Record which register addresses kernel data and which far pointers belong to the caller. Trace success, error, and nonlocal returns back to their original stack frames.
5. Assemble the modules and let LINK resolve their references. Boot places the linked range and rebinds its external entries. Remove the superseded selector, alias, vector and packer entry after their final caller is gone.
6. Inspect the map and the linked call target. Test the same binary in high and conventional memory, review the diff, and run regression. Advance the progress count only when the acceptance checks below pass.

## PROC module

MASM assembles `proc.asm` and its included `exec.asm` into one object. In MISC, `DosCodeModules` has one word pointing to PROC's `ProcEntries`. PROC owns the seven vector/target pairs and their public gateways. Both lists end with a zero word. LINK places the functional code in shared `DOSCODE`; startup selects its placement once.

| Boundary | Contract |
|---|---|
| Entry | INT 21h/4Bh uses the resident `$Exec` gateway to enter `LoadProgram`. Process termination uses `Reset_Version` to enter `ResetExecVersion`. Wait, keep, exit, abort and MSCTRLC's critical-error abort enter the other five gateways on the DOS stack. |
| Internal calls | The EXEC routines and their private seek helper are in `DOSCODE`. LINK resolves normal near calls for allocation bookkeeping, file reads, MZ relocation and version handling. The seek adapter also belongs to this segment. |
| Resident services | `CallResident` calls the boot-bound callback with the resident service offset in the next word. The callback preserves inputs and service results, including carry. In the HMA it releases A20 before calling out and reacquires it on a normal return. |
| Data | The EXEC frame is addressed through BP. DOS tables and version counters remain below A20. DS and ES can point into the caller's or child's address space. |
| Child launch | `StartChild` in `proc.asm` takes the child entry in DS:SI, stack in AX:DI, PSP in DX and initial AX in BX. It changes SS:SP in resident code after the callback has released A20 and transfers directly to the child. |
| Legacy TSR | `Stay_resident` receives INT 27h on the caller's stack and converts DX from bytes to paragraphs before transferring to the DOS dispatcher. |
| Termination | Keep and exit branch directly to `FinishProcess`. The final callback enters resident `reset_environment` in MSCTRLC, which restores the parent stack and returns to its termination address. |
| Boot | The linked `DOSCODE` bytes come from `MSDOS.SYS`. SYSINIT copies them into temporary conventional workspace before DOS initialization reuses that part of the loaded kernel. Boot then selects HMA or conventional placement and reclaims the workspace. `IO.SYS` still carries the legacy overlay fragments. |

`test/check_hma` runs the same kernel in HMA and both conventional layouts. It checks EXEC load-and-run, load-only, overlay relocation and errors. It verifies child status after INT 20h, INT 27h and INT 21h functions 00h, 31h and 4Ch. A child on an unformatted scratch floppy requests Abort in its INT 24h handler; the parent must receive 0200h. Clean build and full regression passed (14 batch cases and 9 additional checks).

## ALLOC module

`AllocEntries` binds the resident names `arena_free_process`, `$ALLOC`, `$SETBLOCK`, `$DEALLOC` and `$AllocOper` to their implementations in `DOSCODE`. The arena walk, coalescing, fit selection and UMB link management stay in ALLOC. Arena headers remain in the memory blocks they describe.

PROC calls `AllocateBlock`, `ResizeBlock` and `ExecLargest` directly. The last routine has no resident caller or gateway. Critical-section hooks and system-call return routines use the resident callback. The private INT 21h/58FEh request used by MEM reads DOS placement through MISC's linked `QueryDosResidency` routine.

`test/check_hma` checks allocation, resize, free and the maximum size returned on failed growth. Two consecutive UMB probes must recover the same segment and largest extent after a child exhausts upper memory, falls back to conventional memory and exits. The HMA, near and far layouts passed. The clean build reproduced the tested kernel binaries, and all 23 regression checks passed.

## CLOSE and BUF

MISC registers `CloseEntries` and `BufEntries`. CLOSE calls BUF directly inside DOSCODE. The redirector can enter CLOSE on an application stack, so its resident callback uses DS for DOSGROUP. BUF keeps its disk transfer area below A20.

The active EMS regression (`test/check_ems`) boots the shipped EMM386.SYS with QEMU on a 486 and `BUFFERS=64 /X`. It requires QEMU and NASM, checks the kernel cache mode, injects a BIOS read failure, retries, and compares a copied file after shutdown.

## Linked modules and dependencies

The module name is the object filename in the LINK response file. Each row lists the INCLUDE directives in the top-level assembly source and the other objects that supply its external code or data references in this build. Conditional INCLUDE directives appear even when disabled. The object dependencies come from MASM fixup records resolved against the defining objects' public symbols. A reference can be a call, pointer, dispatch-table entry or shared variable. Runtime calls through interrupt vectors and installed drivers require a separate interface review.

### MSDOS.SYS

[msdos.lnk](dos/msdos.lnk) lists 54 objects. Five are built in `common/`: `const2`, `msdata`, `msdosme`, `mstable` and `nibdos`. The others are built in `kernel/dos/`. Names in the dependency column refer to objects in this same image.

**PROC example.** `proc.asm` directly includes `dosseg.asm`, `dossym.inc`, `devsym.inc` and `exec.asm`. In turn, `exec.asm` includes `ea.inc` and `version.inc`. `dosseg.asm` declares the shared segments and DOSGROUP. `exec.asm` emits code and data into those segments as part of PROC. Both are assembly-time dependencies. At link time, for example, PROC's `DosCallbackPtr` reference resolves to MISC and its near call to `AllocateBlock` resolves to ALLOC.

| Module (.obj) | Direct source includes | Direct links to other modules | HMA review |
|---|---|---|---|
| ABORT | dosseg.asm, dossym.inc, devsym.inc | CONST2, HANDLE, NIBDOS, UTIL | — |
| ALLOC | dosseg.asm, dossym.inc, devsym.inc | CONST2, CRIT, MISC, MSCODE, MSDISP, NIBDOS | DOSCODE, Whole Module Relocatable |
| BUF | dosseg.asm, dossym.inc, devsym.inc, version.inc | CONST2, CRIT, DISK, DISK2, MISC, MSDATA, MSDISP, MSTABLE, NIBDOS | DOSCODE, Whole Module Relocatable. EMS interrupt adapter and cache data stay resident. |
| CLOSE | dosseg.asm, dossym.inc, devsym.inc, bugtyp.asm | BUF, CONST2, CRIT, DELETE, DEV, DIR, FAT, MISC, MISC2, MSDATA, MSTABLE, NIBDOS, SHARE, TIME | DOSCODE, Whole Module Relocatable. Redirector and SHARE callbacks use resident adapters. |
| CONST2 | dossym.inc, dosseg.asm, devsym.inc | CRIT, MSDATA | — |
| CPMIO | dosseg.asm, dossym.inc, devsym.inc, doscntry.inc, kstrin.asm, editsw.inc, strin.asm | CONST2, CPMIO2, DEV, DISK, MSCTRLC, MSDATA, MSDOSME, MSTABLE, NIBDOS, TIME | — |
| CPMIO2 | dosseg.asm, dossym.inc, devsym.inc | CONST2, CPMIO, DEV, DISK, MSCTRLC, MSDISP | — |
| CREATE | dosseg.asm, dossym.inc, devsym.inc, version.inc | CONST2, CRIT, DELETE, FAT, IOCTL, MISC, MKNODE, MSDATA, MSTABLE, OPEN | Legacy local create and node creation. |
| CRIT | dosseg.asm, dossym.inc, bugtyp.asm | — | — |
| DELETE | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, fastseek.inc, fastxxxx.inc | BUF, CONST2, CREATE, CRIT, DIR, DIR2, FAT, MACRO2, MISC2, MKNODE, MSDATA, MSTABLE, NIBDOS, ROM, SEARCH, SHARE | — |
| DEV | dosseg.asm, dossym.inc, devsym.inc, version.inc | CONST2, CRIT, DISK, IOCTL, MSCTRLC, MSDATA, MSDISP, MSTABLE, NIBDOS | — |
| DINFO | dosseg.asm, dossym.inc, devsym.inc, bugtyp.asm | CONST2, CRIT, FAT, MISC2, MSDATA | — |
| DIR | dosseg.asm, fastopen.inc, dossym.inc | CONST2, DIR2, DISK, FAT, MISC, MSDATA, MSTABLE, ROM | Legacy directory walker and search entries. |
| DIR2 | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc | BUF, CONST2, CRIT, DIR, DIRCALL, DISK, FAT, FCB, MACRO2, MISC, MISC2, MSDATA, MSTABLE, NIBDOS, TIME | Legacy path walker. Preserve FASTOPEN callbacks. |
| DIRCALL | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, fastxxxx.inc | BUF, CONST2, CREATE, CRIT, DELETE, DIR, DIR2, MISC, MISC2, MKNODE, MSDATA, MSTABLE, ROM | Legacy directory verb entries. |
| DISK | dosseg.asm, fastseek.inc, fastxxxx.inc, dossym.inc, devsym.inc, version.inc | BUF, CLOSE, CONST2, CPMIO, CPMIO2, CRIT, DEV, DISK2, DISK3, FAT, LOCK, MISC, MISC2, MSCTRLC, MSDATA, MSDISP, MSTABLE, NIBDOS, ROM, UTIL | Legacy read/write entries and vectors. |
| DISK2 | dosseg.asm, dossym.inc, devsym.inc, version.inc | BUF, CONST2, DEV, DISK, DISK3, FAT, LOCK, MSCTRLC, MSDATA, MSDISP, MSTABLE, NIBDOS, ROM | Legacy setup paths can consume a near return address. |
| DISK3 | dosseg.asm, dossym.inc, devsym.inc, version.inc | BUF, CONST2, DELETE, DEV, DISK, DISK2, MSCTRLC, MSDATA, MSDISP, MSTABLE, NIBDOS, OPEN, ROM | Legacy file growth crosses SHARE. |
| DUP | dosseg.asm, dossym.inc, devsym.inc | DEV, MISC2, MSDATA | — |
| EXTATTR | dosseg.asm, dossym.inc, devsym.inc, ea.inc | MSDATA, MSDISP, MSTABLE | — |
| FAT | dosseg.asm, dossym.inc, devsym.inc | BUF, CONST2, DEV, MISC, MSCODE, MSCTRLC, MSDATA, MSTABLE, NIBDOS | Legacy FAT packing and EOF entries. |
| FCB | dosseg.asm, dossym.inc, devsym.inc, doscntry.inc | CONST2, MACRO, MISC, MSDATA, MSDOSME | Legacy FCB construction and name translation. |
| FCBIO | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, bugtyp.asm | CLOSE, CONST2, DELETE, DIR2, FCBIO2, FINFO, LOCK, MACRO, MACRO2, MISC, MISC2, MSCODE, MSCTRLC, MSDATA, MSDISP, NIBDOS, RENAME | Legacy FCB dispatch and indirect I/O. |
| FCBIO2 | dosseg.asm, dossym.inc, devsym.inc, version.inc, bugtyp.asm | BUF, CONST2, CREATE, DISK, FCBIO, LOCK, MACRO, MACRO2, MISC2, MSCODE, MSDATA, MSDISP, NIBDOS, OPEN, SHARE, TIME | Legacy record I/O, shared buffers and SHARE callbacks. |
| FILE | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, ea.inc, version.inc, bugtyp.asm | CONST2, CREATE, CRIT, DELETE, FCB, FINFO, HANDLE, MACRO, MACRO2, MISC, MISC2, MSCODE, MSDATA, MSDISP, MSTABLE, NIBDOS, OPEN, RENAME, TIME, UTIL | Legacy file-service entries. |
| FINFO | dosseg.asm, dossym.inc, devsym.inc, fastxxxx.inc, fastopen.inc | BUF, CONST2, CRIT, DELETE, DIR2, MISC2, MSDATA, MSTABLE | — |
| GETSET | dosseg.asm, dossym.inc, devsym.inc, doscntry.inc | CONST2, DINFO, FCB, MACRO, MSCODE, MSDISP, MSDOSME, MSTABLE, NIBDOS | — |
| HANDLE | dosseg.asm, dossym.inc, devsym.inc, ea.inc, version.inc, bugtyp.asm | ALLOC, BUF, CLOSE, CONST2, CRIT, DISK, DUP, EXTATTR, MSCODE, MSDATA, MSDISP, MSTABLE, NIBDOS, UTIL | — |
| IOCTL | dosseg.asm, dossym.inc, devsym.inc, ioctl.inc, ifssym.inc | CONST2, DEV, DISK, MACRO, MSCODE, MSCTRLC, MSDATA, MSDISP, NIBDOS, UTIL | — |
| ISEARCH | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, fastxxxx.inc | CONST2, CRIT, DIR, DIR2, MACRO, MSCODE, MSDATA, MSTABLE | Legacy search start and continuation. |
| LOCK | dosseg.asm, dossym.inc, devsym.inc, lock.inc | CONST2, MISC2, MSCODE, MSCTRLC, MSDATA, NIBDOS, UTIL | — |
| MACRO | dosseg.asm, dossym.inc, devsym.inc | CONST2, MSCODE, MSDATA, MSDISP, NIBDOS | — |
| MACRO2 | dosseg.asm, dossym.inc, devsym.inc | CONST2, CRIT, DIR2, FAT, FCB, MACRO, MISC, MISC2, MSCODE, MSDATA, NIBDOS, SEARCH | Legacy pathname and FCB translation entries. |
| MISC | dosseg.asm, dossym.inc, devsym.inc, bugtyp.asm | ALLOC, BUF, CLOSE, CONST2, CRIT, DINFO, DUP, FAT, IOCTL, MACRO, MSCODE, MSDATA, MSDISP, MSTABLE, NIBDOS, PROC, UTIL | Gateway and callbacks. Keep A20 and return-frame handling here. |
| MISC2 | dosseg.asm, dossym.inc, fastseek.inc, fastxxxx.inc, bugtyp.asm | CONST2, FCB, FILE, HANDLE, IOCTL, MSDATA, MSTABLE, NIBDOS | — |
| MKNODE | dosseg.asm, fastopen.inc, dossym.inc, devsym.inc | BUF, CONST2, CRIT, DELETE, DEV, DIR, DIR2, DISK, FAT, MISC, MSDATA, MSTABLE, ROM, SHARE, TIME | Legacy node creation across directory and FAT modules. |
| MSCODE | mssw.asm, ms_code.asm | BUF, CONST2, CRIT, DELETE, DISK2, MACRO, MISC, MISC2, MSDATA, MSDISP, MSTABLE | — |
| MSCTRLC | mssw.asm, ctrlc.asm | ABORT, ALLOC, BUF, CONST2, CPMIO, CPMIO2, CRIT, DEV, DISK, GETSET, MKNODE, MSCODE, MSDATA, MSDISP, MSDOSME, MSTABLE, NIBDOS, PROC | — |
| MSDATA | mssw.asm, dosseg.asm, dosmac.inc, sf.inc, dirent.inc, curdir.inc, dpb.inc, buffer.inc, arena.inc, vector.inc, devsym.inc, pdb.inc, find.inc, mi.inc, ms_data.asm, msinit.asm | CONST2, DEV, MISC, MSCODE, MSCTRLC, MSDISP, MSDOSME, MSTABLE, NIBDOS, PROC | — |
| MSDISP | mssw.asm, disp.asm | CONST2, CRIT, MSCTRLC, MSDATA, MSTABLE, NIBDOS | — |
| MSDOSME | mssw.asm, dosseg.asm, dosmes.asm | CPMIO | — |
| MSTABLE | mssw.asm, ms_table.asm | ALLOC, BUF, CLOSE, CPMIO, CPMIO2, DIR2, FCB, FCBIO, FCBIO2, FILE, GETSET, HANDLE, IOCTL, LOCK, MACRO, MACRO2, MISC, MISC2, MSCODE, MSCTRLC, MSDISP, MSDOSME, NIBDOS, OPEN, PARSE, PATH, PROC, SEARCH, SHARE, SRVCALL, TIME, UTIL | — |
| NIBDOS | mssw.asm, msconst.asm | CONST2, MSCODE, MSDATA, MSDISP | — |
| OPEN | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, fastxxxx.inc, ifssym.inc | CONST2, CRIT, DELETE, DEV, DIR2, MISC, MISC2, MKNODE, MSDATA, MSTABLE, NIBDOS, SHARE | Legacy local open and SHARE callbacks. |
| PARSE | dosseg.asm, dossym.inc, devsym.inc | FCB, MSDISP | — |
| PATH | dosseg.asm, dossym.inc, devsym.inc | CONST2, CRIT, DIR2, DIRCALL, MACRO, MACRO2, MISC2, MSCODE, MSDATA, MSDISP | — |
| PROC | dosseg.asm, dossym.inc, devsym.inc, exec.asm | ALLOC, CONST2, CRIT, FILE, HANDLE, IOCTL, MACRO, MISC, MISC2, MSCODE, MSCTRLC, MSDATA, MSDISP, MSTABLE, NIBDOS, UTIL | DOSCODE, Whole Module Relocatable |
| RENAME | dosseg.asm, dossym.inc, devsym.inc | BUF, CONST2, CRIT, DELETE, DIR, DIR2, ISEARCH, MISC, MISC2, MKNODE, MSDATA, PATH, SHARE | Legacy rename and directory search continuation. |
| ROM | dosseg.asm, fastseek.inc, fastxxxx.inc, version.inc, dossym.inc, devsym.inc, ea.inc | BUF, CONST2, DELETE, FAT, MISC, MSDATA, MSTABLE | Legacy cluster allocation. Preserve disk-full and partial allocation exits. |
| SEARCH | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, fastxxxx.inc | CONST2, ISEARCH, MACRO2, MISC, MSCODE, MSDATA | Legacy name packing and find dispatch. |
| SHARE | dosseg.asm, dossym.inc, devsym.inc | CONST2, MISC2, MSCTRLC, MSDATA, NIBDOS | — |
| SRVCALL | dosseg.asm, dossym.inc, devsym.inc, dpl.asm | CLOSE, CONST2, CRIT, IOCTL, MISC2, MSCODE, MSDATA, MSDISP, NIBDOS, UTIL | — |
| TIME | dosseg.asm, dossym.inc, devsym.inc | CONST2, DEV, MSDATA, MSDISP, MSTABLE, NIBDOS | — |
| UTIL | dosseg.asm, dossym.inc, devsym.inc, bugtyp.asm | CONST2, NIBDOS | — |



### IO.SYS

[msbio.lnk](bios/msbio.lnk) links the following 15 BIOS objects. MSLOAD is a sixteenth, independently linked module. The [BIOS Makefile](bios/Makefile) prepends its binary to the linked BIOS body. The DOS and BIOS object lists are separate. During boot SYSINIT1 invokes FCBLOAD to copy the linked DOSCODE range from the loaded MSDOS.SYS. FCBPACK is generated from the DOS link output and legacy object fixups. Its table row describes its BIOS-side object dependencies.

| Module (.obj) | Direct source includes | Direct links to other modules |
|---|---|---|
| FCBLOAD | fcbsizes.inc, msbio.cl6, fcbtable.inc | FCBPACK, SYSINIT1, SYSINIT2 |
| FCBPACK | — | — |
| MSAUX | msgroup.inc, jumpmac.inc, msmacro.inc | MSBIO1, MSCON |
| MSBIO1 | msgroup.inc, jumpmac.inc, pushpop.inc, devsym.inc, msdskpr.inc, msbdata.inc, msmacro.inc | MSAUX, MSBIO2, MSCLOCK, MSCON, MSDISK, MSINIT, MSLPT |
| MSBIO2 | msgroup.inc, msequ.inc, devsym.inc, pushpop.inc, msmacro.inc, msbio.cl2, ms96tpi.inc | MSBIO1, MSCON, MSDISK |
| MSCLOCK | msgroup.inc, msmacro.inc | MSBIO1 |
| MSCON | msgroup.inc, jumpmac.inc, msequ.inc, msmacro.inc | MSBIO1 |
| MSDISK | msgroup.inc, msequ.inc, pushpop.inc, msmacro.inc, devsym.inc, msdskpr.inc, biostruc.inc, msioctl.inc | MSBIO1, MSBIO2 |
| MSHARD | — | MSBIO1 |
| MSINIT | msgroup.inc, msdskpr.inc, msequ.inc, msmacro.inc, msextrn.inc, biostruc.inc, cmosequ.inc, cputype.inc, readcloc.inc, clocksub.inc | MSBIO1, MSBIO2, MSCLOCK, MSCON, MSDISK, MSHARD, SYSIMES, SYSINIT1 |
| MSLPT | msgroup.inc, msequ.inc, msmacro.inc, devsym.inc, ioctl.inc | MSBIO1 |
| SYSCONF | smdossym.inc, devsym.inc, ioctl.inc, biostruc.inc, smifssym.inc, devmark.inc, version.inc, psoption.inc, parse.asm | MSBIO1, MSDISK, SYSIMES, SYSINIT1, SYSINIT2 |
| SYSIMES | msequ.inc, msmacro.inc, msbio.cl3 | — |
| SYSINIT1 | smdossym.inc, devsym.inc, ioctl.inc, biostruc.inc, smifssym.inc, defems.inc, devmark.inc, cputype.inc, version.inc, msstack.inc, msbio.cl5, msbio.cl4, stkinit.inc | FCBLOAD, MSBIO2, MSDISK, SYSCONF, SYSIMES, SYSINIT2 |
| SYSINIT2 | smdossym.inc, devsym.inc, ioctl.inc, devmark.inc, copyrigh.inc | MSDISK, SYSCONF, SYSIMES, SYSINIT1 |
| MSLOAD (separate link) | msload.inc, bootform.inc, versiona.inc, msbio.cl1 | — |

## Acceptance checks

1. The link map and linked instructions show that internal calls resolve to their named targets in the movable segment. Check both incoming and outgoing calls and remove the corresponding packer dependencies.
2. Exercise the same service on the same binary in HMA and conventional memory, including both existing fallback layouts where applicable. Verify the result, carry/error behavior and any affected external callback or nonlocal return.
3. Review the source and map, then run regression. Record the verified module names and test result when advancing the progress line. Preserve independent functional fixes throughout.
