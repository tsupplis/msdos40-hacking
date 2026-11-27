# HIMEM.SYS

The native driver provides XMS discovery, A20 control, HMA ownership and
extended-memory block allocation on AT-compatible systems. The distribution and full floppies carry HIMEM.SYS. SELECT copies it
to the chosen DOS directory. With the default directory, enable it in
CONFIG.SYS to load the relocatable DOS code into the HMA.

```ini
DOS=HIGH
DEVICE=C:\DOS\HIMEM.SYS
```

| Interface | Current behavior |
| --- | --- |
| DOS device initialization | Requires a 286 or later. Declines to install over an existing XMS provider. |
| INT 2Fh, AX=4300h / 4310h | Reports installation and returns the far XMS entry point. Other requests chain to the previous interrupt handler. |
| XMS 00h | Returns interface version 0200h, driver revision 0001h and DX=1 if an HMA exists. Before the first grant, this is a BIOS size estimate. |
| XMS 01h / 02h | Request or release the whole HMA. Errors include 81h for a legacy conflict, 82h for A20 failure, 90h for insufficient memory, 91h for an existing owner and 93h for release without an owner. |
| XMS 03h / 04h | Acquire or release the global A20 hold. Repeated enables count once. Global disable returns BL=94h if the gate remains on. |
| XMS 05h / 06h | Acquire or release a local A20 hold. Holds nest. An unmatched release, counter overflow or controller failure returns BL=82h. |
| XMS 07h | Test physical address wrap and return AX=1 for on or AX=0 for off, with BL=0. |
| XMS 08h | Returns the largest new allocation in AX and total free KiB in DX. When all handles are in use, AX is zero. |
| XMS 09h / 0Ah | Allocate or free a block in KiB. A zero-length block uses one handle. |
| XMS 0Bh | Move an even number of bytes between two real-mode or XMS addresses. Either operand may be an unlocked handle. Overlap works in both directions. |
| XMS 0Ch / 0Dh | Lock or unlock a block. Lock returns its physical byte address in DX:BX. |
| XMS 0Eh / 0Fh | Read length, lock count and remaining handle count, or resize an unlocked block. |
| INT 2Fh, AX=4309h | Returns the descriptor table used by `MEM` to count allocated KiB. |
| Other XMS functions | Return AX=0, BL=80h (unimplemented). |

The assembled image is 2,760 bytes. DOS retains 2,576 bytes (161 paragraphs)
and discards the initialization code and diagnostics.

A20 control uses the IBM AT-compatible 8042 keyboard controller. The first
hold records whether HIMEM enabled the gate. The last release restores that
state. A local enable returns with A20 on so its caller can access the HMA.
Interrupt clients must pair their own enable and disable before returning.
Each hardware request has a bounded wait and checks physical address
wrap before committing ownership. Once the output-port command is issued,
HIMEM gives a slow controller a second wait for its data byte. A controller
that stays busy returns error 82h. Machines requiring a different gate
mechanism will need a separate hardware handler.

The first non-version XMS call hooks INT 15h to preserve A20 across BIOS
block moves. BIOS size queries continue to chain until the first successful
pool reservation, then return zero. HIMEM checks the VDISK and RAMDRIVE
signatures when reserving the pool and again at the first HMA grant if the
pool was reserved earlier. A late conflict blocks new allocations, locks,
A20 acquisitions and A20 queries. Existing clients can still release A20
holds, inspect their handles, unlock them and free them.

On a 286 the physical address ceiling is 16 MiB. With at least 64 KiB
of extended RAM, the HMA reservation occupies the first 64 KiB above
1 MiB and the block pool starts at physical address 110000h. Smaller
ranges can supply blocks from 100000h and cannot supply an HMA.

The driver has 16 stable handles. Allocation takes the first contiguous
gap large enough for the request. A locked block keeps its address until
its final unlock. Resize can shrink a block, grow it into the adjacent
gap or give an empty handle its first extent. Growth that would require
moving live data returns A0h and preserves the existing block.

Function 0Bh validates both ranges before writing. It pins the operands
for the duration of the call and copies up to 4 KiB per BIOS transfer.
Handle zero selects a segment:offset address. A firmware error stops the
move and releases both pins. Earlier chunks may already have been copied.

## Integration

* `kernel/bios/fcbload.asm` already discovers XMS, requests the HMA with
  DX=FFFFh and enables A20 locally. It releases the HMA if the enable fails.
  Its conventional-memory gateway enables A20 on entry to high code and
  releases its hold on return.
* `kernel/umbs/umbs.asm` can provide UMBs independently. Load HIMEM first
  and UMBS second to expose both through the same XMS entry. UMBS alone
  advertises a provider, so reversing that order leaves UMBS in charge.
  UMBS handles XMS 10h by giving DOS whole mapped ranges. DOS manages
  allocations within them. Direct XMS 11h release is unsupported.
* HIMEM initialization messages come from `messages/usa-ms.msg`.
  `NOSRVBLD` generates the assembler include from `himem.skl`, as for
  XMAEM. Only the discardable initialization module includes the messages.
* PCEHIMEM delegates XMS services to the emulator. Its guest shim and host
  implementation carry GPLv2 notices. It serves as a behavioral reference.
  The native driver is independently written under the repository's MIT
  license.

The full regression (`test/run_tests --all`) includes `test/check_himem`.
Run it directly after building the driver and full floppy for a focused check.
The suite also runs `test/check_install` to install each release floppy with
SELECT and verify HELP and HMA placement after booting the hard disk.
It boots scratch images on PCE (8086) and QEMU (486), checks discovery,
compares the PCEHIMEM version and HMA response, and exercises both UMBS
load orders. The AT tests verify physical wrap independently, exercise
nested and mixed holds, and simulate a busy controller before and after
the gate data write. HMA tests cover exclusive ownership,
legacy signatures, BIOS block-move state preservation, a 1 MiB fallback
boot and actual kernel placement. With 4 MiB on the QEMU 486, the test
COM received 24,256 more conventional bytes with `DOS=HIGH` than with
the same driver loaded low and DOS in conventional memory.

The one-off 80386 regression passed all 23 AT cases on DOSBox-X 2026.10.01
with `core=normal`, `cputype=386` and the full release floppy. A guest
probe toggled EFLAGS.AC on the 486 control and confirmed it stayed clear
on the 386. The kernel layout probe also confirmed placement in the HMA.
The tests reported results through port E9h. For the busy-controller case,
a guest trace supplied 65,536 busy status reads. Hardware testing is deferred.

Block tests cover fragmentation, exhaustion, zero-size handles, nested
locks, failed growth and re-entry during the BIOS reservation. A BIOS
block move writes and reads back a word at the returned physical address.
The function 0Bh probe checks transfers across 64 KiB, overlapping ranges,
nested calls, and cleanup after BIOS failures with DOS low, DOS high and
UMBS chaining. The 24-bit ceiling test copies the last addressable word.

## Phase 8: extended-memory driver compatibility

Loading HIMEM and claiming the XMS pool are separate events. Until the first
reservation, a driver can take memory from the top of the BIOS range and
reduce the size reported by INT 15h/88h. HIMEM then sees the reduced range.
After reservation, HIMEM reports zero through that BIOS call.

| Driver and mode | Observation on the QEMU 486 with 8 MiB |
| --- | --- |
| RAMDRIVE /E and VDISK /E | Load an XMS manager first. Each instance allocates its own block. Conventional mode needs no manager. RAMDRIVE /A uses EMS. VDISK /X requires a DOS-reserved EMS page. |
| SMARTDRV | An IDE cache uses XMS by default or EMS with /A. The track buffer stays in conventional memory and fits within one physical 64 KiB DMA page. |
| EMM386 256 | With HIMEM first, EMM386 installed, DOS loaded high and XMS moves passed. With EMM386 first, HIMEM's processor test rejected the 486. With the pool already claimed, EMM386 reported insufficient memory. |
| XMAEM and XMA2EMS | XMAEM sizes its backing memory through INT 15h/88h. XMA2EMS has an XMA adapter path and can reduce the BIOS memory report. The test machine lacked a supported system unit and adapter, so neither installed. |

On the simulated 386, `EMM386.SYS 256 ON` allocated, mapped, wrote and
read back two distinct EMS pages, both alone and after HIMEM. Adding
`XMSHOLD.SYS` between the drivers claimed 8 KiB. XMS still reported
free memory, INT 15h/88h reported zero and EMM386 did not install.
The XMS-backed allocator in issue #22 must cover both the EMS pages and
the memory that EMM386 reserves for its own relocated code and tables.
