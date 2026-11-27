# DOS kernel HMA standard

**Progress — 35 whole modules relocatable in DOSCODE.** PROC, ALLOC, CLOSE, BUF, DINFO, CREATE, ROM, MKNODE, FINFO, DUP, DISK, DISK2, DISK3, EXTATTR, FILE, ISEARCH, CPMIO, CPMIO2, ABORT, SEARCH, RENAME, OPEN, FAT, DIR, DIR2, DIRCALL, FCB, FCBIO, FCBIO2, MACRO2, GETSET, PARSE, TIME, DEV and PATH.

Count the assembly input that produces the object file. Track included sources under their owning module. The inventory lists the affected service sources since v1.2.0. Update the progress line and inventory together after verification.

## Rules for every module

| Area | Convention |
|---|---|
| Ownership | Keep each service and its implementation in its owning assembly module. Put shared declarations in includes. Assemble and link executable routines from source modules. Use 8.3 filenames for DOS build inputs. |
| Placement | Follow the DOS 6.0 code/data split. Use a shared public code segment named `DOSCODE` for converted routines and keep resident data below A20. LINK establishes internal offsets. SYSINIT tries the HMA when HIGH is requested, then a contiguous upper memory block when UMB is requested, then conventional memory. It preserves offsets and binds external entry pointers. |
| Naming | Keep the established public name and spelling, including DOS service names such as `$OPEN`. Refer to an internal routine by its operation, e.g. `PackName`. Use the same symbol in every placement. Retire its `HMA_` alias, numeric selector and placement vector when the last dependent caller is converted. Name a necessary resident entry for the interface it serves. |
| Internal calls | Within the same linked code segment, use the project's near procedure, call and return conventions across file boundaries. Declare external symbols with the correct distance. A tail jump is valid only when the callee accepts the caller's stack frame and return convention. |
| Data access | Treat CS as the executing code segment. State how DS, ES or SS reaches each resident object. Use SS for kernel data only on paths whose ABI guarantees a DOS stack. Preserve caller-supplied far pointers, including device packets and buffers. |
| Entry and return | Preserve the existing ABI at each public entry: register inputs and outputs, preserved registers, flags (especially carry), stack ownership and return distance. Near calls return near, far calls return far, and interrupt entries follow their documented interrupt-return path. Document exceptions such as consuming a caller's return address. |
| External calls and A20 | Keep resident entry code for interfaces that can execute while A20 is off. Give interrupts, SHARE, redirectors, FASTOPEN and device callbacks an explicit A20 and stack contract. Account for re-entry, error exits and callbacks that abandon a frame. Keep A20 and placement decisions out of service bodies. |
| Build | Use MASM symbols and LINK fixups for internal calls. Each converted group must build without instruction-byte rewriting or a packer selector for those calls. Remove obsolete entries and generated data as their consumers disappear. |

## Conversion procedure

1. Record the existing service name, callers, callees, and ABI. Include indirect and error exits. For EXEC, trace the caller’s BP frame, relocation-table reads, and carry on seek/read failure. Run the behavioral baseline before editing.
2. Decide each call from its endpoints. If both ends move together in `DOSCODE`, declare the callee `NEAR` and use its ordinary name. If an interrupt, driver, or caller outside that segment can enter the service, identify the resident entry and its A20, register, and stack contracts first.
3. Keep the routine in its owning module. Use its existing operation name in every placement (for example, `RelocateExe`). Preserve an established exported name such as `$EXEC`. Use `Ptr` for a new stored pointer when that distinction is needed; reserve `Entry` for an actual entry point. Follow existing public spellings. A numbered selector or an `HMA_` prefix is never the name of a new internal call.
4. Check every segment assumption. Record which register addresses kernel data and which far pointers belong to the caller. Trace success, error, and nonlocal returns back to their original stack frames.
5. Assemble the modules and let LINK resolve their references. Boot places the linked range and rebinds its external entries. Remove the superseded selector, alias, vector and packer entry after their final caller is gone.
6. Inspect the map and the linked call target. Test the same binary in HMA, UMB and conventional memory, review the diff, and run regression. Advance the progress count only when the acceptance checks below pass.

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
| Boot | The linked `DOSCODE` bytes come from `MSDOS.SYS`. SYSINIT copies them into temporary conventional workspace before DOS initialization reuses that part of the loaded kernel. Boot places the code and reclaims the workspace. A UMB allocation is permanent and uses the far gateway with the body at offset 100h. The build reads the linked map and entry tables to emit placement metadata. All placements execute the same linked bytes. |

`test/check_hma` runs the same kernel in HMA, UMB and both conventional layouts. It also boots with an HMA request and a UMB-only provider, and with fragmented UMBs that force conventional fallback. It checks EXEC load-and-run, load-only, overlay relocation and errors. It verifies child status after INT 20h, INT 27h and INT 21h functions 00h, 31h and 4Ch. A child on an unformatted scratch floppy requests Abort in its INT 24h handler; the parent must receive 0200h.

## ALLOC module

`AllocEntries` binds the resident names `arena_free_process`, `$ALLOC`, `$SETBLOCK`, `$DEALLOC` and `$AllocOper` to their implementations in `DOSCODE`. The arena walk, coalescing, fit selection and UMB link management stay in ALLOC. Arena headers remain in the memory blocks they describe.

PROC calls `AllocateBlock`, `ResizeBlock` and `ExecLargest` directly. The last routine has no resident caller or gateway. Critical-section hooks and system-call return routines use the resident callback. The private INT 21h/58FEh request used by MEM reports HMA residency through MISC's linked `QueryDosResidency` routine.

`test/check_hma` checks allocation, resize, free and the maximum size returned on failed growth. Two consecutive UMB probes must recover the same segment and largest extent after a child exhausts upper memory, falls back to conventional memory and exits.

## CLOSE and BUF

MISC registers `CloseEntries` and `BufEntries`. CLOSE calls BUF directly inside DOSCODE. The redirector can enter CLOSE on an application stack, so its resident callback uses DS for DOSGROUP. BUF keeps its disk transfer area below A20.

The active EMS regression (`test/check_ems`) boots the shipped EMM386.SYS with QEMU on a 486 and `BUFFERS=64 /X /L`. It requires QEMU and NASM, checks the kernel cache mode, injects a BIOS read failure, retries, and compares a copied file after shutdown.

## DINFO and CREATE

`DinfoEntries` binds the disk-information gateway. `CreateEntries` binds create, exclusive create, node-error translation, media-ID update and extended-mode setup. CREATE keeps its lookup table in resident TABLE. Its redirector adapters push the attributes immediately before INT 2Fh. DINFO calls the redirector through a resident adapter and reads FAT entries directly in DOSCODE.

## ROM, MKNODE and FINFO

ROM owns cluster allocation, release and traversal. MKNODE calls ROM and BUF directly for cluster and buffer operations. Its node creation and rename bodies share ordinary near entries with the other movable callers. FINFO keeps the INT 2Fh redirector adapters resident, including the stack argument for setting attributes.

## DUP, DISK, DISK2, DISK3 and EXTATTR

DUP uses DS for kernel callbacks during DOS initialization, when SS belongs to the boot caller. Its direct handle entry preserves the caller’s DS and uses the DOS stack segment to obtain DOSGROUP.

DISK calls DISK2’s SETUP directly. The EOF and zero-capacity exits consume the near return address and return to the read or write caller. DISK2 retains resident entries for absolute disk I/O. DISK3 has only movable callers, so its module list has no gateway slots. EXTATTR keeps its handle interface and returns the local attribute size through the saved user registers.

## FILE, ISEARCH, CPMIO and CPMIO2

FILE keeps its indirect open/create and SHARE callbacks resident. ISEARCH owns the local search bodies and calls the resident multiplex adapter for redirector searches. SEARCH remains a separate module.

CPMIO and CPMIO2 keep editor state below A20. OEM function-key dispatch jumps within the movable editor frame. The resident Ctrl-C handler reaches BUFOUT and CRLF through gateways. INT 2Fh/1205h accepts an application stack and uses the DOS character-output dispatcher to write to standard output. The regression checks the emitted character and return. Each editor boot verifies its placement before testing Ctrl-C and prompt recovery.

## ABORT, SEARCH, RENAME, OPEN and FAT

ABORT keeps the redirector and SHARE termination callbacks resident. SEARCH owns the FCB and handle find services. RENAME calls ISEARCH directly to resume a wildcard rename. OPEN keeps network interrupt arguments on the resident stack and uses DS for callbacks from the INT 2Fh SFT interfaces, where SS can belong to the caller. FAT calls BUF directly and routes device I/O and critical errors through resident entries.

## Directory, pathname and FCB services

DIR, DIR2 and DIRCALL share near calls for directory traversal. DIR2 enters FASTOPEN through resident callbacks. INT 2Fh/1223h receives DOSGROUP in DS and ES on the caller’s stack. FCB keeps its character tables resident and accepts the caller’s stack for multiplex uppercase. MACRO2 calls the linked path and FCB routines. FCBIO and FCBIO2 select record reads, writes, opens and creates with near calls. SHARE callbacks remain resident.

## DEV

DEV keeps request construction (`SETREAD` and `SETWRITE`), character I/O, device open/close and secondary-cache handling in DOSCODE. Resident callers enter through the four gateways in `DevEntries`. `CallDeviceDriver` calls strategy and interrupt from resident code with DS:SI pointing to the device header and ES:BX to the request packet. INT 2Fh/120Ch and process initialization supply DOSGROUP in DS for device open on a caller-owned stack.

The placement probe opens a mock character device on the application stack and checks its strategy and interrupt entries. All six placement scenarios and both EMS tests passed. Full regression passed all 34 jobs.

## PATH

The four INT 21h directory services (39h, 3Ah, 3Bh and 47h) enter through `PathEntries`. MKDIR and RMDIR share pathname validation and then call their DIRCALL routines directly. RENAME calls PATH’s length check directly. Directory strings, CDS records and the caller’s get-directory buffer stay below A20 or in caller-owned memory.

The four public gateways occupy 52 B in resident CODE. Six former internal gateways in DIRCALL, DIR2 and MACRO2 lost their last callers. In a PCE boot with `DOS=HIGH,UMB` and PCEHIMEM, the largest executable block increased from 621,392 to 621,760 B (+368 B).

## Linked modules and dependencies

The module name is the object filename in the LINK response file. Each row lists the INCLUDE directives in the top-level assembly source and the other objects that supply its external code or data references in this build. Conditional INCLUDE directives appear even when disabled. The object dependencies come from MASM fixup records resolved against the defining objects' public symbols. A reference can be a call, pointer, dispatch-table entry or shared variable. Runtime calls through interrupt vectors and installed drivers require a separate interface review.

### MSDOS.SYS

[msdos.lnk](dos/msdos.lnk) lists 54 objects. Five are built in `common/`: `const2`, `msdata`, `msdosme`, `mstable` and `nibdos`. The others are built in `kernel/dos/`. Names in the dependency column refer to objects in this same image.

**PROC example.** `proc.asm` directly includes `dosseg.asm`, `dossym.inc`, `devsym.inc` and `exec.asm`. In turn, `exec.asm` includes `ea.inc` and `version.inc`. `dosseg.asm` declares the shared segments and DOSGROUP. `exec.asm` emits code and data into those segments as part of PROC. Both are assembly-time dependencies. At link time, for example, PROC's `DosCallbackPtr` reference resolves to MISC and its near call to `AllocateBlock` resolves to ALLOC.

Estimates use the current MASM object segment lengths and public-symbol offsets in `msdos.map`. “Up to” gives the module’s resident CODE size before allowing for gateways and callbacks. A named subset counts only those routine bodies. The net conventional-memory gain requires a before/after boot with the same configuration. For scale, TIME keeps 65 B resident for five gateways. The current build has 25,377 B in DOSCODE.

Of the two modules with an existing resident or partial review, MISC has another 159 B in `$SETDPB` alone, excluding gateways. NIBDOS has 0 B to move under this model.

| Module (.obj) | Direct source includes | Direct links to other modules | HMA review |
|---|---|---|---|
| ABORT | dosseg.asm, dossym.inc, devsym.inc | CONST2, HANDLE, MISC, NIBDOS, UTIL | DOSCODE, Whole Module Relocatable |
| ALLOC | dosseg.asm, dossym.inc, devsym.inc | CONST2, CRIT, MISC, MSCODE, MSDISP, NIBDOS | DOSCODE, Whole Module Relocatable |
| BUF | dosseg.asm, dossym.inc, devsym.inc, version.inc | CONST2, CRIT, DISK, DISK2, MISC, MSDATA, MSDISP, MSTABLE, NIBDOS | DOSCODE, Whole Module Relocatable. EMS interrupt adapter and cache data stay resident. |
| CLOSE | dosseg.asm, dossym.inc, devsym.inc, bugtyp.asm | BUF, CONST2, CRIT, DELETE, DEV, DIR, DIR2, FAT, MISC, MISC2, MSDATA, MSTABLE, NIBDOS, SHARE, TIME | DOSCODE, Whole Module Relocatable. Redirector and SHARE callbacks use resident adapters. |
| CONST2 | dossym.inc, dosseg.asm, devsym.inc | CRIT, MSDATA | No movable code. 0 B. Resident constants and DOS data. |
| CPMIO | dosseg.asm, dossym.inc, devsym.inc, doscntry.inc, kstrin.asm, editsw.inc, strin.asm | CONST2, CPMIO2, DEV, DISK, MISC, MSCTRLC, MSDATA, MSDOSME, MSTABLE, NIBDOS, TIME | DOSCODE, Whole Module Relocatable |
| CPMIO2 | dosseg.asm, dossym.inc, devsym.inc | CONST2, CPMIO, DEV, DISK, MISC, MSCTRLC, MSDISP | DOSCODE, Whole Module Relocatable |
| CREATE | dosseg.asm, dossym.inc, devsym.inc, version.inc | CONST2, CRIT, DELETE, FAT, IOCTL, MISC, MKNODE, MSDATA, MSTABLE, OPEN | DOSCODE, Whole Module Relocatable. |
| CRIT | dosseg.asm, dossym.inc, bugtyp.asm | — | No movable code. 0 B. SHARE patches the first instruction of each of the four resident critical-section hooks (32 B total). |
| DELETE | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, fastseek.inc, fastxxxx.inc | BUF, CONST2, CREATE, CRIT, DIR, DIR2, FAT, MACRO2, MISC2, MKNODE, MSDATA, MSTABLE, NIBDOS, ROM, SEARCH, SHARE | 421 B of delete and rename-access logic before `FastOpen_Delete` (613 B in CODE). Keep SHARE, redirector and FASTOPEN/FASTSEEK calls behind resident entries. |
| DEV | dosseg.asm, dossym.inc, devsym.inc, version.inc | CONST2, CRIT, DISK, IOCTL, MISC, MSCTRLC, MSDATA, MSTABLE, NIBDOS | DOSCODE, Whole Module Relocatable. Driver callbacks remain resident. |
| DINFO | dosseg.asm, dossym.inc, devsym.inc, bugtyp.asm | CONST2, CRIT, FAT, MISC, MISC2, MSDATA | DOSCODE, Whole Module Relocatable. |
| DIR | dosseg.asm, fastopen.inc, dossym.inc | CONST2, DIR2, DISK, FAT, MISC, MSDATA, MSTABLE, ROM | DOSCODE, Whole Module Relocatable |
| DIR2 | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc | BUF, CONST2, CRIT, DIR, DIRCALL, DISK, FAT, FCB, MACRO2, MISC, MISC2, MSDATA, MSTABLE, NIBDOS, TIME | DOSCODE, Whole Module Relocatable |
| DIRCALL | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, fastxxxx.inc | BUF, CONST2, CREATE, CRIT, DELETE, DIR, DIR2, MISC, MISC2, MKNODE, MSDATA, MSTABLE, ROM | DOSCODE, Whole Module Relocatable |
| DISK | dosseg.asm, fastseek.inc, fastxxxx.inc, dossym.inc, devsym.inc, version.inc | BUF, CLOSE, CONST2, CPMIO, CPMIO2, CRIT, DEV, DISK2, DISK3, FAT, LOCK, MISC, MISC2, MSCTRLC, MSDATA, MSDISP, MSTABLE, NIBDOS, ROM, UTIL | DOSCODE, Whole Module Relocatable |
| DISK2 | dosseg.asm, dossym.inc, devsym.inc, version.inc | BUF, CONST2, DEV, DISK, DISK3, FAT, LOCK, MISC, MSCTRLC, MSDATA, MSDISP, MSTABLE, NIBDOS, ROM | DOSCODE, Whole Module Relocatable |
| DISK3 | dosseg.asm, dossym.inc, devsym.inc, version.inc | BUF, CONST2, DELETE, DEV, DISK, DISK2, MISC, MSCTRLC, MSDATA, MSDISP, MSTABLE, NIBDOS, OPEN, ROM | DOSCODE, Whole Module Relocatable |
| DUP | dosseg.asm, dossym.inc, devsym.inc | DEV, MISC, MISC2, MSDATA | DOSCODE, Whole Module Relocatable |
| EXTATTR | dosseg.asm, dossym.inc, devsym.inc, ea.inc | MISC, MSDATA, MSDISP, MSTABLE | DOSCODE, Whole Module Relocatable |
| FAT | dosseg.asm, dossym.inc, devsym.inc | BUF, CONST2, DEV, MISC, MSCODE, MSCTRLC, MSDATA, MSTABLE, NIBDOS | DOSCODE, Whole Module Relocatable |
| FCB | dosseg.asm, dossym.inc, devsym.inc, doscntry.inc | CONST2, MACRO, MISC, MSDATA, MSDOSME | DOSCODE, Whole Module Relocatable |
| FCBIO | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, bugtyp.asm | CLOSE, CONST2, DELETE, DIR2, FCBIO2, FINFO, LOCK, MACRO, MACRO2, MISC, MISC2, MSCODE, MSCTRLC, MSDATA, NIBDOS, RENAME | DOSCODE, Whole Module Relocatable |
| FCBIO2 | dosseg.asm, dossym.inc, devsym.inc, version.inc, bugtyp.asm | BUF, CONST2, CREATE, DISK, FCBIO, LOCK, MACRO, MACRO2, MISC, MISC2, MSCODE, MSDATA, MSDISP, NIBDOS, OPEN, SHARE, TIME | DOSCODE, Whole Module Relocatable |
| FILE | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, ea.inc, version.inc, bugtyp.asm | CONST2, CREATE, CRIT, DELETE, FCB, FINFO, HANDLE, MACRO, MACRO2, MISC, MISC2, MSCODE, MSDATA, MSDISP, MSTABLE, NIBDOS, OPEN, RENAME, TIME, UTIL | DOSCODE, Whole Module Relocatable |
| FINFO | dosseg.asm, dossym.inc, devsym.inc, fastxxxx.inc, fastopen.inc | BUF, CONST2, CRIT, DELETE, DIR2, MISC, MISC2, MSDATA, MSTABLE | DOSCODE, Whole Module Relocatable |
| GETSET | dosseg.asm, dossym.inc, devsym.inc, doscntry.inc | CONST2, DINFO, FCB, MACRO, MSCODE, MSDISP, MSDOSME, MSTABLE, NIBDOS | DOSCODE, Whole Module Relocatable. NLS driver calls use resident adapters. |
| HANDLE | dosseg.asm, dossym.inc, devsym.inc, ea.inc, version.inc, bugtyp.asm | ALLOC, BUF, CLOSE, CONST2, CRIT, DISK, DUP, EXTATTR, MSCODE, MSDATA, MSDISP, MSTABLE, NIBDOS, UTIL | Up to 796 B. Handle read/write, seek, timestamps, close and duplication. Budget resident entries and adapters for SHARE and network calls. |
| IOCTL | dosseg.asm, dossym.inc, devsym.inc, ioctl.inc, ifssym.inc | CONST2, DEV, DISK, MACRO, MSCODE, MSCTRLC, MSDATA, MSDISP, NIBDOS, UTIL | Up to 864 B. Device-control dispatch and request handling. Driver entry, redirector calls and request packets need resident access. |
| ISEARCH | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, fastxxxx.inc | CONST2, CRIT, DIR, DIR2, MACRO, MISC, MSCODE, MSDATA, MSTABLE | DOSCODE, Whole Module Relocatable |
| LOCK | dosseg.asm, dossym.inc, devsym.inc, lock.inc | CONST2, MISC2, MSCODE, MSCTRLC, MSDATA, NIBDOS, UTIL | Up to 179 B. Lock request and retry/error logic. Keep the lock buffer, SHARE calls and network calls resident. |
| MACRO | dosseg.asm, dossym.inc, devsym.inc | CONST2, MSCODE, MSDATA, MSDISP, NIBDOS | Up to 413 B. Drive mapping, CDS lookup and user-ID services. Keep the INT 2Fh calls resident. |
| MACRO2 | dosseg.asm, dossym.inc, devsym.inc | CONST2, CRIT, DIR2, FAT, FCB, MACRO, MISC, MISC2, MSCODE, MSDATA, NIBDOS, SEARCH | DOSCODE, Whole Module Relocatable |
| MISC | dosseg.asm, dossym.inc, devsym.inc, bugtyp.asm | ABORT, ALLOC, BUF, CLOSE, CONST2, CPMIO, CPMIO2, CREATE, CRIT, DEV, DINFO, DIR, DIR2, DIRCALL, DISK, DISK2, DISK3, DUP, EXTATTR, FAT, FCB, FCBIO, FCBIO2, FILE, FINFO, IOCTL, ISEARCH, MACRO, MACRO2, MKNODE, MSCODE, MSDATA, MSDISP, MSTABLE, NIBDOS, OPEN, PATH, PROC, RENAME, ROM, SEARCH, UTIL | Partially relocatable. Owns the module entry list, resident dispatch stub, near-placement callback and DOSCODE far-return stub. FCBLOAD handles A20 and far gateway frames. |
| MISC2 | dosseg.asm, dossym.inc, fastseek.inc, fastxxxx.inc, bugtyp.asm | CONST2, FCB, FILE, HANDLE, IOCTL, MSDATA, MSTABLE, NIBDOS | 121 B in the string/exchange helpers and network predicates (392 B in CODE). Idle, indirect dispatch and NLS callbacks need separate review. |
| MKNODE | dosseg.asm, fastopen.inc, dossym.inc, devsym.inc | BUF, CONST2, CRIT, DELETE, DEV, DIR, DIR2, DISK, FAT, MISC, MSDATA, MSTABLE, ROM, SHARE, TIME | DOSCODE, Whole Module Relocatable |
| MSCODE | mssw.asm, ms_code.asm | BUF, CONST2, CRIT, DELETE, DISK2, MACRO, MISC, MISC2, MSDATA, MSDISP, MSTABLE | 248 B in `GETBP`, the two extended-error lookups and `RW32_CONVERT` (659 B in CODE). Retain interrupt entry, stack switching and return paths. |
| MSCTRLC | mssw.asm, ctrlc.asm | ABORT, ALLOC, BUF, CONST2, CPMIO, CPMIO2, CRIT, DEV, DISK, GETSET, MKNODE, MSCODE, MSDATA, MSDISP, MSDOSME, MSTABLE, NIBDOS, PROC | 34 B in `SET_I24_EXTENDED_ERROR` (1,051 B in CODE). Defer the INT 23h/24h, abort and parent-stack paths. Review with MSCODE’s error lookup. |
| MSDATA | mssw.asm, dosseg.asm, dosmac.inc, sf.inc, dirent.inc, curdir.inc, dpb.inc, buffer.inc, arena.inc, vector.inc, devsym.inc, pdb.inc, find.inc, mi.inc, ms_data.asm, msinit.asm | CONST2, DEV, MISC, MSCODE, MSCTRLC, MSDISP, MSDOSME, MSTABLE, NIBDOS, PROC | No persistent movable code. 0 B. DOS data stays resident. The initialization code in LAST is reclaimed at boot. |
| MSDISP | mssw.asm, disp.asm | CONST2, CRIT, MSCTRLC, MSDATA, MSTABLE, NIBDOS | 0 B budgeted from 575 B in CODE. Keep the dispatcher, interrupt returns, user-stack switching and EMS save/restore resident in this pass. |
| MSDOSME | mssw.asm, dosseg.asm, dosmes.asm | CPMIO | 0 B budgeted. The OEM key dispatcher already occupies 36 B in DOSCODE. Keep the country far callback and BIOS cursor helper resident (65 B in CODE). |
| MSTABLE | mssw.asm, ms_table.asm | ALLOC, BUF, CLOSE, CPMIO, CPMIO2, DIR2, FCB, FCBIO, FCBIO2, FILE, GETSET, HANDLE, IOCTL, LOCK, MACRO, MACRO2, MISC, MISC2, MSCODE, MSCTRLC, MSDISP, MSDOSME, NIBDOS, OPEN, PARSE, PATH, PROC, SEARCH, SHARE, SRVCALL, TIME, UTIL | No movable code. 0 B. The 1,270 B in TABLE hold dispatch and lookup data. |
| NIBDOS | mssw.asm, msconst.asm | CONST2, MSCODE, MSDATA, MSDISP | Resident boot jump to DOSINIT and fixed DOSGROUP data. |
| OPEN | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, fastxxxx.inc, ifssym.inc | CONST2, CRIT, DELETE, DEV, DIR2, MISC, MISC2, MKNODE, MSDATA, MSTABLE, NIBDOS, SHARE | DOSCODE, Whole Module Relocatable |
| PARSE | dosseg.asm, dossym.inc, devsym.inc | FCB, MSDISP | DOSCODE, Whole Module Relocatable. INT 21h/29h calls FCB directly and returns SI through the saved caller frame. |
| PATH | dosseg.asm, dossym.inc, devsym.inc | CONST2, CRIT, DIR2, DIRCALL, MACRO, MACRO2, MISC, MISC2, MSCODE, MSDATA, MSDISP | DOSCODE, Whole Module Relocatable. Four resident INT 21h gateways. |
| PROC | dosseg.asm, dossym.inc, devsym.inc, exec.asm | ALLOC, CONST2, CRIT, FILE, HANDLE, IOCTL, MACRO, MISC, MISC2, MSCODE, MSCTRLC, MSDATA, MSDISP, MSTABLE, NIBDOS, UTIL | DOSCODE, Whole Module Relocatable |
| RENAME | dosseg.asm, dossym.inc, devsym.inc | BUF, CONST2, CRIT, DELETE, DIR, DIR2, ISEARCH, MISC, MISC2, MKNODE, MSDATA, PATH, SHARE | DOSCODE, Whole Module Relocatable |
| ROM | dosseg.asm, fastseek.inc, fastxxxx.inc, version.inc, dossym.inc, devsym.inc, ea.inc | BUF, CONST2, DELETE, FAT, MISC, MSDATA, MSTABLE | DOSCODE, Whole Module Relocatable |
| SEARCH | dosseg.asm, dossym.inc, devsym.inc, fastopen.inc, fastxxxx.inc | CONST2, ISEARCH, MACRO2, MISC, MSCODE, MSDATA | DOSCODE, Whole Module Relocatable |
| SHARE | dosseg.asm, dossym.inc, devsym.inc | CONST2, MISC2, MSCTRLC, MSDATA, NIBDOS | 72 B in sharing-violation and retry logic (82 B in CODE). Keep the two installed-sharer call stubs resident. This is the kernel object, separate from SHARE.EXE. |
| SRVCALL | dosseg.asm, dossym.inc, devsym.inc, dpl.asm | CLOSE, CONST2, CRIT, IOCTL, MISC2, MSCODE, MSDATA, MSDISP, NIBDOS, UTIL | Up to 305 B. The server service dispatches through a resident table. SHARE calls and the stack-discarding redispatch path reduce the available saving. |
| TIME | dosseg.asm, dossym.inc, devsym.inc | CONST2, DEV, MSDATA, MSDISP, MSTABLE, NIBDOS | DOSCODE, Whole Module Relocatable. DATE16 packs FAT timestamps on the DOS stack. Clock-driver requests call DEV directly in DOSCODE. |
| UTIL | dosseg.asm, dossym.inc, devsym.inc, bugtyp.asm | CONST2, NIBDOS | Up to 190 B. Five handle and SFT helpers. DOS initialization can call them before placement, with a non-DOS stack. |



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
2. Exercise the same service on the same binary in HMA, UMB and conventional memory, including both conventional layouts where applicable. Verify the result, carry/error behavior and any affected external callback or nonlocal return.
3. Review the source and map, then run regression. Record the verified module names and test result when advancing the progress line. Preserve independent functional fixes throughout.
