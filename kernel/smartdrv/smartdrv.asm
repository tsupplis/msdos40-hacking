	TITLE	EXTENDED/EXPANDED MEMORY DISK CACHE

PAGE	58,132

;
; DEVICE=SMARTDRV.SYS [kilobytes] [/A]
; Use XMS for a hard-disk cache, or select EMS with /A.
; XMS defaults to 256 KiB. EMS defaults to available pages up to 8192 KiB.
; An explicit cache size is 128 to 8192 KiB.
;
; NOTE WARNING: ALL OF THIS CODE ASSUMES THAT ALL HARDFILES ARE 512 BYTES
;	PER SECTOR!!! All other hardfile parameters are read via INT 13, but
;	Bytes/sector MUST be IBM standard 512.
;
; MODIFICATION HISTORY
;
;	1.00	5/10/86 ARR Initial version based on RAMDrive 1.16.
;	1.01	5/20/86 ARR Slight re-organization of places where FLUSH_CACHE
;			    is called to discard a track to make sure
;			    TRACK_BUFFER is invalidated correctly.
;	1.10	5/26/86 ARR Added Timer Int to flush cache after passage
;			    of user setable time.
;	1.20	5/27/86 ARR Additions at request of Neilk. /t:nnnnn /d /wb:on
;			    /wb:off /wt:on /wt:off can be on device = line.
;			    Lock cache function added.
;	1.21	5/29/86 ARR Lock code made more intelligent.
;	1.22	5/30/86 ARR /r reboot flush code added
;	1.23	6/03/86 ARR Cache statistics added
;	1.24	6/05/86 ARR Added /a "all cache" code
;	1.25	6/10/86 ARR Added total used, total locked to status
;	1.26	6/12/86 ARR /wb changed to /wc to align with docs. Discard
;			    of track when write to locked track changed to
;			    unlock. Discard of track when write with /wc:off
;			    changed to immediate write through.
;	1.27	6/17/86 ARR Bug regarding the INT 13 error which is not
;			    an error (error 11H, ECC error corrected).
;			    changed error handling logic to handle this
;			    correctly (ignore it).
;	1.28	7/31/86 ARR Default seg reg access byte changed from
;			    82H to 92H. This was needed for 80386 functionality.
;			    Change to LOADALL.ASM, also RAMDrive problem.
;	1.30	8/04/86 ARR Default cache size uped to 256K
;			    Min cache size uped to 128K
;	1.31	8/07/86 ARR Moved SMSW SIDT SGDT set into BLKMOV code for
;			    problem with CEMM
;	1.32	8/27/86 ARR Added code to A20 routine to provide approp
;			    settle time for A20 switch to occur. This will
;			    help us on Compaq machines and faster ATs and
;			    80386 machines. Thanks to CC of Compaq for fix.
;	1.33	9/22/86 ARR Added more info to startup header, in particular,
;			    tells you whether /A or /E cache.
;
;	SMARTDRV
;	------
;
;	1.00	5/13/87 SUNILP, GREGH, DAVIDW:
;			    Modified INT13 to take care of multi track caching
;			    Reduced functionality
;			    Added two new IOCTL calls to increase/decrease
;			    cache size, dynamically
;
;
;;		7/24/87 WSH Added 6300 PLUS support.  This code is marked by
;;			    the use of double semi-colons to make it easy to
;;			    find.
;
;		8/31/87 SUNILP
;			    New extended memory allocation scheme. 386 support.
;			    Support for new ps/2 systems. better 286 loadall
;			    transfer. more complete expanded memory access.
;			    several bug fixes.
;
;	1.01	9/17/87 SUNILP
;			    Removed check that was limiting tracks to 32k bytes
;			    Tracks can be upto 64k bytes now
;
;	1.02	10/22/87 SUNILP
;			    Reduced statically allocated track buffer size to
;			    minimum required
;
;	1.03	10/29/87 SUNILP
;			    Changed name reported in messages to SMARTDrive
;
;		 1/08/88 GREGH
;			    Added support for OMTI controller.	This code
;			    is ifdef'd in with the OMTI keyword.
;
;	1.04	3/02/88  SUNILP
;			    fix for recognition of 20MHz model 80.
;			    fix for READ DASD int 13 dispatch.
;
;	1.05	5/13/88  SUNILP
;			    fixed version checking to include dos 4.00
;
;	2.10	6/13/88  CHIPA	Merged in these changes for HP Vectra
;	       11/20/87  RCP
;			    Fixed a20 enabling/disabling problems on
;			    Vectra machines.
;               8/24/88  MRW Merged changes from Windows tree into DOS tree
;

BREAK	MACRO	subtitle
	SUBTTL	subtitle
	PAGE
ENDM

.286p				; Use some 286 instructions in /E code

DEBUG	EQU	0
WINDOWS_SWITCHES EQU	1	; 1 = uses switches for windows, 0 = all switches
;OMTI	 EQU	 1		 ; Used for code specific to the OMTI Controller

MAX_HARD_FILES	EQU	16	; Max number of hardfiles our data structures support

MIN_CACHE_SIZE_K EQU	128	; Minimum size for cache in K (multiple of 16)

IF1
    IFDEF OMTI
	%out OMTI Controller release
    ENDIF
ENDIF

IF1
    IF DEBUG
	%out DEBUG VERSION!!!!!!
    ENDIF
ENDIF

.xlist
	include devsym.asm
	include syscall.asm
	include mi.asm
.list

; Cache storage is owned by XMS, or by the EMS manager when /A is selected.
	include above.asm

	include ab_macro.asm

BREAK	<I/O Packet offset declarations>

;
; Define I/O packet offsets for useful values.
;
; SEE ALSO
;	MS-DOS Technical Reference manual section on Installable Device Drivers
;

; READ/WRITE PACKET OFFSETS
RW_COUNT	EQU	WORD PTR (SIZE SRHEAD) + 5
RW_TRANS	EQU	DWORD PTR (SIZE SRHEAD) + 1
RW_START	EQU	WORD PTR (SIZE SRHEAD) + 7

; MEDIA CHECK PACKET OFFSETS
MCH_RETVAL	EQU	BYTE PTR (SIZE SRHEAD) + 1
MCH_MEDIA	EQU	BYTE PTR (SIZE SRHEAD) + 0

; BUILD BPB PACKET OFFSETS
BPB_BUFFER	EQU	DWORD PTR (SIZE SRHEAD) + 1
BPB_MEDIA	EQU	BYTE PTR (SIZE SRHEAD) + 0
BPB_BPB 	EQU	DWORD PTR (SIZE SRHEAD) + 5

; INIT PACKET OFFSETS
INIT_NUM	EQU	BYTE PTR (SIZE SRHEAD) + 0
INIT_BREAK	EQU	DWORD PTR (SIZE SRHEAD) + 1
INIT_BPB	EQU	DWORD PTR (SIZE SRHEAD) + 5
INIT_DOSDEV	EQU	BYTE PTR (SIZE SRHEAD) + 9

BREAK	<Cache control structure>

;
; The cache control structure is the "management" data associated
;   with all of the data in the cache. The cache structures are
;   part of the device driver and they contain pointers to the
;   actual cache memory where the data is. This is more efficient
;   than putting the structures with the data as there is more overhead
;   to access stuff in the data area. The structures form a double
;   linked list in LRU order. The head points to the MRU element. The
;   tail points to the LRU element. Scans start at MRU as this is the
;   highest probability of a hit. Selection for bump is at LRU. All of
;   the links are short pointers. This limits the size of the cache
;   as the cache structures together with the device code must all
;   fit in 64K. This is more efficient than FAR links. Each cache element
;   contains one complete track of one of the INT 13 hard files (INT 13
;   floppy drives are NOT cached). Cache "read ahead" is obtained by
;   reading complete tracks into the cache even though the INT 13 user
;   may have only requested one sector. Write behind is accomplished
;   (if enabled) by holding tracks for a while allowing user writes
;   on that track to "accumulate".
;
; The original INT 13 caching algorithm (Aaronr) is sumarized as follows:
;
;	If user read is in cache
;	    Perform user read from cache
;	Else
;	    If read is full track
;		Perform write through (if enabled)
;		Pass Read to old INT 13 handler (no cache operation)
;	    Else
;		Read track into cache using old INT 13 handler
;		Perform user read out of cache
;
;	If user write is in cache
;	    If write buffering is enabled
;		Perform user write into cache
;	    Else
;		Discard cache for this track
;		Pass write through to old INT 13 handler
;	Else
;	    If write is full track
;		Perform write through (if enabled)
;		Pass Write to old INT 13 handler (no cache operation)
;	    Else
;		If write buffering is enabled
;		    Read track into cache using old INT 13 handler
;		    Perform user write into cache
;		Else
;		    Pass write through to old INT 13 handler
;
;	SMARTDRV     modifications:
;
;	1. Write through always.
;	2. Multi track I/O capability support.
;	3. Direct transfer between cache and user buffer address for
;	   full tracks.
;
;
;

CACHE_CONTROL	STRUC
FWD_LRU_LNK	DW	?	; Link to next CACHE_CONTROL, -1 if last
BACK_LRU_LNK	DW	?	; Link to previous CACHE_CONTROL, -1 if first
BASE_OFFSET	DD	?	; Offset releative to start of cache
				;  memory of start of this track buffer
TRACK_FLAGS	DW	?	; Flags
;
; NOTE: The next two bytes are refed as a word.
;	    MOV     DX,WORD PTR STRC.TRACK_DRIVE
;	    OR	    DH,80H
;	Puts the INT 13 drive in DL, and the head in DH which is correct
;	for an INT 13
;
TRACK_DRIVE	DB	?	; INT 13 drive with high bit = 0
TRACK_HEAD	DB	?	; INT 13 head
TRACK_CYLN	DW	?	; INT 13 cylinder
				;   High byte is low byte of cylinder #
				;   High two bits of Low byte are high
				;	 two bits of cylinder #. Other bits
				;	 are 0. This makes it easy to load the
				;	 CX register for an INT 13 for this
				;	 track:
				;		 MOV	CX,STRC.CACHE_CYLN
				;		 OR	CL,1
CACHE_CONTROL	ENDS

;
; TRACK_FLAGS bits
;
TRACK_FREE	EQU	0000000000000001B	; Track buffer is free
TRACK_DIRTY	EQU	0000000000000010B	; Track needs to be written
TRACK_LOCKED	EQU	0000000000000100B	; Track is locked

BREAK	<Device header>

INT13CODE SEGMENT
ASSUME	CS:INT13CODE,DS:NOTHING,ES:NOTHING,SS:NOTHING

	IF	DEBUG
	public	strategy,int13$in,cmderr,err$cnt,err$exit,devexit
	public	INT13$IOCTL_Read,INT13$Read_St,INT13$Write_St,INT13$IOCTL_Write
	public	int_1C_handler,int_13_handler,POP_NO_PROC,INVALIDATE_CACHE
	public	CACHE_READ,CACHE_WRITE,FLUSH_PASS,FLUSH_INVALID_PASS
	public	FLUSH_WHOLE_CACHE_SAV,FLUSH_WHOLE_CACHE,FLUSH_CACHE
	public	WRITE_FROM_CACHE
	public	Cache_hit
	public	blkmov,INT_9,INT_19,RESET_SYSTEM,DO_INIT,SETBPB
	public	PRINT,ITOA,INT13$INIT,DRIVEPARMS,GETNUM
	public	SET_RESET
	public	XMS_INIT,ABOVE_INIT
	public	process_read_partial,process_block_read,pr_acc_trks
	public	pr_acc_trks,pr_cur_trk,process_write_partial,process_block_write
	public	check_parameters,process_regions,bytes_in_trk,sect_in_trk
	public	not_in_mem,read_disk
	public		      not_in_memw,rd_partw,rd_part
	public	region
	public	SECTRKARRAY
	ENDIF

;**
;
;	INT13 DEVICE HEADER
;
;	COMMON TO TYPE 1, 2 drivers
;
;	SEE ALSO
;	  MS-DOS Technical Reference manual section on
;	  Installable Device Drivers
;

;; The internal name of the device driver has been changed from SMARTDRV
;; to SMARTAAR to avoid DOS name conflicts with files named SMARTDRV.*
;;
INT13DEV  LABEL   WORD
	DW	-1,-1
DEVATS	DW	DEVOPCL + CharDev + DevIOCtl
	DW	STRATEGY
	DW	INT13$IN
	DB	"SMARTAAR"			;Name of device


BREAK	<Command dispatch table>

;**
;
; This is the device driver command dispatch table.
;
; The first byte indicates the size of the table and therefore defines
; which device function codes are valid.
;
; The entries in the table are NEAR word addresses of the appropriate
; device routine. Thus the address of the routine to handle device function
; 3 is:
;	WORD at ((INT13TBL + 1) + (2 * 3))
;
;	COMMON TO TYPE 1, 2 drivers
;
;

INT13TBL  LABEL   WORD
	DB	15			; Max allowed command code
	DW	INT13$INIT		; Init
	DW	CMDERR			; Media check
	DW	CMDERR			; Build BPB
	DW	INT13$IOCTL_Read	; IOCTL input
	DW	CMDERR			; Read
	DW	CMDERR			; Non-des read no-wait
	DW	INT13$Read_St		; Read status
	DW	CMDERR			; Read flush
	DW	CMDERR			; Write
	DW	CMDERR			; Write with verify
	DW	INT13$Write_St		; Output status
	DW	CMDERR			; Output flush
	DW	INT13$IOCTL_Write	; IOCTL output
	DW	DEVEXIT 		; Open
	DW	DEVEXIT 		; Close
	DW	CMDERR			; Rem media?

BREAK	<Device Control data>

STATISTICS_SIZE EQU	40

DRIVER_SEL	DB	0	; 0 if /E (TYPE 1), 1 if /A (TYPE 2),

XMS_ENTRY       DD      0
XMS_HANDLE      DW      0
XMS_STACK_TOP   DW      0               ; private stack for INT 13h XMS calls
XMS_MOVING      DB      0
XMS_STACK_SIZE  EQU     512
DEV_SIZE	DW	256	; Size in K of the cache

SECTRACK	DW	?	; Sectors per track

current_dev_size dw	?	; Current size in K of cache

ifdef OMTI
sys_flg db 0
OMTI_EXT equ 00100000B
endif

; 0 if device is valid
; Non-0 if device install failed (device non-functional)
;
;   We need this state because there is no way to "un-install"
;     a character device as there is with block devices
;
NULDEV	DB	0

;
; 0 if caching is off
; Non-0 if caching is on
;
ENABLE_13 DB	1  ; 0 for debug

;
; 0 if no write through
; Non-0 if write through
;
WRITE_THROUGH DB 0

;
; 0 if no write buffering
; Non-0 if write buffering enabled
;
WRITE_BUFF DB	0

;
; 0 if cache is unlocked
; Non-0 if cache is locked
;
LOCK_CACHE DB	0

;
; 0 if full track I/O to tracks not in cache is not cached.
; Non-0 if ALL I/O is to be cached
;
ALL_CACHE DB 1

;
; 0 if reboot flush is disabled
; Non-0 if reboot flush is enabled
;
REBOOT_FLUSH DB 0

;
; An exclusion sem so that the INT 13 handler and the timer interact
;	without re-entrancy problems
;
INT_13_BUSY	DB	0		; Exclusion sem

	EVEN				; Force word data to word align
;
; Statistics counters
;
;  WARNING!!!! Do not disturb the order of these!!!! See IOCTL_READ code.
;
TOTAL_WRITES	DD	0
WRITE_HITS	DD	0
TOTAL_READS	DD	0
READ_HITS	DD	0
TTRACKS 	DW	?	; Total number of track buffers that fit
				;  in DEV_SIZE K (number of cache elements)
TOTAL_USED	DW	0
TOTAL_LOCKED	DW	0
TOTAL_DIRTY	DW	0

;
; Tick counters
;
TICK_SETTING	DW	1092		; Approx 1 minute
TICK_CNT	DW	1092

;
; Non-zero if there are dirty buffers in the cache
;
DIRTY_CACHE	DW	0		; 0 if no dirty elements in cache

BREAK	<Common Device code>

;	INT13 DEVICE ENTRY POINTS - STRATEGY, INT13$IN
;
;	This code is standard DOS device driver function dispatch
;	code. STRATEGY is the device driver strategy routine, INT13$IN
;	is the driver interrupt routine.
;
;	INT13$IN uses INT13TBL to dispatch to the appropriate handler
;	for each device function. It also does standard packet
;	unpacking.
;
;	SEE ALSO
;	  MS-DOS Technical Reference manual section on
;	  Installable Device Drivers
;

ASSUME	CS:INT13CODE,DS:NOTHING,ES:NOTHING,SS:NOTHING

PTRSAV	DD	0			; Storage location for packet addr

;**	STRATEGY - Device strategy routine
;
;	Standard DOS 2.X 3.X device driver strategy routine. All it does
;	is save the packet address in PTRSAV.
;
;	ENTRY	ES:BX -> Device packet
;	EXIT	NONE
;	USES	NONE
;
;	COMMON TO TYPE 1, 2 drivers
;
;

STRATP	PROC	FAR

STRATEGY:
	MOV	WORD PTR [PTRSAV],BX	; Save packet addr
	MOV	WORD PTR [PTRSAV+2],ES
	RET

STRATP	ENDP

;**	INT13$IN - Device interrupt routine
;
;	Standard DOS 2.X 3.X device driver interrupt routine.
;
;
;	ENTRY	PTRSAV has packet address saved by previous STRATEGY call.
;	EXIT	Dispatch to appropriate function handler
;			CX = Packet RW_COUNT
;			DX = Packet RW_START
;			ES:DI = Packet RW_TRANS
;			DS = INT13CODE
;			STACK has saved values of all regs but FLAGS
;		    All function handlers must return through one of
;			the standard exit points
;	USES	FLAGS
;
;	COMMON TO TYPE 1, 2 drivers
;
;

INT13$IN:
	PUSH	SI
	PUSH	AX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	BP
	PUSH	DS
	PUSH	ES
	PUSH	BX

	LDS	BX,[PTRSAV]	       ;GET POINTER TO I/O PACKET
    ;
    ; Set up registers for READ or WRITE since this is the most common case
    ;
	MOV	CX,DS:[BX.RW_COUNT]	;CX = COUNT
	MOV	DX,DS:[BX.RW_START]	;DX = START SECTOR
	MOV	AL,DS:[BX.REQFUNC]	; Command code
	MOV	AH,BYTE PTR [INT13TBL]	; Valid range
	CMP	AL,AH
	JA	CMDERR			; Out of range command code
	MOV	SI,OFFSET INT13TBL + 1	; Table of routines
	CBW				; Make command code a word
	ADD	SI,AX			; Add it twice since one word in
	ADD	SI,AX			;  table per command.

	LES	DI,DS:[BX.RW_TRANS]	; ES:DI transfer address

	PUSH	CS
	POP	DS

ASSUME	DS:INT13CODE

	JMP	WORD PTR [SI]		; GO DO COMMAND

;**	EXIT - ALL ROUTINES RETURN THROUGH ONE OF THESE PATHS
;
;	Exit code entry points:
;
;	SEE ALSO
;	  MS-DOS Technical Reference manual section on
;	  Installable Device Drivers
;
;	GENERAL ENTRY for all entry points
;		All packet values appropriate to the specific device function
;		filled in except for the status word in the static request
;		header.
;
;	CMDERR - Used when an invalid device command is detected
;
;		ENTRY Stack has frame set up by INT13$IN
;		EXIT  Standard Device driver with error 3
;		USES  FLAGS
;
;	ERR$CNT - Used when READ or WRITE wants to return with error code.
;		   The packet RW_COUNT field is zeroed
;
;		ENTRY AL is error code for low byte of packet status word
;		      Stack has frame set up by INT13$IN
;		EXIT  Standard Device driver with error AL
;		USES  FLAGS
;
;	ERR$EXIT - Used when a function other that READ or WRITE wants to
;			return an error
;
;		ENTRY AL is error code for low byte of packet status word
;		      Stack has frame set up by INT13$IN
;		EXIT  Standard Device driver with error AL
;		USES  FLAGS
;
;	DEVEXIT - Used when a function wants to return with no error
;
;		ENTRY AL is value for low byte of packet status word
;		       NOTE: Typically there is no meaningful value
;			in the AL register when EXITing through here.
;			This is OK as the low 8 bits of the status word
;			have no meaning unless an error occured.
;		      Stack has frame set up by INT13$IN
;		EXIT  Standard Device driver with no error
;		USES  FLAGS
;
;	ERR1 - Used when a function wants to return with a value
;			for the whole status word
;
;		ENTRY AX is value for packet status word
;		      Stack has frame set up by INT13$IN
;		EXIT  Standard Device driver with or without error
;		USES  FLAGS
;
;	COMMON TO TYPE 1, 2 drivers
;
;

ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING

CMDERR:
	MOV	AL,3			;UNKNOWN COMMAND ERROR
	JMP	SHORT ERR$EXIT

ERR$CNT:
	LDS	BX,[PTRSAV]
	MOV	[BX.RW_COUNT],0 	; NO sectors transferred
ERR$EXIT:				; Error in AL
	MOV	AH,(STERR + STDON) SHR 8  ;MARK ERROR RETURN
	JMP	SHORT ERR1

EXITP	PROC	FAR

DEVEXIT:
	MOV    AH,STDON SHR 8
ERR1:
	LDS	BX,[PTRSAV]
	MOV	[BX.REQSTAT],AX 	; Set return status

	POP	BX
	POP	ES
	POP	DS
	POP	BP
	POP	DI
	POP	DX
	POP	CX
	POP	AX
	POP	SI
	RET				;RESTORE REGS AND RETURN
EXITP	ENDP

;
; The following functions are not supported at this time.
;
INT13$Read_St:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
INT13$Write_St:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	JMP	CMDERR

BREAK	<IOCTL Read function (get device control parms)>

SET_ZRJ3:
	JMP	SET_ZR

INT13$IOCTL_Read:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	CLD
	CMP	CX,STATISTICS_SIZE	; Must have room to transfer data.
	JB	SET_ZRJ3		; Not enough room from user
	MOV	[TOTAL_USED],0
	MOV	[TOTAL_LOCKED],0
	MOV	[TOTAL_DIRTY],0
    ;
    ; Count all occupied, dirty and locked elements
    ;
	MOV	[INT_13_BUSY],1
	MOV	SI,[CACHE_HEAD]
	INC	SI
NEXTCC:
	DEC	SI
	TEST	[SI.TRACK_FLAGS],TRACK_FREE
	JNZ	SKIPCC
	INC	[TOTAL_USED]
	TEST	[SI.TRACK_FLAGS],TRACK_LOCKED
	JZ	TEST_DIRTY
	INC	[TOTAL_LOCKED]
TEST_DIRTY:
	TEST	[SI.TRACK_FLAGS],TRACK_DIRTY
	JZ	SKIPCC
	INC	[TOTAL_DIRTY]
SKIPCC:
	MOV	SI,[SI.FWD_LRU_LNK]
	INC	SI
	JNZ	NEXTCC
	MOV	[INT_13_BUSY],0
	MOV	AL,[WRITE_THROUGH]
	MOV	AH,[WRITE_BUFF]
	STOSW
	MOV	AL,[ENABLE_13]
	MOV	AH,[NULDEV]
	STOSW
	MOV	AX,[TICK_SETTING]
	STOSW
	MOV	AL,[LOCK_CACHE]
	MOV	AH,[REBOOT_FLUSH]
	STOSW
	MOV	AL,[ALL_CACHE]
	XOR	AH,AH			; Unused currently
	STOSW
	MOV	SI,OFFSET TOTAL_WRITES
	MOV	CX,12
	REP	MOVSW
;
; Transfer Above Board Information
;
	xor	dx,dx
	mov	es:[di][0],dx
	mov	es:[di][2],dx
	mov	es:[di][4],dx
	cmp	[driver_sel],dl		; is it expanded memory?
	jz	no_ems			; no, info already set
	mov	cx,16
	mov	ax,[current_dev_size]
	div	cx
	or	dx,dx
	jz	no_remain
	inc	ax
	xor	dx,dx
no_remain:
	stosw
	mov	ax,[dev_size]
	div	cx
	or	dx,dx
	jz	no_remaind
	inc	ax
no_remaind:
	stosw
	mov	ax,MIN_CACHE_SIZE_K / 16
	stosw
no_ems:
	LDS	BX,[PTRSAV]
ASSUME	DS:NOTHING
	MOV	[BX.RW_COUNT],STATISTICS_SIZE ; transfer amount
	JMP	DEVEXIT

BREAK	<IOCTL Write functions (set device control parms and do flushes)>

;
; Command table for IOCTL Write functions. The first byte of the written
;	data contains the "function" code which is dispatched via this
;	table. The first byte is the maximum legal function code, then the word
;	addresses of the handlers for each function.
;
IOCTLTBL DB	0Ch
	DW	IOCTL_FLUSH		  ; Function 0h
	DW	IOCTL_FLUSH_INVALID	  ; Function 1h
	DW	IOCTL_DISABLE		  ; Function 2h
	DW	IOCTL_ENABLE		  ; Function 3h
	DW	IOCTL_WRITE_MOD 	  ; Function 4h
	DW	IOCTL_SET_TICK		  ; Function 5h
	DW	IOCTL_LOCK		  ; Function 6h
	DW	IOCTL_UNLOCK		  ; Function 7h
	DW	IOCTL_REBOOT		  ; Function 8h
	DW	IOCTL_STAT_RESET	  ; Function 9h
	DW	IOCTL_ALL_CACHE 	  ; Function Ah
	dw	ioctl_reduce_cache_size   ; Function Bh
	dw	ioctl_increase_cache_size ; Function Ch

SET_ZR:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	LDS	BX,[PTRSAV]
ASSUME	DS:NOTHING
	MOV	[BX.RW_COUNT],0 	; NO bytes transferred
	JMP	DEVEXIT

SET_ERR_CNT:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	MOV	AL,3			;UNKNOWN COMMAND ERROR
	JMP	ERR$CNT

INT13$IOCTL_Write:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	CMP	[NULDEV],0		; Is the device valid?
	JNZ	SET_ZR			; No, you get an error
	MOV	AL,ES:[DI]		; Get command byte
	MOV	AH,BYTE PTR [IOCTLTBL]	; Valid range
	CMP	AL,AH			; In range?
	JA	SET_ERR_CNT		; No
	MOV	SI,OFFSET IOCTLTBL + 1	; Table of routines
	CBW				; Make command code a word
	ADD	SI,AX			; Add it twice since one word in
	ADD	SI,AX			;  table per command.
	JMP	WORD PTR [SI]		; GO DO COMMAND

;**	IOCTL_FLUSH -- Flush the cache, but keep the data
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_FLUSH:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	MOV	[INT_13_BUSY],1
	CALL	FLUSH_WHOLE_CACHE
	MOV	[INT_13_BUSY],0
	JMP	DEVEXIT

;**	IOCTL_FLUSH_INVALIDATE -- Flush the cache, and discard the data
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_FLUSH_INVALID:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	MOV	[INT_13_BUSY],1
	CALL	FLUSH_WHOLE_CACHE
	CALL	INVALIDATE_CACHE
	MOV	[INT_13_BUSY],0
	JMP	DEVEXIT

;**	IOCTL_DISABLE -- Disable the caching for both reads and writes
;
;   Also flush and invalidate the cache
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_DISABLE:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	MOV	[INT_13_BUSY],1
	CALL	FLUSH_WHOLE_CACHE
	CALL	INVALIDATE_CACHE
	MOV	[ENABLE_13],0
	MOV	[INT_13_BUSY],0
	JMP	DEVEXIT

;**	IOCTL_ENABLE --  Enable the caching for reads (and possibly writes)
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_ENABLE:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	MOV	[ENABLE_13],1
	JMP	DEVEXIT

;**	IOCTL_WRITE_MOD -- En/Disable Write through and write caching
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
;   Second byte of data indicates what to set
;	0 Turn off Write through
;	1 Turn on Write through
;	2 Turn off Write buffering (also flush)
;	3 Turn on Write buffering (also flush)
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_WRITE_MOD:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	CMP	CX,2		; Did user write enough?
	JB	SET_ZR		; No, error
	MOV	AL,ES:[DI.1]	; Get second byte
	CMP	AL,3		; In range?
	JA	SET_ZR		; No, error
	CMP	AL,2		; WT or WB?
	JB	SET_WRITE_TH	; WT
	DEC	AL
	DEC	AL			; 2 = 0, 3 = 1
	MOV	[INT_13_BUSY],1
	MOV	[WRITE_BUFF],AL
	CALL	FLUSH_WHOLE_CACHE
	MOV	[INT_13_BUSY],0
	JMP	DEVEXIT

SET_WRITE_TH:
	MOV	[WRITE_THROUGH],AL
	JMP	DEVEXIT

;**	IOCTL_SET_TICK -- Set tick count for auto flush
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
;   Second byte and third byte of data is value to set
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_SET_TICK:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	CMP	CX,3		; Did user write enough?
	JB	SET_ZRJ 	; No, error
	MOV	AX,ES:[DI.1]	; Get second byte and third byte as word
	MOV	[TICK_SETTING],AX
	JMP	DEVEXIT

SET_ZRJ:
	JMP	 SET_ZR

;**	IOCTL_LOCK -- Lock the current cache
;
;   Also flush the cache
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_LOCK:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	MOV	[INT_13_BUSY],1
	CALL	FLUSH_WHOLE_CACHE
	MOV	[LOCK_CACHE],1
    ;
    ; Lock all cache elements that have something in them
    ;
	MOV	SI,[CACHE_HEAD]
	INC	SI
NEXTCS:
	DEC	SI
	TEST	[SI.TRACK_FLAGS],TRACK_FREE
	JNZ	SKIPCS
	OR	[SI.TRACK_FLAGS],TRACK_LOCKED
SKIPCS:
	MOV	SI,[SI.FWD_LRU_LNK]
	INC	SI
	JNZ	NEXTCS
	MOV	[INT_13_BUSY],0
	JMP	DEVEXIT

;**	IOCTL_UNLOCK --  Unlock the cache
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_UNLOCK:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	MOV	[INT_13_BUSY],1
	MOV	[LOCK_CACHE],0
    ;
    ; UnLock all cache elements
    ;
	MOV	SI,[CACHE_HEAD]
	INC	SI
NEXTCX:
	DEC	SI
	AND	[SI.TRACK_FLAGS],NOT TRACK_LOCKED
	MOV	SI,[SI.FWD_LRU_LNK]
	INC	SI
	JNZ	NEXTCX
	MOV	[INT_13_BUSY],0
	JMP	DEVEXIT

;**	IOCTL_REBOOT -- En/Disable Reboot flush
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
;   Second byte of data indicates what to set
;	0 Turn off reboot flush
;	1 Turn on reboot flush
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_REBOOT:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	CMP	CX,2		; Did user write enough?
	JB	SET_ZRJ 	; No, error
	MOV	AL,ES:[DI.1]	; Get second byte
	CMP	AL,1		; In range?
	JA	SET_ZRJ 	; No, error
	MOV	[REBOOT_FLUSH],AL
	JMP	DEVEXIT


;**	IOCTL_STAT_RESET -- Reset the INT 13 statistics counters
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_STAT_RESET:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	XOR	AX,AX
	MOV	WORD PTR [TOTAL_WRITES],AX
	MOV	WORD PTR [TOTAL_WRITES + 2],AX
	MOV	WORD PTR [WRITE_HITS],AX
	MOV	WORD PTR [WRITE_HITS + 2],AX
	MOV	WORD PTR [TOTAL_READS],AX
	MOV	WORD PTR [TOTAL_READS + 2],AX
	MOV	WORD PTR [READ_HITS],AX
	MOV	WORD PTR [READ_HITS + 2],AX
	JMP	DEVEXIT

;**	IOCTL_ALL_CACHE -- En/Disable All cache
;
; ENTRY:
;   ES:DI is transfer address
;   CX is transfer count
;   Second byte of data indicates what to set
;	0 Turn off all cache
;	1 Turn on all cache
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
IOCTL_ALL_CACHE:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	CMP	CX,2		; Did user write enough?
	JB	SET_ZRJ2	; No, error
	MOV	AL,ES:[DI.1]	; Get second byte
	CMP	AL,1		; In range?
	JA	SET_ZRJ2	; No, error
	MOV	[ALL_CACHE],AL
	JMP	DEVEXIT

SET_ZRJ2:
	JMP	SET_ZR

;**	ioctl_reduce_cache_size  Dynamically reduce the size of the cache
;
; This routine dynamically reduces the size of an Above Board memory (/A)
; cache.  The routine is passed the number of pages that the cache should
; be reduced by.  The minimum size for a cache is 64K or 4 pages.  In
; removing the tracks from the cache, the memory is returned to the EMM
; and then the cache control structures for that memory are taken off the
; LRU list, and set to free.
;
; NOTE: In this version of INT13, only reads are cached, so that when
;	a cached track is "removed" from memory, it's contents are not
;	updated to disk.
;
; ENTRY:
;   ES:DI is transfer address
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
error_reduce_exitj:
	jmp	error_reduce_exit

ioctl_reduce_cache_size:
	assume	ds:Int13Code
	assume	es:nothing
	assume	ss:nothing

	cmp	byte ptr [driver_sel],1 ; Make sure using Above Board
	jnz	error_reduce_exitj
	mov	ax,es:[di.1]		; Get second byte
	or	ax,ax			; Reduce by a non-0 amount?
	jnz	do_it
	jmp	devexit
do_it:	mov	cl,4			; Multiply by 16 to get # of K bytes
	shl	ax,cl			; AX has requested reduction in K
	mov	bx,word ptr [current_dev_size]
	mov	si,bx			; Save current_dev_size in SI for error
	sub	bx,ax			; BX now has remaining cache memory in K
	cmp	bx,MIN_CACHE_SIZE_K	; Compare BX with min cache in K bytes
	jl	error_reduce_exitj
	mov	word ptr [current_dev_size],bx
	shr	bx,cl			; BX has new cache size in pages
	mov	byte ptr [int_13_busy],1
;
; Request Reallocation of Pages from EMM
;
	push	ax
	mov	dx,word ptr [above_pid]
	mov	ah,ABOVE_REALLOCATE_PID
	int	67h
	or	ah,ah
	jnz	real_fail
;
; Determine how many cache tracks will be lost
;
	mov	bx,word ptr [sectrack]	; Init code checked for too large track
	mov	cl,9
	shl	bx,cl			; BX has bytes/track
	mov	ax,word ptr [ttracks]
	mul	bx			; AX:DX has bytes used by tracks
	xchg	ax,si
	mov	di,dx
	mov	cx,1024
	mul	cx			; AX:DX has total bytes allocated
	sub	ax,si			; Find difference in allocated and used
	sbb	dx,di
	xchg	ax,si
	xchg	dx,di
	pop	ax			; AX still has requested reduction in K
	mul	cx			; DX:AX has requested reduction in byte

;
; Make sure the we have to free up tracks in order to satisfy the request
; HACK! HACK! HACK!  Smartdrv should only allocate as many pages as it needs.
; ChipA 14-Mar-1988
;
	cmp	dx,di
	ja	free_tracks
	jb	no_need_to_free_tracks
	cmp	ax,si
	ja	free_tracks
no_need_to_free_tracks:
	sub	ax,ax
	mov	dx,ax
	jmp	all_freed

free_tracks:
	sub	ax,si			; Account for part not used
	sbb	dx,di
	div	bx			; AX has number of tracks being "lost"
	or	dx,dx
	jz	no_remainder
	inc	ax			; Add one more track if remainder
;
; Determine which cache control structures we are to remove
;
no_remainder:
	mov	si,ax
	mov	cx,SIZE CACHE_CONTROL
	mul	cx
	xchg	ax,bx			; BX has backward offset into CCS's
	mov	ax,word ptr [ttracks]
	sub	word ptr [ttracks],si
	mul	cx			; AX has end of Cache Control
	sub	ax,bx			; AX has start offset of CCS's to remove
	mov	cx,si			; CX has number of CCS's to remove
	mov	si,word ptr [cache_control_ptr]
	add	si,ax			; SI points to first CCS to modify
;
; Loop through each cache control structure, removing from LRU list
;
remove_cache_entries:
	mov	word ptr [si].track_flags,TRACK_FREE
	call	unlink_cache
	add	si,SIZE CACHE_CONTROL
	loop	remove_cache_entries

all_freed:
	mov	byte ptr [int_13_busy],0
	jmp	devexit

real_fail:
	pop	ax
	mov	[current_dev_size],si	; Restore former dev size
	mov	byte ptr [int_13_busy],0
error_reduce_exit:
	mov	al,0Ch			; General failure
	jmp	err$cnt


;**	ioctl_increase_cache_size  Dynamically increase the size of the cache
;
; This routine dynamically increases the size of an Above Board memory (/A)
; cache.  The routine is passed the number of pages that the cache should
; be increased by.  The maximum size allowed is the size specified from the
; INT13.SYS command line.  The cache control structures for the memory added
; to the cache are placed on the LRU list at the LRU position, so that they
; will be immediately available for incoming tracks.
;
; ENTRY:
;   ES:DI is transfer address
; EXIT:
;   Through one of the device exit paths
; USES:
;   ALL
;
error_increase_exitj:
	jmp	error_increase_exit

ioctl_increase_cache_size:
	assume	ds:Int13Code
	assume	es:nothing
	assume	ss:nothing

	cmp	[driver_sel],1		; Make sure using Above Board
	jnz	error_increase_exitj
	mov	ax,es:[di.1]		; Get second byte
	mov	cl,4			; Multiply by 16 to get # of K bytes
	shl	ax,cl			; AX has requested addition in K
	mov	bx,word ptr [current_dev_size]
	mov	si,bx			; Save current dev size for error
	add	bx,ax			; BX now has new cache memory size in K
	cmp	bx,[dev_size]		; Compare BX with largest size in K bytes
	jbe	increase_size_ok
	mov	bx, [dev_size]		; Go to MAX size
	mov	ax, bx
	sub	ax, si			; Correct increase
increase_size_ok:
	mov	word ptr [current_dev_size],bx
	shr	bx,cl			; BX has new cache size in pages
	mov	[int_13_busy],1
;
; Request Reallocation of Pages from EMM
;
	push	ax
	mov	dx,[above_pid]
	mov	ah,ABOVE_REALLOCATE_PID
	int	67h
	or	ah,ah
	jnz	realloc_fail
;
; Determine how many cache tracks will be gained
;
	mov	bx,word ptr [sectrack]	; Init code checked for too large track
	mov	cl,9
	shl	bx,cl			; BX has bytes/track
	mov	ax,word ptr [ttracks]
	mul	bx			; AX:DX has bytes used by tracks
	xchg	ax,si
	mov	di,dx
	mov	cx,1024
	mul	cx			; AX:DX has total bytes allocated
	sub	ax,si			; Find difference in allocated and used
	sbb	dx,di
	xchg	ax,si
	xchg	dx,di
	pop	ax			; AX still has requested reduction in K
	mul	cx			; DX:AX has requested reduction in byte
	add	ax,si			; Account for part not used
	adc	dx,di
	div	bx			; AX has number of tracks being "gained"
	or	ax, ax			; DIV trashes flags
	jz	nothing_to_gain
;
; Determine which cache control structures we are to add
;
	mov	si,ax
	mov	cx,SIZE CACHE_CONTROL
	mov	ax,[ttracks]
	add	[ttracks],si		; Update TTRACKS
	mul	cx			; AX has end of Cache Control
	mov	cx,si			; CX has number of CCS's to add
	mov	si,[cache_control_ptr]
	add	si,ax			; SI points to first CCS to modify
;
; Loop through each cache control structure, adding to LRU list
;
add_cache_entries:
	mov	di,si			; Place element at LRU position
	xchg	di,[cache_tail]
	mov	[di].fwd_lru_lnk,si
	mov	[si].back_lru_lnk,di
	mov	[si].fwd_lru_lnk,-1
	mov	[si].track_flags,TRACK_FREE

	add	si,SIZE CACHE_CONTROL
	loop	add_cache_entries
nothing_to_gain:
	mov	[int_13_busy],0
	jmp	devexit

realloc_fail:
	pop	ax
	mov	[current_dev_size],si	; Restore to original size
	mov	[int_13_busy],0
error_increase_exit:
	mov	al,0Ch			; General failure
	jmp	err$cnt


;
; If the device errors out during install, we set the break address here.
;
ERROR_END LABEL BYTE

BREAK	<INT 1C (timer) handler>

	EVEN			; Force word align
;
; Storage for the INT 1C vector BEFORE cache installed
;
OLD_1C	DD	?

;**	INT_1C_HANDLER - Handler for INT 1C timer ticks
;
; ENTRY
;	None
;
; EXIT
;	To next 1C handler, EOI may be sent
;
; USES
;	None
;
; SEE ALSO
;	IBM PC TECH REF MANUAL section on INT 1C
;	DOS PRINT utility (most of this is stolen from there)
;
INT_1C_HANDLER	PROC	FAR
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	PUSH	AX
	DEC	[TICK_CNT]
	JNZ	CHAIN_1C
	CMP	[INT_13_BUSY],0
	JZ	TRY_FLSH
RE_TRIGGER:
	INC	[TICK_CNT]		; Set it back to 1 so next tick triggers
CHAIN_1C:
	POP	AX
	JMP	[OLD_1C]

TRY_FLSH:
	mov	al,00001011b		; Select ISR in 8259
	out	20H,al
	jmp	short yyyy
yyyy:
	jmp	short zzzz
zzzz:
	in	al,20H			; Get ISR register
	and	al,0FEH 		; Mask timer int
	jnz	RE_TRIGGER		; Another int is in progress
	INC	[INT_13_BUSY]		; Exclude
	CMP	[DIRTY_CACHE],0 	; Anything to do?
	JZ	SKIP_FLSH		; No
	STI
	mov	al,20H
	out	20H,al
	CALL	FLUSH_WHOLE_CACHE_SAV
SKIP_FLSH:
	MOV	AX,[TICK_SETTING]
	CLI
	MOV	[TICK_CNT],AX
	MOV	[INT_13_BUSY],0
	JMP	CHAIN_1C

INT_1C_HANDLER	ENDP

BREAK	<INT 13 handler>


; INT 13 stack frame
;
STACK_FRAME STRUC
USER_OFF    DW	?	    ; added for user transfer address
USER_ES DW	?
USER_DS DW	?
USER_DI DW	?
USER_SI DW	?
USER_BP DW	?
	DW	?
USER_BX DW	?
USER_DX DW	?
USER_CX DW	?
USER_AX DW	?
USER_IP DW	?
USER_CS DW	?
USER_FL DW	?
STACK_FRAME ENDS

	EVEN			; Force word align
;
; Storage for the INT 13 vector BEFORE cache installed
;
OLD_13	DD	?

;
; Array of sec/track for all hardfiles on system. First element cooresponds
;   to first hard file.
;	Value = 0 indicates no hardfile
;
SECTRKARRAY	DB  MAX_HARD_FILES DUP (0)
;
; ARRAY OF MAXIMUM USEABLE HEADS FOR ALL THE HARDFILES IN THE SYSTEM. FIRST
; ELEMENT CORRESPONDS TO FIRST HARDFILE.
;	VALUE = FF  INDICATES NO HARDFILE   (SUNILP)
;
HDARRAY 	DB  MAX_HARD_FILES DUP (0FFH)

ifdef	OMTI
OMTI_SET_CYL	EQU	0EEh
OMTI_GET_CYL	EQU	0FEh
OMTI_GET_REV	EQU	0F9h
endif	;OMTI
;
; INT 13 function dispatch
;	Addresses of routines for AH INT 13 functions
;
INT13DISPATCH	LABEL	WORD
	DW	POP_NO_PROC		; 0, reset
	DW	POP_NO_PROC		; 1, Read status
	DW	CACHE_READ		; 2, read
	DW	CACHE_WRITE		; 3, write
	DW	POP_NO_PROC		; 4, verify
	DW	      INVALID_PASS	; 5, format
	DW	      INVALID_PASS	; 6, format
	DW	      INVALID_PASS	; 7, format
	DW	POP_NO_PROC		; 8, drive parms
	DW	      INVALID_PASS	; 9, Init drive characteristic
	DW	      INVALID_PASS	; A, Read long
	DW	      INVALID_PASS	; B, Write long
	DW	POP_NO_PROC		; C, Seek
	DW	POP_NO_PROC		; D, Alt reset
	DW	      INVALID_PASS	; E, Read buffer
	DW	      INVALID_PASS	; F, Write buffer
	DW	POP_NO_PROC		; 10, Test drive rdy
	DW	POP_NO_PROC		; 11, Recalibrate
	DW	POP_NO_PROC		; 12, Controller diag
	DW	      INVALID_PASS	; 13, Drive diag
	DW	POP_NO_PROC		; 14, Controller diag internal
	DW	POP_NO_PROC		; 15, READ DASD
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	MODIFICATIONS TO DATA STRUCT TO SUPPORT MULTI-TRACK I/O
;
;	sunilp
;
; extra declarations needed
;
max_hd		db	?	;maximum useable head number for curr. drive
sect_in_trk	db	?	;maximum sector number in trk for curr drive
bytes_in_trk	dw	?	;numb of bytes in trk for current drive
int13err	db	?
;
TRUE		=	0ffH
FALSE		=	NOT TRUE
REG1_P	=	001B
REG2_P	=	010B
REG3_P	=	100B
;
REG1t	struc
START_H db	?	;start head
START_T dw	?	;start track
COUNT	dw	?	;number of words
START_S dw	?	;start sector
REG1t	ends
;
REG2t	struc
	db	?	;start head
	dw	?	;start track
TRACKS	db	?	;number of tracks
REG2t	ends
;
REG3t	struc
	db	?	;start head
	dw	?	;start track
	dw	?	;number of words
REG3t	ends
;
REGIONt struc
FLAG	db	0
REG1	db	size REG1t dup(?)
REG2	db	size REG2t dup(?)
REG3	db	size REG3t dup(?)
REGIONt ends
;
;
REGION	db	size REGIONt dup(?)
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	INT_13_HANDLER - Handler for INT 13 requests
;
; ENTRY
;	All regs as for INT 13
;
; EXIT
;	To old INT 13 handler with regs unchanged if cache not involved
;	Else return in AH and flags as per INT 13.
;
; USES
;	AH and carry bit of FLAGS
;
; SEE ALSO
;	IBM PC TECH REF MANUAL section on INT 13
;
INT_13_HANDLER	PROC	FAR
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	MOV	[INT_13_BUSY],1 ; Exclude
	TEST	DL,80H		; Hard file?
	JNZ	IS_HARD 	; Yes
NO_PROC:
	PUSHF
	CLI
	CALL	[OLD_13]	; Let old handler do it
	MOV	[INT_13_BUSY],0 ; Clear sem
	RET	2		; "IRET" chucking flags

;
; Pop off the stack frame and pass to old handler
;
POP_NO_PROC:
	POP	BX
	POP	ES
	POP	DS
    ; Simulate POPA
	POP	DI
	POP	SI
	POP	BP
	POP	BX		; Dummy for pop sp
	POP	BX
	POP	DX
	POP	CX
	POP	AX
    ;
	JMP	NO_PROC

IS_HARD:
	STI			; INTs ok now
    ;
    ; Set up standard stack frame
    ;
    ; Simulate PUSHA
	PUSH	AX
	PUSH	CX
	PUSH	DX
	PUSH	BX
	PUSH	BX		; dummy for push sp
	PUSH	BP
	PUSH	SI
	PUSH	DI
    ;
	PUSH	DS
	PUSH	ES
	push	bx
    ; Set frame pointer
	MOV	BP,SP
	MOV	BL,AH
	XOR	BH,BH			; Command in BX
	PUSH	CS
	POP	DS
ASSUME	DS:INT13CODE
	CMP	[ENABLE_13],0		; Are we enabled?
	JZ	POP_NO_PROC		; No, ignore

ifdef	OMTI
;
; The following code is used to handle the extended cylinder access method
; used by the OMTI controller.	This controller has a modified INT13 routine
; that uses a unique function number to tell the controller that the next
; access to INT13 is for an extended cylinder.
;
	test	sys_flg,OMTI_EXT	; Are we in extended state?
	jnz	in_extended_state
	cmp	bx,OMTI_SET_CYL 	; Is this the OMTI extended function?
	jnz	check_command_range
	or	sys_flg,OMTI_EXT
	jmp	pop_no_proc
in_extended_state:
;
; If we are in the extended state, we want to make sure that this call
; does not go through into the cache.  Therefore, we will check to see
; if this is a read or write function, and will return to the old INT13
; routine if so.
;
	and	sys_flg,NOT OMTI_EXT	; Clear the extended flag
	cmp	bx,2h			; READ
	jz	pop_no_proc
	cmp	bx,3h			; WRITE
	jz	pop_no_proc
check_command_range:
;
; Allow the other OMTI functions to pass through
;
	cmp	bx,OMTI_GET_CYL
	jz	pop_no_proc
	cmp	bx,OMTI_GET_REV
	jz	pop_no_proc
endif ; OMTI

	CMP	BX,15H			; Command in range?
	JA	      INVALID_PASS	; No, throw out cache
	SHL	BX,1			; Times two bytes per table entry
	JMP	[BX.INT13DISPATCH]	; Dispatch to handler

;**    FLUSH_INVALID_PASS -- Discard cache and pass through
;
; ENTRY:
;   INT 13 regs except for BP,BX and DS
; EXIT:
;   To old INT13 handler
;
FLUSH_INVALID_PASS:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	CALL	FLUSH_WHOLE_CACHE
	CALL	INVALIDATE_CACHE
	JMP	POP_NO_PROC

;**    INVALID_PASS -- DISCARD CACHE, NO NEED TO FLUSH, PASS THROUGH
;
;**	SUNIL PAI
;
; ENTRY:
;   INT 13 regs except for BP,BX and DS
; EXIT:
;   To old INT 13 handler
;
INVALID_PASS:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	CALL	INVALIDATE_CACHE
	JMP	POP_NO_PROC

;**    FLUSH_PASS -- Flush cache (but retain data) and pass through
;
; ENTRY:
;   INT 13 regs except for BP,BX and DS
; EXIT:
;   To old INT13 handler
;
FLUSH_PASS:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	CALL	FLUSH_WHOLE_CACHE
	JMP	POP_NO_PROC

BREAK	<CACHE_READ -- Read via cache>

ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
;
cache_read:
;
;	inputs: int13 regs except for bp - user stack frame
;				      bx - function (read,write)
;				      ds - int13code segment
;
;	exits:	to user success routine
;		to user error routine
;		to old int13 handler call
;
;	uses:	all but bp
;
;	written by: sunil pai
;
	call	check_parameters	; check user params
	jc	pop_no_proc		; if error go to old int 13 handler
					;
	call	process_regions 	; for multi-track business find the
					; initial partial track, middle block
					; and final partial track
					; sets up REGION struct
;
;	mov	[int13err],FALSE	; clear int 13 error flag
;
	test	[REGION.FLAG],REG1_P	; is region1 present
	je	cr$2			; if not present try region2
;
	mov	dh,[REGION.REG1.START_H]	;start head
	mov	cx,[REGION.REG1.START_T]	;get start track
	mov	bx,[REGION.REG1.START_S]	;start sector
	mov	ax,[REGION.REG1.COUNT]		;number of words
	call	process_read_partial		;
	jc	error			;go to process error
;
cr$2:	test	[REGION.FLAG],REG2_P	; is region2 present
	je	cr$3			; if not present try region3
;
	mov	dh,[REGION.REG2.START_H]	; get start head
	mov	cx,[REGION.REG2.START_T]	; get start track
	mov	al,[REGION.REG2.TRACKS] 	; get number of tracks
	call	process_block_read		; multi track capability
	jc	error				; fouled?
;
cr$3:	test	[REGION.FLAG],REG3_P	; is region3 present
	je	suc			; if not we are done
;
	mov	dh,[REGION.REG3.START_H]	; start head
	mov	cx,[REGION.REG3.START_T]	; start track
	mov	bx,1				; start sector is 1
	mov	ax,[REGION.REG3.COUNT]		; number of words
	call	process_read_partial		;
	jc	error				; just as we were about to fin!
;
;	exit points - suc and error.
;
suc:	and	[bp.USER_FL],NOT f_Carry	;
	mov	byte ptr [bp.USER_AX.1],0	;
;
operation_done:
	mov	cs:[int_13_busy],0		;clear semaphore
	pop	bx			;user offset
;
;	simulate popa
;
	pop	es
	pop	ds
	pop	di
	pop	si
	pop	bp
	pop	bx
	pop	bx
	pop	dx
	pop	cx
	pop	ax
;
	iret
;
error:
;
;	the next two instructions were removed because of the way Compaq
;	handles bad sectors. they mark sectors bad not tracks. so in a
;	track there may be good and bad sectors. However our int13 caching
;	system does i/o from disk in tracks and will not get any track with
;	bad sectors. to take care of this, we pass the read to the old int13
;	handler even when there is an int 13 error
;
;	test	[int13err],TRUE
;	jne	er$1			;if not int13 error go to call
					;int13
	jmp	pop_no_proc
;er$1:	or	[bp.USER_FL],f_Carry	;
;	mov	byte ptr [bp.USER_AX.1],AL	;int13 error code
;	jmp	operation_done
;
pop_no_procw:
	call	invalidate_cache
	jmp	pop_no_proc
;
cache_write:
;
;	inputs: int13 regs except for bp - user stack frame
;				      bx - function (read,write)
;				      ds - int13code segment
;
;	uses:	all but bp
;
;	written by: sunil pai
;
	call	check_parameters	;check user params
	jc	pop_no_procw		;error
					;
	call	process_regions 	;for multi-track business find the
					;initial partial track, middle block
					;and final partial track
					;sets up REGION struct
;
;	writes always update disk, i.e., write through always operational
;
	mov	ax,[bp.user_ax] 	; restore int13 registers
	mov	cx,[bp.user_cx] 	;
	mov	dx,[bp.user_dx] 	;
	mov	bx,[bp.user_bx] 	;
	mov	es,[bp.user_es] 	;
	pushf				; since interrupt routine being called
	cli
	call	[old_13]		; call old int 13 handler
	jnc	cw$1			; no error in writing to disk, continue
;
	or	[bp.user_fl],f_Carry	; error then set carry
	mov	byte ptr [bp.user_ax.1],ah	 ; and error code
	jmp	short errorw		; and take error exit
;
;	int 13 was successful, now we have to update cache as well
;
cw$1:	and	[bp.user_fl],not f_Carry	; int 13 success
	mov	byte ptr [bp.user_ax.1],0	 ;
;
	and	dl,not 80h
;
	test	[REGION.FLAG],REG1_P	; is region1 present
	je	cw$2			; if not present try region2
;
	mov	dh,[REGION.REG1.START_H]	; get start head
	mov	cx,[REGION.REG1.START_T]	; get start track
	mov	bx,[REGION.REG1.START_S]	; start sector
	mov	ax,[REGION.REG1.COUNT]		; number of words
	call	process_write_partial		; partial write
	jc	errorw			; go to process error
;
cw$2:	test	[REGION.FLAG],REG2_P	; is region2 present
	je	cw$3			; if not present try region3
;
	mov	dh,[REGION.REG2.START_H]	; get start head
	mov	cx,[REGION.REG2.START_T]	; get start track
	mov	al,[REGION.REG2.TRACKS] 	; get number of tracks
	call	process_block_write		;
	jc	errorw				; fouled?
;
cw$3:	test	[REGION.FLAG],REG3_P	; is region3 present
	je	operation_donew 		; if not we are done
;
	mov	dh,[REGION.REG3.START_H]	; start head
	mov	cx,[REGION.REG3.START_T]	; start track
	mov	bx,1				; start sector is 1
	mov	ax,[REGION.REG3.COUNT]		; number of words
	call	process_write_partial		;
	jnc	operation_donew 		; no error - finish
;
errorw: call	invalidate_cache		; we are not sure of the
operation_donew:
	jmp	operation_done
;
;
INT_13_HANDLER	endp
;
process_read_partial	proc	near
;
;	is used to read a partial track
;
;	inputs: dx: head and drive (8th bit stripped)
;		cx: track
;		bx: start sector
;		ax: number of words
;
;	outputs:cy set if error
;		   clear if success
;
;	strategy:
;		if (track in cache) then {
;			if (track in track_buffer) then
;				perform user read from track buffer;
;			else
;				perform user read from cache;
;		}
;		else {
;			read track into track buffer;
;			read track buffer into cache;
;			perform user read from track buffer;
;		}
;
;	cache transfers handled by freeing cache element if possible
;	and making it lru
;
;	uses: only dx assumed unchanged
;
	call	track_in_cache		; is track in cache
	jc	read_disk		; if not we have to read from disk
;
	cmp	cx,[track_buffer_cyln]	; is it in the track buffer
	jnz	not_in_mem		; no
	cmp	dx,[track_buffer_hddr]	;
	jz	read_bufferj		; yes
;
;	read buffer from cache
;
not_in_mem:
	push	dx
	xchg	ax,bx		;get number of words in bx and start sect in ax
	dec	ax		;0 based number
	mov	cl,9		;
	shl	ax,cl		;byte offset
	xor	dx,dx		;
;
	mov	cx,bx		;number of words
	mov	es,[bp.user_es] ;
	mov	di,[bp.user_off];
	shl	bx,1		; number of bytes
	add	[bp.user_off],bx	; update user offset
;
	add	ax,word ptr [si.base_offset]
	adc	dx,word ptr [si.base_offset.2]
	xor	bh,bh
	push	si
	push	ds
	push	bp
	call	blkmov
	pop	bp
	pop	ds
	pop	si
	pop	dx
	jc	err_cache
	call	cache_is_mru
	clc
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	track not in cache. see if free cache available to initiate transfer
;
read_disk:
	cmp	di,-1		;free cache
	jnz	rd_part 	;if present we can initiate read
	stc			; else error exit
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
read_bufferj:
	jmp	      short read_buffer
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	cache element available. we can start by transferring track from disk
;	to track buffer.
;
rd_part:
	mov	si,di		;get element in si
	mov	[track_buffer_cyln],-1	;invalidate present track buffer
	mov	[track_buffer_hddr],-1
	mov	[si.track_flags],track_free	;if read fails
	push	dx
	push	cx
	push	bx
	push	ax
	or	cl,1
	or	dl,80h
	mov	al,[sect_in_trk]
	mov	ah,2			; read

	mov	es,[track_segment]
	xor	bx,bx
	pushf
	cli
	call	[old_13]
	jnc	rd$1
	cmp	ah,11h	;the int13 error which is not an error
	je	rd$1
	mov	[int13err],TRUE
	add	sp,8
	mov	al,ah
	stc
	ret
;
;	transfer track buffer to cache
;
rd$1:
	xor	di,di	;es:di is transfer address
	mov	cx,[bytes_in_trk]
	shr	cx,1			; cx is number words in track
	mov	bh,1		;write
	mov	ax,word ptr [si.base_offset]	;address of cache
	mov	dx,word ptr [si.base_offset.2]	;
	push	ds
	push	si
	push	bp
	call	blkmov
	pop	bp
	pop	si
	pop	ds
	pop	ax
	pop	bx
	pop	cx
	pop	dx
	jnc	rd$2
;
;	error in transferring info to cache. invalidate cache element and
;	make it lru
;
err_cache:
	mov	[si.track_flags],track_free
	call	cache_is_lru		; make cache element lru
	stc
	ret
;
;	info transfer to cache successful. fill in track, head and drive
;	info into cache control element and track buffer control element
;
if	debug
rd_2:
endif
rd$2:
	mov	word ptr [si.track_cyln],cx
	mov	word ptr [si.track_drive],dx
	and	[si.track_flags], not track_free
	mov	word ptr [track_buffer_cyln],cx
	mov	word ptr [track_buffer_hddr],dx
;
;	perform user i/o from track buffer
;
read_buffer:
	call	cache_is_mru
;
	mov	si,bx		; start sector
	dec	si		; 0 based number
	mov	cl,9		;
	shl	si,cl		; byte offset in si
	; SI is the byte offset within the track segment.
	mov	cx,ax
	mov	es,[bp.user_es]
	mov	di,[bp.user_off]
	push	ds
	mov	ds,[track_segment]
	cld
rep	movsw
	pop	ds
	mov	[bp.user_off],di
	clc
	ret
;
process_read_partial	endp
;
process_block_read	proc	near
;
;	inputs: ax = number of tracks
;		dx = drive and head (8th bit stripped)
;		cx = start track
;		bp = user stack frame
;
;	outputs: cy set if error
;		 cy clear if okay
;
;	algorithm:
;
;		repeat
;		    if (cur_trk in cache) then
;			    transfer track from cache to user buffer;
;			    no_of_trks = no_of_trks - 1
;		    else
;			    accumulate tracks which are not in cache
;			    read these in one disk operation
;			    transfer these from user buffer to cache
;			    no_of_trks = no_of_trks - accumulated_trks
;		until no_of_trks == 0
;
pbr$1:
;
;	since we are going to look ahead and see how many tracks can
;	be dealt with together, we have to save start head and track
;
	push	cx		; save start head
	push	dx		; save start track
	xor	ah,ah		;number of accumulated tracks
pbr$2:	call	track_in_cache	;
	jnc	pbr$4		; if current track in cache start processing
	inc	dh		; go to next track
	call	adj_hd_trk	;
	inc	ah		;accumulate the tracks
	dec	al		;are we done
	jne	pbr$2		;go to see next track
	pop	dx		;restore start head and track
	pop	cx		;
	call	pr_acc_trks	;process the accumulated tracks
	ret			;we are done
pbr$4:
	pop	dx		;restore start head and track
	pop	cx
	or	ah,ah		;are there any accumulated
	je	pbr$5
	call	pr_acc_trks	;process the accumulated tracks
	jc	pbr$7		;if carry set finish with error
	add	dh,ah		;adjust track and head
	call	adj_hd_trk
	jmp	pbr$1
;
pbr$5:	call	pr_cur_trk	;process current track which is in cache
	jc	pbr$7		;if carry set finish with error
	inc	dh
	call	adj_hd_trk
pbr$6:
	dec	al		;are we done?
	jne	pbr$1		;
	clc
pbr$7:	ret
;
process_block_read	endp
;
pr_acc_trks	proc	near
;
;	inputs: cx = start track
;		dh = start head
;		ah = number of accumulated tracks
;
;	outputs: if success :- cy clear, [bp.user_off] modified
;		 if failure :- cy set
;
;	regs to be preserved: al,cx,si
;
;	algorithm:
;
;		read buffer from disk;
;		for (cur_trk=start_trk,transfer_off=user_off; no_of_trks-- > 0;
;		transfer_off=transfer_off+size_of_trk) do
;			if ((cache=get_cache())!=-1) then
;				transfer_trk_to_cache;
;			else
;				exit with error;
;
;
	push	si
	push	dx
	push	cx
	push	ax		; stack:- {ax,cx,dx,si}
;
;	initialise int13 registers for reading the accumulated tracks into
;	user memory.
;
	mov	al,ah		;number of tracks
	xor	ah,ah		;in ax
;
	mul	[sect_in_trk]	;get number of sectors in ax
;
	mov	ah,2
	or	cx,1		;start sector
;
	or	dl,80h		;set hard disk bit
	mov	bx,[bp.user_off];
	mov	es,[bp.user_es] ;
;
	pushf
	cli
	call	[old_13]	;perform multi track read
;
;	check for int 13 error
;
	jnc	pat$1		;if okay proceed
;
	add	sp,8		;clear stack
	mov	al,ah
	mov	[int13err],TRUE ;
	stc
	ret			;error exit
;
;	we have succesfully read al tracks into user memory. now these have
;	to transfer these to cache.
;
pat$1:	and	dl,not 80h	;clear off 8th bit
	pop	ax		;restore ax
	pop	cx		;
	push	cx		;
	push	ax
;
	mov	di,[bp.user_off];initialise transfer offset
;
;	ah has number of tracks still left to be transferred
;	di has transfer offset
;	cx has current track number
;	dx has current drive and head
;
pat$2:
	call	get_cache	;get free cache element
;
;	si = cache element
;
	cmp	si,-1		;was there an element
	je	pat$5		;cache saturated exit
;
;	check if track is in track buffer
;
	cmp	cx,[track_buffer_cyln]
	jne	pat$21
	cmp	dx,[track_buffer_hddr]
	jne	pat$21
;
;	track is in track buffer. to avoid two transfers invalidate
;	track buffer
;
	mov	[track_buffer_cyln],-1
	mov	[track_buffer_hddr],-1
;
;	transfer track from user buffer to cache
;
pat$21: mov	[si.track_flags],track_free    ;if write fails
	push	cx
	push	ax
	push	ds
	push	si
	push	bp
	push	di
	push	dx
;
	mov	es,[bp.user_es]
	mov	cx,[bytes_in_trk]
	shr	cx,1			;words
	mov	ax,word ptr [si.base_offset]
	mov	dx,word ptr [si.base_offset.2]
	mov	bh,1		;write
	call	blkmov
;
	pop	dx
	pop	di
	pop	bp
	pop	si
	pop	ds
	pop	ax
	pop	cx
;
	jnc	pat$3
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	error in transferring information to cache. make it lru
;
;
	call	cache_is_lru
pat$5:
	add	sp,8
	stc
	ret			;cache error exit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	successfully transferred information to cache. fill in track and
;	drive and head information into cache control element
;
pat$3:	mov	word ptr [si.track_cyln],cx
	mov	word ptr [si.track_drive],dx
	and	[si.track_flags],not track_free
	call	cache_is_mru

;
	add	di,[bytes_in_trk]   ;advance pointer in user transfer buffer to
				    ;next track
;
	inc	dh		    ;advance track
	call	adj_hd_trk
;
pat$4:	dec	ah		    ;have we processed all the accumulated trks
	jne	pat$2
	mov	[bp.user_off],di    ;update user transfer address to beyond
				    ;this accumulated block
	pop	ax
	pop	cx
	pop	dx
	pop	si
	clc
	ret				;success exit
;
pr_acc_trks	endp
;
pr_cur_trk	proc	near
;
;	inputs:
;	si = cache element
;	cx = current track
;	dx = drive and head
;
;	outputs:
;	cy = set if error
;	   = clear if success
;
;	algorithm:
;		transfer track from cache to user memory
;
	push	ax
	push	cx
	push	dx
	push	si
	push	ds
	push	bp
;
	mov	cx,[bytes_in_trk]
	shr	cx,1
	mov	ax,word ptr [si.base_offset]
	mov	dx,word ptr [si.base_offset.2]
	mov	es,[bp.user_es]
	mov	di,[bp.user_off]
	xor	bh,bh		;read
	call	blkmov
;
	pop	bp
	pop	ds
	pop	si
	pop	dx
	pop	cx
	pop	ax
;
	jnc	pct$1
;
	mov	[si.track_flags],track_free
	call	cache_is_lru
	stc
	ret		;error exit
;
pct$1:	call	cache_is_mru
	mov	di,[bytes_in_trk]
	add	[bp.user_off],di
	clc
	ret
;
pr_cur_trk	endp
;
process_write_partial	proc	near
;
;	is used to write a partial track
;
;	inputs: dx: int13 dx with high bit of dl set off
;		cx: track
;		bx: start sector
;		ax: number of words
;
;	outputs:cy set if error
;		   clear if success
;
;	strategy:
;		if (track in cache) then {
;			if (track in track_buffer) then
;				invalidate track buffer;
;			perform user write into cache;
;		}
;		else {
;			read track into track buffer;
;			write track buffer into cache;
;		}
;
;
	call	track_in_cache		;is track in cache
	jc	read_diskw		;if not we have to read from disk
;
	cmp	cx,[track_buffer_cyln]	;is it in the track buffer
	jnz	not_in_memw		;no
	cmp	dx,[track_buffer_hddr]	;
	jnz	not_in_memw		;no
					;yes
;
	mov	[track_buffer_cyln],-1	;invalidate trk buf
	mov	[track_buffer_hddr],-1	;to avoid two transfers
;
;	update cache element from user buffer
;
not_in_memw:
	push	dx
	xchg	ax,bx		;get number of words in bx and start sect in ax
	dec	ax		;0 based number
	mov	cl,9		;
	shl	ax,cl		;byte offset
	xor	dx,dx		;
;
	mov	cx,bx		;number of words
	mov	es,[bp.user_es] ;
	mov	di,[bp.user_off];
	shl	bx,1
	add	[bp.user_off],bx
;
	add	ax,word ptr [si.base_offset]
	adc	dx,word ptr [si.base_offset.2]
	mov	bh,1		;write
	push	si
	push	ds
	push	bp
	call	blkmov
	pop	bp
	pop	ds
	pop	si
	pop	dx
	jc	err_cw
	call	cache_is_mru
	clc
	ret
;
;	cache error
;
err_cw: mov	[si.track_flags],track_free
	call	cache_is_lru
	stc
	ret
;
;	track not in cache. see if free cache element available
;
read_diskw:
	cmp	di,-1		;free cache
	jnz	rd_partw	;if present we can initiate read
	stc
	ret
;
;	free cache element available. read track from disk into track buffer
;
rd_partw:
	mov	si,di		;get element in si
	mov	[track_buffer_cyln],-1
	mov	[track_buffer_hddr],-1
	mov	[si.track_flags],track_free
	push	dx
	push	cx
	push	bx
	push	ax
	or	cl,1
	or	dl,80h
	mov	al,[sect_in_trk]
	mov	ah,2

	mov	es,[track_segment]
	xor	bx,bx
	pushf
	cli
	call	[old_13]
	jnc	wr$1
	cmp	ah,11h	;the int13 error which is not an error
	je	wr$1
	mov	[int13err],TRUE
	add	sp,8
	mov	al,ah
	stc
	ret
;
;	since we have already updated disk, the track read doesn't need
;	to be updated from user buffer. transfer track from track buffer
;	into cache
;
wr$1:	xor	di,di	;es:di is transfer address
	mov	al,[sect_in_trk]
	xor	ah,ah
	mov	cl,8
	shl	ax,cl
	mov	cx,ax
	mov	bh,1		;write
	mov	ax,word ptr [si.base_offset]
	mov	dx,word ptr [si.base_offset.2]
	push	ds
	push	si
	push	bp
	call	blkmov
	pop	bp
	pop	si
	pop	ds
	pop	ax
	pop	bx
	pop	cx
	pop	dx
	jnc	wr$2
	ret
;
;	information successfully transferred to cache. fill in cache
;	control element with the info on head, drive and track
;
wr$2:
	mov	word ptr [si.track_cyln],cx
	mov	word ptr [si.track_drive],dx
	and	[si.track_flags], not track_free
	mov	word ptr [track_buffer_cyln],cx
	mov	word ptr [track_buffer_hddr],dx
;
	call	cache_is_mru
;
	shl	ax,1
	add	[bp.user_off],ax
	clc
	ret
;
process_write_partial	endp
;
;
process_block_write	proc	near
;
;	al = number of tracks
;	cx = start track
;	dx = drive and start head
;	bp = user stack frame
;
;	cy set if error
;	cy clear if success
;
;	algorithm: for (cur_trk=st_trk; trks-- > 0; )
;			if (cur_trk in cache) then
;			    write cur_trk from user buffer into cache;
;			else {
;			    get a free cache element;
;			    write cur_trk from user buffer into this cache elem
;			}
;
	mov	di,[bp.user_off]
;
pbw$1:	push	di		;save it because next call destroys di
	call	track_in_cache	;is the track in cache
	jnc	pbw$2
;
	cmp	di,-1		;no free cache
	je	pbw$4		;error exit
;
	mov	si,di		;track was not in cache. now there will be one
	mov	[si.track_flags],track_free
	mov	word ptr [si.track_cyln],cx
	mov	word ptr [si.track_drive],dx
;
pbw$2:	pop	di
;
;	check if it is in track buffer also in which case invalidate trk buffer
;
	cmp	cx,[track_buffer_cyln]
	jne	pbw$21
	cmp	dx,[track_buffer_hddr]
	jne	pbw$21
;
;	invalidate track buffer to avoid two transfers
;
	mov	[track_buffer_cyln],-1
	mov	[track_buffer_hddr],-1
;
;	update cache from user buffer
pbw$21:
	push	cx		;
	push	ax
	push	ds
	push	si
	push	bp
	push	di
	push	dx
;
	mov	es,[bp.user_es]
	mov	cx,[bytes_in_trk]
	shr	cx,1
	mov	ax,word ptr [si.base_offset]
	mov	dx,word ptr [si.base_offset.2]
	mov	bh,1
	call	blkmov
;
	pop	dx
	pop	di
	pop	bp
	pop	si
	pop	ds
	pop	ax
	pop	cx
;
	jnc	pbw$22
	jmp	err_cw
;
pbw$22: and	[si.track_flags],not track_free
;
	inc	dh		;go to next track
	call	adj_hd_trk
pbw$3:	add	di,[bytes_in_trk]
	call	cache_is_mru
;
	dec	al		; are we done
	jne	pbw$1
;
;	success exit
	mov	[bp.user_off],di
	clc
	ret
;
;	error exit
;
pbw$4:	pop	di
	stc
	ret
;
process_block_write	endp
;
check_parameters	proc	near
;
;	inputs: same as int13 registers except for
;		BP - user_stack_frame
;		BX - function (either read or write)
;		DS - int13code segment
;
;	outputs: carry set if params invalid
;		 carry clear if params okay
;
;		 if parameters okay :
;		 dl - drive with high bit off
;		 bx - sector number
;		 cl - cleared of the sector number
;
;
;	check for number of drives
;
	and	dl, not 80H		; turn off high bit of drive
	cmp	dl,MAX_HARD_FILES	; more than allowed drives?
	jae	bad_parmx		; error.
;
;	check for number of sectors
;
	or	al,al			; zero sectors ?
	je	bad_parmx		; error.
;
	cmp	al,80h			; more than 80h sectors ?
	ja	bad_parmx		; error.
;
;	check for wrap in user transfer address
;
	mov	di,[bp.user_bx] 	; es:di is transfer address
	xor	ah,ah			; ax has number of sectors
	mov	si,ax			; get it into si
	push	cx			;
	mov	cl,9
	shl	si,cl			; convert number of sectors into
					; number of bytes
	dec	si			; convert into zero based number
	pop	cx			;
	add	di,si			; add to transfer address offset
	jc	bad_parmx		; if exceeds 64k offset then wrap
;
;	get drive number into di to use as offset into sect / trk table
;
	mov	di,dx			; drive number
	and	di,0000000011111111B	; just get the relevant bits
;
;	form sector number in bx and compare against allowed number of sectors
;	in track on the drive indicated
;
	mov	bx,cx			;
	and	bx,0000000000111111B	; bl will then have sector number
	or	bx,bx			; zero sector number
	je	bad_parmx		; is bad
	cmp	bl, [di.sectrkarray]	; is it more than number of sectors
					; allowed
	ja	bad_parmx		;
;
;	check head parameter
;
	cmp	dh,[di.hdarray] 	; is it more than max useable val for drive
	ja	bad_parmx		;
;
;	do we need some code to check if read exceeds tracks in system ?
;	should we also put a limit on the number of sectors that could
;	be looked up in cache ?
;
;
;	clear off sector number from cl to leave just trk number in cx
;
	and	cl,11000000B		; clear off sector number
;
;	store sectors in track for current drive and bytes in track for
;	current drive in memory
;
	push	bx
	push	cx
	mov	bl,[di.hdarray]
	mov	[max_hd],bl	      ; maximum head number for cur. drive
	mov	bl,[di.sectrkarray]	; number of sectors in trk
	mov	[sect_in_trk],bl	; store this
	mov	cl,9
	shl	bx,cl			; bytes in track
	mov	[bytes_in_trk],bx	; store this
	pop	cx
	pop	bx
	clc
	ret				;return with no error
;
bad_parmx:
	stc
	ret
;
check_parameters	endp
;
process_regions proc	near
;
;	inputs: bx - start sector
;		al - number of sectors
;		cx - start track
;
;	outputs: none
;
;	action: initialise regions struct
;
	mov	byte ptr [REGION.FLAG],0 ; clear regions flag
	cmp	bx,1		; if start sector is one
	je	pr$2		; might as well start with region2
;
;	process region1
;
	or	[REGION.FLAG],REG1_P	; mark region1 present
	mov	ah,[sect_in_trk]	; get sectors in track
	sub	ah,bl		; remaining number of sectors in track
	inc	ah		; adjust 0 based numb to one based numb
	cmp	ah,al
	jbe	pr$1		; if below or equal ah has number of sectors
				; in region1
	mov	ah,al		; else all the sectors are in region1
pr$1:	sub	al,ah		; adjust number of sectors
	mov	[REGION.REG1.START_H],dh
	mov	[REGION.REG1.START_T],cx
	mov	[REGION.REG1.START_S],bx
	push	cx		; save these registers
	push	ax		;
	mov	al,ah		;
	xor	ah,ah		; ax has number of sectors now
	mov	cl,8		;
	shl	ax,cl		; multiply by 256 to get number of words
	mov	[REGION.REG1.COUNT],ax	; store this count
	pop	ax		;
	pop	cx
	inc	dh
	call	adj_hd_trk
;
;	process region2
;
pr$2:	or	al,al		; are we done
	je	pr$end		;
	xor	ah,ah		; ax has number of sectors
	div	[sect_in_trk]	; find number of tracks
	or	al,al		; al will have number of full tracks
				; ah will have number of sectors left
	je	pr$3		; if no full tracks no region2
;
	or	[REGION.FLAG],REG2_P	; mark region2 present
	mov	[REGION.REG2.START_H],dh
	mov	[REGION.REG2.START_T],cx; store start track
	mov	[REGION.REG2.TRACKS],al ; and number of tracks
	add	dh,al		; adjust track number
	call	adj_hd_trk
;
;	process region3
;
pr$3:	or	ah,ah		; are we done (no sectors left)
	je	pr$end		; if yes go to fin
	or	[REGION.FLAG],REG3_P	; else mark region3 present
	mov	[REGION.REG3.START_H],dh
	mov	[REGION.REG3.START_T],cx	;store track number
	mov	cl,8
	mov	al,ah
	xor	ah,ah		; convert number of sectors into number of
	shl	ax,cl		; words
	mov	[REGION.REG3.COUNT],ax	; store this
pr$end:
;
	ret
;
process_regions endp
;
;	Support Routines:
;
;
track_in_cache	proc	near
;
;	input:	dl = drive number with bit 8 set off
;		cx = cylinder number
;
	mov	di,-1		; di will return lru item nearest to matching
				; element, -1 if none
	mov	si,[cache_head] ; start with mru cache entry
	inc	si		; to counter next instruction
nexte:
	dec	si		; to counter last instruction in the loop
	test	[si.track_flags],track_locked ; is the track locked?
	jnz	no_set		;
	mov	di,si		; if not locked update di to this element
no_set:
	test	[si.track_flags],track_free ; is element free
	jnz	skipe		; if free we need not check this one
	cmp	dx,word ptr [si.track_drive]	; if not free check drive+head
	jnz	skipe		;
	cmp	cx,[si.track_cyln]		; and cylinder number
	jz	tic$1		; if found exit routine
skipe:
	mov	si,[si.fwd_lru_lnk]	; else go to check next cache element
	inc	si		; if last element was end then si = -1
	jnz	nexte		; and incrementing it will set zero flag
	stc
	ret
tic$1:	clc
	ret
;
track_in_cache	endp
;
get_cache	proc	near
;
;	inputs: none
;	outputs: si = lru cache element not locked
;		    = -1 if all elems locked
;
	mov	si,[cache_tail] ;start with lru element
	inc	si		;to counter next instruction
gc$1:
	dec	si		; to counter last instruction in loop
	test	[si.track_flags],track_locked ; is the element locked
	jz	gc$2		; if not locked this is the lucky(?) guy
;
	mov	si,[si.back_lru_lnk]	; else go back in chain to check the
					; next recently used cache element
	inc	si		; as before -1 is the end of chain
	jnz	gc$1		; incrementing it will set zero flag
;
	dec	si		; no element found, si = -1
;
gc$2:	ret
;
get_cache	endp
;
adj_hd_trk  proc    near
;
;	inputs: ch,cl track number
;		dh changed head number to be checked and adjusted
;
;	outputs: cx and dh updated
;
	pushf
aht$1:	cmp	dh,[max_hd]	    ;is the head number > heads on drive
	jbe	aht$2
	sub	dh,[max_hd]	    ;if so decrease head number by number of
				    ;heads on drive
	dec	dh		    ;by one more
	add	ch,1		    ;and step to next track
	jnc	aht$1
	add	cl,40h
	jmp	aht$1
aht$2:	popf
	ret
;
adj_hd_trk	endp

CACHE_HIT PROC NEAR
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
CACHE_HIT ENDP


;**	INVALIDATE_CACHE -- Discard all cache info
;
; ENTRY
;	Cache is flushed (If it is not, all dirty info will simply be chucked)
; EXIT
;	All elements of cache are marked free
; USES
;	BX,FLAGS
;
INVALIDATE_CACHE PROC NEAR
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	MOV	BX,[CACHE_HEAD]
	INC	BX		; Counter next instruction
NEXTC:
	DEC	BX
	MOV	[BX.TRACK_FLAGS],TRACK_FREE
	MOV	BX,[BX.FWD_LRU_LNK]
	INC	BX
	JNZ	NEXTC
    ;
    ; Track buffer invalid too
    ;
	MOV	[TRACK_BUFFER_CYLN],-1
	MOV	[TRACK_BUFFER_HDDR],-1
	MOV	[DIRTY_CACHE],0
	ret

INVALIDATE_CACHE ENDP

;**	CACHE_IS_MRU -- Put cache element in LRU chain at MRU position
;
; ENTRY
;	SI points cache element to place at MRU position
; EXIT
;	SI is at MRU position (head)
; USES
;	DI,FLAGS
;
CACHE_IS_MRU PROC NEAR
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	push	di
	CMP	SI,[CACHE_HEAD]
	JZ	RET444
	CALL	UNLINK_CACHE
	MOV	DI,SI
	XCHG	DI,[CACHE_HEAD]
	MOV	[DI.BACK_LRU_LNK],SI
	MOV	[SI.FWD_LRU_LNK],DI
	MOV	[SI.BACK_LRU_LNK],-1
RET444: pop di
	RET

CACHE_IS_MRU ENDP

;**	CACHE_IS_LRU -- Put cache element in LRU chain at LRU position
;
; ENTRY
;	SI points to cache element to place at LRU position
; EXIT
;	SI is at LRU position (tail)
; USES
;	DI,FLAGS
;
CACHE_IS_LRU PROC NEAR
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	push	di
	CMP	SI,[CACHE_TAIL]
	JZ	RET555
	CALL	UNLINK_CACHE
	MOV	DI,SI
	XCHG	DI,[CACHE_TAIL]
	MOV	[DI.FWD_LRU_LNK],SI
	MOV	[SI.BACK_LRU_LNK],DI
	MOV	[SI.FWD_LRU_LNK],-1
RET555: pop	di
	RET

CACHE_IS_LRU ENDP

;**	UNLINK_CACHE -- Unlink cache element from LRU chain
;
; ENTRY
;	SI points to element to unlink
; EXIT
;	SI is unlinked
; USES
;	DI,FLAGS
;
UNLINK_CACHE PROC NEAR
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	PUSH	BX
	MOV	DI,[SI.BACK_LRU_LNK]	; Get prev guy
	INC	DI			; Guy First?
	JZ	NEW_HEAD		; Yes
	DEC	DI
	MOV	BX,[SI.FWD_LRU_LNK]	; Get next guy
	MOV	[DI.FWD_LRU_LNK],BX	; Prev fwd is my fwd
	INC	BX			; Is that guy last?
	JZ	NEW_TAIL		; Yes
	DEC	BX
	MOV	[BX.BACK_LRU_LNK],DI	; Next back is my back
NULL_CACHE:
	POP	BX
	RET

NEW_HEAD:
	MOV	DI,[SI.FWD_LRU_LNK]	; Is head also tail?
	INC	DI
	JZ	NULL_CACHE		; Yes
	DEC	DI
	MOV	[CACHE_HEAD],DI 	; New head
	MOV	[DI.BACK_LRU_LNK],-1	; New head has no back link
	POP	BX
	RET

NEW_TAIL:
	MOV	[CACHE_TAIL],DI 	; New tail
	POP	BX
	RET
UNLINK_CACHE ENDP

RETRY_CNT	DB	?

;**	WRITE_FROM_CACHE -- Write out cache element to disk
;
; ENTRY
;	SI -> cache element to write
; EXIT
;	Carry Clear
;		Written OK
;		Track buffer is set to this track
;	Carry Set
;		Error, AL is error code
;		Track buffer is set to empty
; USES
;	AX,BX,CX,DX,ES,DI,FLAGS
;
WRITE_FROM_CACHE PROC NEAR
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
    ;
    ; First transfer track down to track buffer because we can't write
    ;	direct to extended or expanded mem with INT 13
    ;

	mov	es,[track_segment]
	xor	DI,DI	; ES:DI is transfer addr for BLKMOV
	MOV	BX,WORD PTR [SI.TRACK_DRIVE]
	XOR	BH,BH
	MOV	AL,[BX.SECTRKARRAY]
	XOR	AH,AH
	PUSH	AX
	MOV	CL,8
	SHL	AX,CL			; AX is words in track
	MOV	CX,AX
	XOR	BH,BH			; Read
	MOV	AX,WORD PTR [SI.BASE_OFFSET]
	MOV	DX,WORD PTR [SI.BASE_OFFSET.2]	; DX:AX is address in mem
	PUSH	DS
	PUSH	SI
	PUSH	BP
	CALL	BLKMOV			; Track buffer contents to track buffer
	POP	BP
	POP	SI
	POP	DS
	JC	ERR_FLP
	POP	AX			; AL is sec/trk
    ;
    ; Now write it out to drive from the track buffer
    ;
	MOV	CX,[SI.TRACK_CYLN]
	MOV	DX,WORD PTR [SI.TRACK_DRIVE]
	MOV	[TRACK_BUFFER_CYLN],CX	; Set track buffer currency
	MOV	[TRACK_BUFFER_HDDR],DX
	OR	CL,1
	OR	DL,80H
	MOV	AH,3

	mov	es,[track_segment]
	xor	BX,BX
	PUSH	AX
	MOV	[RETRY_CNT],5
RETRY_WRITE:
	PUSHF
	CALL	[OLD_13]		; Write it out
	JC	ERR_RETRY
NO_ERR1:
	POP	AX
ERR_FL:
	ret

ERR_RETRY:
	CMP	AH,11H			; The error that is not an error?
	JZ	NO_ERR1 		; Yes, cmp cleared carry
	PUSH	AX			; Save error in AH
	MOV	AH,0			; Reset
	INT	13H
	POP	AX			; Get error back
	DEC	[RETRY_CNT]
	JZ	SET_ERR 		; Return error
	POP	AX			; Recover correct AX for INT 13
	PUSH	AX
	JMP	RETRY_WRITE

SET_ERR:
	MOV	AL,AH			; INT 13 error to AL
ERR_FLP:
	ADD	SP,2
	STC
	MOV	[TRACK_BUFFER_CYLN],-1	; Zap the track buffer
	MOV	[TRACK_BUFFER_HDDR],-1
	JMP	ERR_FL

WRITE_FROM_CACHE ENDP

;**	FLUSH_CACHE -- Flush specific cache element if it's dirty
;
; ENTRY
;	SI points to element to flush
; EXIT
;   Carry Clear
;	SI is flushed if it was dirty
;	SI.TRACK_FLAGS dirty bit clear
;	Track buffer set to this track
;   Carry Set
;	SI could not be flushed
;	SI.TRACK_FLAGS = free
;	AL is error code
;	Track buffer set to empty
; USES
;	AX,BX,CX,DX,ES,DI,FLAGS
;
FLUSH_CACHE PROC NEAR
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	TEST	[SI.TRACK_FLAGS],TRACK_FREE	; Clears carry
	JNZ	IGNORE_TRK
	TEST	[SI.TRACK_FLAGS],TRACK_DIRTY	; Clears carry
	JZ	IGNORE_TRK
	CALL	WRITE_FROM_CACHE
	DEC	[DIRTY_CACHE]			; Doesn't effect carry
	JC	FLUSH_ERRX
	AND	[SI.TRACK_FLAGS],NOT TRACK_DIRTY ; Clears carry
IGNORE_TRK:
	ret

FLUSH_ERRX:
	MOV	[SI.TRACK_FLAGS],TRACK_FREE	; Track gone, unlocked
	RET

FLUSH_CACHE ENDP

;**	FLUSH_WHOLE_CACHE_SAV -- Flush all dirty cache elements saving regs
;
; ENTRY
;	None
; EXIT
;	Cache flushed
; USES
;	FLAGS
;
FLUSH_WHOLE_CACHE_SAV PROC NEAR
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
    ; Simulate PUSHA
	PUSH	AX
	PUSH	CX
	PUSH	DX
	PUSH	BX
	PUSH	BX		; dummy for push sp
	PUSH	BP
	PUSH	SI
	PUSH	DI
    ;
	PUSH	DS
	PUSH	ES
	PUSH	CS
	POP	DS
ASSUME	DS:INT13CODE
	CALL	FLUSH_WHOLE_CACHE
	POP	ES
	POP	DS
    ; Simulate POPA
	POP	DI
	POP	SI
	POP	BP
	POP	BX		; Dummy for pop sp
	POP	BX
	POP	DX
	POP	CX
	POP	AX
    ;
	ret
FLUSH_WHOLE_CACHE_SAV ENDP

;**	FLUSH_WHOLE_CACHE -- Flush all dirty cache elements
;
; ENTRY
;	None
; EXIT
;	Cache flushed
; USES
;	AX,BX,CX,DX,ES,SI,DI,FLAGS
;
FLUSH_WHOLE_CACHE PROC NEAR
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	MOV	SI,[CACHE_HEAD]
	INC	SI		; Counter next instruction
FLSH_LP:
	DEC	SI
	CALL	FLUSH_CACHE
	MOV	SI,[SI.FWD_LRU_LNK]
	INC	SI
	JNZ	FLSH_LP
FLUSH_DONE:
	MOV	[DIRTY_CACHE],0 ; No dirty guys in cache
	ret

FLUSH_WHOLE_CACHE ENDP

BREAK	<Drive code for /E driver>

;
; The following label defines the start of the I/O code which is driver type
; specific.
;
; THE TYPE 2 driver must REPLACE this code with code appropriate
;	to the driver type.
;
		EVEN		; Force start of drive code to word boundary

; XMS 0Bh uses the same cache-relative offsets as BLKMOV. INT 13h callers
; supply their own stack, so build the move packet on our resident stack.
; A nested BIOS caller cannot reuse an active XMS transfer stack.
xms_move:
	pushf
	cli
	cmp     cs:[xms_moving],0
	je      xms_enter
	popf
	mov     al,20h
	stc
	ret
xms_enter:
	inc     cs:[xms_moving]
	popf
	mov     si,ss
	mov     bp,sp
	push    cs
	pop     ss
	mov     sp,cs:[xms_stack_top]
	push    si                      ; caller's SS:SP
	push    bp
	or      bh,bh
	jnz     xms_write
	push    es                      ; destination: real-mode buffer
	push    di
	xor     si,si
	push    si
	push    dx                      ; source: cache handle and byte offset
	push    ax
	push    cs:[xms_handle]
	jmp     short xms_transfer
xms_write:
	push    dx                      ; destination: cache
	push    ax
	push    cs:[xms_handle]
	push    es                      ; source: real-mode buffer
	push    di
	xor     si,si
	push    si
xms_transfer:
	xor     dx,dx
	shl     cx,1                    ; word count to DWORD byte count
	adc     dx,dx
	push    dx
	push    cx
	mov     si,sp
	push    cs
	pop     ds
	mov     ah,0bh
	call    cs:[xms_entry]
	add     sp,16
	pop     bp
	pop     ss
	mov     sp,bp
	mov     cs:[xms_moving],0
	cmp     ax,1                    ; AX=0 sets carry
	je      xms_move_done
	mov     al,20h                  ; BIOS controller error
xms_move_done:
	ret

; Transfers use ES:DI, CX words, DX:AX cache offset and BH direction.
; Initialization selects the mover before installing the INT 13h handler.
cache_move      dw      offset xms_move
base_addr       dd      0               ; EMS page frame
above_pid       dw      0               ; EMS allocation handle
BLKMOV:
        jmp     cs:[cache_move]

;**	ABOVE_BLKMOV - Perform transfer for TYPE 2 driver
;
;	This routine is the transfer routine for moving bytes
;	to and from the Above Board memory containing the cache.
;
;	The Above Board is implemented as 4 16K windows into the Above
;	Board memory, giving a total window of 64K wich starts on some
;	16K boundary of the Above Board memory. Given that a DOS I/O
;	request is up to 64K bytes starting on some sector boundary,
;	the most general I/O picture is:
;
;	|------------|------------|------------|------------|------------|
;	| Above Brd  | Above Brd  | Above Brd  | Above Brd  | Above Brd  |
;	|Log page n  |Log page n+1|Log page n+2|log page n+3|Log page n+4|
;	|------------|------------|------------|------------|------------|
;	|---|---|					    |	    |
;	|   |	|---------------- 64K bytes of sectors -------------|
;	   Byte |					    |	    |
;	  offset|------------------|------------------------|	    |
;	of first|	       Number of words in	    |	    |
;	byte of |	       first part of I/O that	    |---|---|
;	I/O in	|	       can be performed once	      Number
;	first	|	       logical pages n - n+3	      of words
;	Log page|	       are mapped into physical       in tail
;		|	       pages 0 - 3		      part of I/O
;	     Location of				      that have
;	     first byte 				      to be done
;	     of sector M,				      once logical
;	     the start sector				      page n+4 is
;	     of the I/O 				      mapped into
;							      physical page
;							      0
;
; One or both of "Byte offset of first byte of I/O in first page" and
; "Number of words in tail part of I/O" may be zero depending on the
; size of the I/O and its start offset in the first logical page it is
; possible to map.
;
; WARNING: IF A PRE-EMPTIVE MULTITASKING SYSTEM SCHEDULES A TASK WHICH
;	IS USING THE ABOVE BOARD DURING THE TIME THIS DRIVER IS IN THE
;	MIDDLE OF PERFORMING AN I/O, THE SYSTEM HAD BETTER MANAGE THE A
;	BOARD MAPPING CONTEXT CORRECTLY OR ALL SORTS OF STRANGE UNPLEASANT
;	THINGS WILL OCCUR.
;
;	SEE ALSO
;	    INTEL Expanded Memory Manager Programming Specification
;
;	ENTRY:
;	    ES:DI is packet transfer address.
;	    CX is number of words to transfer.
;	    DX:AX is 32 bit start byte offset (0 = start of cache)
;	    BH is 1 for WRITE, 0 for READ
;
;	    BASE_ADDR set to point to Above Board mapping window in main memory
;		This "input" is not the responsibility of the caller. It
;		is up to the initialization code to set it up when the
;		device is installed
;
;	EXIT:
;	    Carry Clear
;		    OK, operation performed successfully
;	    Carry Set
;		    Error during operation, AL is error number
;
;	USES:
;	    ALL
;
;	This routine is specific to TYPE 2 driver
;
above_blkmov:
assume ds:int13code,es:nothing,ss:nothing
;
;	save mapping context and return with error if save fails
;
	save_mapping_context
	jnc	ab_blk$1
	ret
;
;	find logical page number, offset of i/o in first page
;
ab_blk$1:
	push	cx
	mov	cx,1024*16	; 16k bytes / page
	div	cx		; dx:ax / 16k --> log page numb in ax
				; 	      --> offset of i/o in dx
	mov	si,dx		; transfer offset to si
	mov	dx,ax		; store the page number in dx
	pop	cx
;
;	find case and dispatch accordingly
;
;	case 0 : user buffer below page map, can use aaron's code
;	case 1 : user buffer above page map, can use aaron's code
;	case 2 : user buffer totally within page map, use pai's code
;	case 3 : user buffer partly in page map partly below, error
;	case 4 : user buffer partly in page map partly above, error
;
	push	bx
	push	cx
;
;	if( final_user_off < pm_base_addr ) then case 0
;
	mov	ax,di		; get user buffer initial offset into ax
	shr	ax,1		; convert to word offset
	dec	cx		; convert word count to 0 based number
	add	ax,cx		; user buffer final word offset
	shr	ax,1		; convert to segment
	shr	ax,1		;
	shr	ax,1		;
	mov	bx,es		; get segment of buffer
	add	ax,bx		; now we have the segment of the user buffer
				; with offset < 16
	sub	ax,word ptr [base_addr+2] ; compare against page map
	jc	aar_cd		; if below page map then execute old code
;
;	if( initial_user_off < pm_base_addr ) then error
;	
	mov	cx,4
	mov	bp,di		; get initial offset in bp
	shr	bp,cl		;
	add	bp,bx		;
	sub	bp,word ptr [base_addr +2]
	jc	ab_error	;
;
;	if ( initial_user_off >= pm_end_addr ) then case1
;
	cmp	bp,4*1024	;
	jae	aar_cd		;
;
;	if ( final_addr >= pm_end_addr ) then error
;
	cmp	ax,4*1024
	jae	ab_error
;
;	case 2
;
within_pm:	jmp	new_code	; user buffer in page map
					; so we need to execute new code
ab_error:
	add	sp,4
	mov	al,0bbh			; general failure
	stc
	jmp	short REST_CONT		; RESTORE CONTEXT!!!
aar_cd:
	pop	cx
	pop	bx
;	
; Referring back to the diagram given above the following routine is
; to take care of transfer of the most general case.
; What this routine does is break every I/O down into the above parts.
; The first or main part of the I/O is performed by mapping 1 to 4
; sequential logical pages into the 4 physical pages and executing one
; REP MOVSW. If the tail word count is non-zero then the fith sequential
; logical page is mapped into physical page 0 and another REP MOVSW is
; executed.
;
;	METHOD:
;	    Break I/O down as described above into main piece and tail piece
;	    Map the appropriate number of sequential pages (up to 4)
;	      into the page window at BASE_ADDR to set up the main piece
;	      of the I/O.
;	   Set appropriate seg and index registers and CX to perform the
;	      main piece of the I/O into the page window
;	   REP MOVSW
;	   IF there is a tail piece
;		Map the next logical page into physical page 0
;		Reset the appropriate index register to point at phsical page 0
;		Move tail piece word count into CX
;		REP MOVSW
;	   Restore Above Board page mapping context
;
	XOR	BP,BP		; No tail page
	PUSH	BX
    ;
    ; DX is first page #, SI is byte offset of start of I/O in first page
    ;
	MOV	AX,DX
	MOV	BX,SI
	SHR	BX,1		; # Words in first 16k page which are not part
				;	of I/O
	PUSH	CX
	ADD	BX,CX		; # of words we need to map to perform I/O
	MOV	DX,BX
	AND	DX,1FFFH	; DX is number of words to transfer last page
				;    remainder of div by words in 16K bytes
	MOV	CL,13		; Div by # words in 16K
	SHR	BX,CL		; BX is number of pages to map (may need round up)
	OR	DX,DX		; Remainder?
	JZ	NO_REM
	INC	BX		; Need one more page
NO_REM:
	MOV	CX,BX		; CX is total pages we need to map
	MOV	BX,AX		; BX is first logical page
	CMP	CX,4		; We can map up to 4 pages
	JBE	NO_TAIL
	MOV	BP,DX		; Words to move in tail page saved in BP
	DEC	CX		; Need second map for the 5th page
	POP	AX
	SUB	AX,DX		; Words to move in first 4 pages is input
				;   word count minus words in tail page
	PUSH	AX		; Count for first mapping back on stack
NO_TAIL:
    ; Map CX pages
	MOV	DX,[ABOVE_PID]
	MOV	AX,ABOVE_MAP SHL 8 ; Physical page 0
	PUSH	AX
MAP_NEXT:
	POP	AX		; Recover correct AX register
	PUSH	AX
	PUSH	BX
	PUSH	DX
	INT	67H		; Damn call ABOVE_MAP zaps BX,DX,AX
	POP	DX
	POP	BX
	OR	AH,AH
	JNZ	MAP_ERR1	; error
IF2
	IF (ABOVE_SUCCESSFUL)
		%out ASSUMPTION IN CODE THAT ABOVE_SUCCESSFUL = 0 IS INVALID
	ENDIF
ENDIF
NEXT_PAGE:
	INC	BX		; Next logical page
	POP	AX
	INC	AL		; Next physical page
	PUSH	AX
	LOOP	MAP_NEXT
	POP	AX		; Clean stack
	POP	CX		; Word count for first page mapping
	POP	AX		; Operation in AH
    ;
    ; BX has # of next logical page (Tail page if BP is non-zero)
    ; BP has # of words to move in tail page (0 if no tail)
    ; CX has # of words to move in current mapping
    ; SI is offset into current mapping of start of I/O
    ; AH indicates READ or WRITE
    ;
	PUSH	AX		; Save op for possible second I/O
	OR	AH,AH
	JZ	READ_A
    ;
    ; WRITE
    ;
	PUSH	ES
	PUSH	DI
	MOV	DI,SI		; Start page offset to DI
	POP	SI		; DS:SI is transfer addr
	POP	DS
ASSUME	DS:NOTHING
	MOV	ES,WORD PTR [BASE_ADDR + 2] ; ES:DI -> start
	JMP	SHORT FIRST_MOVE

READ_A:
ASSUME	DS:INT13CODE
	MOV	DS,WORD PTR [BASE_ADDR + 2]	; DS:SI -> start
ASSUME	DS:NOTHING
FIRST_MOVE:
	REP	MOVSW
	OR	BP,BP		; Tail?
	JNZ	TAIL_IO 	; Yup
ALL_DONE:
	POP	AX
	CLC
REST_CONT:
    ; Restore page mapping context
	PUSH	AX		; Save possible error code
	PUSHF			; And carry state
REST_AGN:
	MOV	DX,[ABOVE_PID]
	MOV	AH,ABOVE_RESTORE_MAP_PID
	INT	67H
	OR	AH,AH
	JZ	ROK
IF2
	IF (ABOVE_SUCCESSFUL)
		%out ASSUMPTION IN CODE THAT ABOVE_SUCCESSFUL = 0 IS INVALID
	ENDIF
ENDIF
	CMP	AH,ABOVE_ERROR_BUSY
	JZ	REST_AGN
	CMP	AH,ABOVE_ERROR_NO_CNTXT
	JZ	ROK		; Ignore the invalid PID error
	POP	DX
	POP	DX		; Clean stack
	MOV	AL,0BBH 	; General failure
	STC
	RET

ROK:
	POPF			; Recover carry state
	POP	AX		; and possible error code
	RET

TAIL_IO:
	MOV	DX,[ABOVE_PID]
MAP_AGN:
	MOV	AX,ABOVE_MAP SHL 8 ; map logical page BX to phys page 0
	PUSH	BX
	PUSH	DX
	INT	67H		; Damn call ABOVE_MAP zaps BX,DX,AX
	POP	DX
	POP	BX
	OR	AH,AH
	JNZ	MAP_ERR2	; Error
IF2
	IF (ABOVE_SUCCESSFUL)
		%out ASSUMPTION IN CODE THAT ABOVE_SUCCESSFUL = 0 IS INVALID
	ENDIF
ENDIF
SECOND_MOVE:
	POP	AX		; Recover Op type
	PUSH	AX
	OR	AH,AH
	JZ	READ_SEC
    ;
    ; WRITE
    ;
	XOR	DI,DI		; ES:DI -> start of tail
	JMP	SHORT SMOVE

READ_SEC:
	XOR	SI,SI		; DS:SI -> start of tail
SMOVE:
	MOV	CX,BP
	REP	MOVSW
	JMP	ALL_DONE

MAP_ERR1:
	CMP	AH,ABOVE_ERROR_BUSY ; Busy?
	JZ	MAP_NEXT	; Yes, wait till not busy (INTs are ON)
	ADD	SP,6		; Clean stack
	JMP	SHORT DNR_ERR

MAP_ERR2:
	CMP	AH,ABOVE_ERROR_BUSY
	JZ	MAP_AGN
	ADD	SP,2
DNR_ERR:
	MOV	AL,0AAH 	; Drive not ready
	STC
	JMP	REST_CONT
;
;
;   this code has been written to handle te cases of overlapping usage
;   of the above board page frame segment by the cache and user buffer
;   assumption: in dos tracks cannot be more than 64 sectors long so
;   in the worst case we shall have the user buffer occupying three
;   pages is the page frame. we attempt to find the page that is
;   available for the cache and use it repeatedly to access the cache
;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
;   the algorithm is:
;   ******************************************************
;   [STEP1: determine the page we can use for the cache]
;
;   if (initial_para_offset_user in page 1 or above ) then  {
;	    physical_cache_page = 0;
;	    cache_segment	= above board segment;
;		}
;						      else  {
;	    physical_cache_page = 3;
;	    cache_segment	= above_board_segment + 3*1024;
;		}
;
;   ******************************************************
;   [STEP2: initial setup]
;
;   count = user_count_requested;
;   number_to_be_transferred = min ( count, (16K - si) >> 2 );
;   exchange source and destination if necessary;
;
;   *******************************************************
;   [STEP3: set up transfer and do it]
;
;   count = count - number_to_be_transferred;
;   map_page cache_handle,physical_cache_page,logical_cache_page
;   mov data
;
;   *******************************************************
;   [STEP4: determine if another transfer needed and setup if so]
;
;   if ( count == 0 ) then exit;
;   if ( operation == read ) then source_offset = 0;
;			     else dest_offset	= 0;
;   number_to_be_transferred = min ( count, 8*1024 );
;   logical_page_number++ ;
;
;   *******************************************************
;   [STEP5: go to do next block]
;
;   goto [STEP3]
;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
;
new_code:
	assume	ds:int13code,es:nothing,ss:nothing
;
;	input parameters:
;
;	bp : start para offset of user buffer in physical page frame
;	ax : end para offset of user buffer in physical page frame
;	di : transfer offset of user buffer
;	es : transfer segment of user buffer
;	dx : logical page number in cache
;	si : offset from start in logical page number
;
;	on stack { cx,bx } where cx = number of words, bx = read / write status
;
;   [STEP1: finding physical cache page and page frame]
;
    ;
    ; assume is physical page 0
    ;
	xor	al,al		; use page 0 for cache
	mov	bx,word ptr [base_addr+2]
    ;
    ; see if this assumption valid
    ;
	cmp	bp,1024 	; is initial in page 1 or above
	jae	ab$30		; if so or assumption is valid
    ;
    ; else we have to correct our assumption
    ;
	mov	al,3		; use page 3 for cache
	add	bx,3*1024	;
    ;
    ; initialise page frame segment
    ;
ab$30:
	mov	ds,bx
    ;
assume	ds:nothing
;
;   [STEP2: initialising transfer parameters]
;
    ;
	pop	bp		; bp will have count of words left to be transferred
	pop	bx		; read / write status
	push	bx		; save it back again
	push	dx		; save this too
    ;
    ; initially si offset into logical page, so we can only do 16*1024 - si
    ; byte transfer
    ;
	mov	cx,16*1024
	sub	cx,si
	shr	cx,1		; convert to word count
    ;
    ;	number to be transferred is the minimum of this and the user requested
    ;	count
    ;
	cmp	cx,bp
	jb	ab$31
	mov	cx,bp
    ;
ab$31:
    ;
    ;	see if write, then we have to switch source with destination
    ;
	or	bh,bh
	je	ab$32		; if read we don't have to do anything
				; else we have to switch
	src_dest_switch
ab$32:
    ;
    ;	set direction flag so that we don't have to do it repeatedly
    ;
	cld
;
;   [STEP3: set up transfer and do it]
;
ab$33:
    ;
    ;	update count of words still left to be transferred after this
    ;
	sub	bp,cx
    ;
    ;	map the logical page in cache to the physical page  selected
    ;
	mov	bx,dx		; get logical page into bx
				; al already holds the physical page #
	map_page
	jnc	ab$34		; suceeded ?
    ;
    ; else report error
    ;
	add	sp,4
	stc
	jmp	short restore_mp ; and go to restore page map
ab$34:
    ;
    ; succeeded, do the transfer
    ;
rep	movsw
    ;
;
;   [STEP4: check if transfer done, if not set up for next block]
;   [STEP5: go back to STEP3]
    ;
    ; check if done
    ;
	or	bp,bp		; count 0
	je	ab$40		; yes, go to finish up
    ;
    ;	recover original dx and bx, increment dx and then save both again
    ;
	pop	dx
	pop	bx
	inc	dx
	push	bx
	push	dx
    ;
    ; words to be transferred minimum of count and 8*1024 words
    ;
	mov	cx,8*1024	; 8k words in a page
	cmp	cx,bp		;
	jbe	ab$35		; if below or equal this is what we want
    ;
	mov	cx,bp		; else we can transfer the whole count
ab$35:
    ;
    ; see whether cache src or dest and accordingly reset either si or di
    ;
	or	bh,bh		; read?
	jne	ab$36		; if write go to modify
    ;
    ; read, zero si and go back to step3
    ;
	xor	si,si
	jmp	short ab$33	; to step 3
ab$36:
    ;
    ; write, zero di and go back to step3
    ;
	xor	di,di
	jmp	short ab$33	; to step 3
;
; finishing up we have to restore the page map
;
ab$40:
	add	sp,4
	clc
restore_mp:
	restore_mapping_context
	ret


BREAK	<INT 19/9 Handlers>

;
; On INT 19h release the selected manager handle and restore the BIOS chain.
;
; Storage locations for the "next" INT 19 and INT 9 vectors, the ones
;  that were in the interrupt table when the device driver was loaded.
;  They are initialized to -1 to indicate they contain no useful information.
;
OLD_19	LABEL	DWORD
	DW	-1
	DW	-1

OLD_9	LABEL	DWORD
	DW	-1
	DW	-1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; modification to meet new memory allocation standard
;**	INT 9 Keyboard handler
;
;	All this piece of code does is look for the Ctrl-Alt-Del event.
;	If key is not Ctrl-Alt-Del, it jumps to OLD_9 without doing
;	anything. If the Ctrl-Alt-Del key is detected it calls
;	RESET_SYSTEM to perform driver TYPE specific re-boot code.
;	It then resets INT 13H to disable the cache and then jumps to
;	OLD_9 to pass on the event.
;
;	NOTE THAT UNLIKE INT 19 THIS HANDLER DOES NOT NEED TO RESET
;	THE INT 9 AND INT 19 VECTORS. This is because the Ctrl-Alt-Del
;	IBM ROM re-boot code resets these vectors.
;
;	We would LIKE to ALSO flush the cache, but we can't. For one the
;	keyboard is at a higher IRQ than the disk. We could EOI the keyboard,
;	but this doesn't fix the second problem. INT 13s to write
;	out any dirty tracks take a LONG time, so long that we lose
;	the key. In other words we see Ctrl-Alt-Del, but none of the
;	INT 9 handlers after us will.
;
;
;	SEE ALSO
;	    INT 9 IBM ROM code in ROM BIOS listing of
;	    IBM PC Technical Reference manual for any PC family member
;
;	ENTRY
;	    NONE
;	EXIT
;	    NONE, via OLD_9
;	USES
;	    FLAGS
;
;	THIS CODE IS USED BY TYPE 1,2 drivers.
;

INT_9:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	PUSH	AX
	PUSH	DS
	IN	AL,60H
	CMP	AL,83			; DEL key?
	JNZ	CHAIN			; No
	XOR	AX,AX
	MOV	DS,AX
	MOV	AL,BYTE PTR DS:[417H]	; Get KB flag
	NOT	AL
	TEST	AL,0CH			; Ctrl Alt?
	JNZ	CHAIN			; No
	MOV	[INT_13_BUSY],1 	; Exclude
;
; We would LIKE to do this, always but we can't. For one the keyboard
;   is at a higher IRQ than the disk. We can EOI the keyboard,
;   but this doesn't fix the second problem. INT 13s to write
;   out any dirty tracks take a LONG time, so long that we loose
;   the key. In other words we see Ctrl-Alt-Del, but none of the
;   INT 9 handlers after us will.
;
	CMP	[REBOOT_FLUSH],0	; Reboot flush enabled?
	JZ	NO_REBOOT_FLUSH 	; No
	CMP	[DIRTY_CACHE],0 	; Anything to do?
	JZ	NO_REBOOT_FLUSH 	; No
	MOV	AL,20H
	OUT	20H,AL			; EOI the keyboard int
	CALL	FLUSH_WHOLE_CACHE_SAV	; Flush cache
NO_REBOOT_FLUSH:
;
	CALL	RESET_SYSTEM		; Ctrl Alt DEL
    ;
    ; Reset INT 13 vector to turn cache off
    ;
	MOV	AX,WORD PTR [OLD_13]
	CLI
	MOV	WORD PTR DS:[13H * 4],AX
	MOV	AX,WORD PTR [OLD_13 + 2]
	MOV	WORD PTR DS:[(13H * 4) + 2],AX
    ;
    ; Reset INT 1C vector to turn cache off
    ;
;	MOV	AX,WORD PTR [OLD_1C]
;	MOV	WORD PTR DS:[1CH * 4],AX
;	MOV	AX,WORD PTR [OLD_1C + 2]
;	MOV	WORD PTR DS:[(1CH * 4) + 2],AX
	MOV	[INT_13_BUSY],0
CHAIN:
	POP	DS
	POP	AX
	JMP	[OLD_9]

;**	INT 19 Software re-boot handler
;
;	All this piece of code does is sit on INT 19 waiting for
;	a re-boot to be signaled by being called. It calls
;	FLUSH_WHOLE_CACHE_SAV to flush out any dirty cache info then
;	RESET_SYSTEM to perform driver TYPE specific re-boot code,
;	resets the INT 19, INT 13 and INT 9 vectors,
;	and then jumps to OLD_19 to pass on the event.
;
;	NOTE THAT UNLIKE INT 9 THIS HANDLER NEEDS TO RESET
;	THE INT 9 AND INT 19 VECTORS. This is because the INT 19
;	IBM ROM re-boot code DOES NOT reset these vectors, and we
;	don't want to leave them pointing to routines that are not
;	protected from getting stomped on by the re-boot.
;
;	SEE ALSO
;	    INT 19 IBM ROM code in ROM BIOS listing of
;	    IBM PC Technical Reference manual for any PC family member
;
;	ENTRY
;	    NONE
;	EXIT
;	    NONE, via OLD_19
;	USES
;	    FLAGS
;
;	THIS CODE IS USED BY TYPE 1,2 drivers.
;

INT_19:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	MOV	[INT_13_BUSY],1 	; Exclude
	cmp	[reboot_flush],0	;
	je	no_flush
	CALL	FLUSH_WHOLE_CACHE_SAV	; Flush out the cache
no_flush:
	CALL	RESET_SYSTEM
	PUSH	AX
	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX
	MOV	AX,WORD PTR [OLD_13]
	CLI
    ;
    ; Reset INT 13 vector to trun cache off
    ;
	MOV	WORD PTR DS:[13H * 4],AX
	MOV	AX,WORD PTR [OLD_13 + 2]
	MOV	WORD PTR DS:[(13H * 4) + 2],AX
    ;
    ; Reset INT 1C vector to turn cache off
    ;
;	MOV	AX,WORD PTR [OLD_1C]
;	MOV	WORD PTR DS:[1CH * 4],AX
;	MOV	AX,WORD PTR [OLD_1C + 2]
;	MOV	WORD PTR DS:[(1CH * 4) + 2],AX
    ;
    ; Since INT 19 DOES NOT reset any vectors (like INT 9 Ctrl Alt DEL does),
    ;	we must replace those vectors we have mucked with.
    ;
    ; NOTE THAT WE RESET VECTORS DIRECTLY!!!!!!!!!!!!!!!!!!
    ;	We are not sure that DOS is reliable enough to call.
    ;
	MOV	AX,WORD PTR [OLD_19]
	MOV	WORD PTR DS:[19H * 4],AX
	MOV	AX,WORD PTR [OLD_19 + 2]
	MOV	WORD PTR DS:[(19H * 4) + 2],AX
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   removed from smartdrv
;	MOV	AX,WORD PTR [OLD_9]
;	MOV	WORD PTR DS:[9H * 4],AX
;	MOV	AX,WORD PTR [OLD_9 + 2]
;	MOV	WORD PTR DS:[(9H * 4) + 2],AX
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	POP	DS
	POP	AX
	MOV	[INT_13_BUSY],0
	JMP	[OLD_19]

; Release the cache when bootstrapping again through INT 19h.
RESET_SYSTEM:
        push    ax
        push    bx
        push    dx
        cmp     cs:[driver_sel],1
        je      reset_ems
        mov     dx,cs:[xms_handle]
        mov     ah,0ah
        call    cs:[xms_entry]
        jmp     short reset_done
reset_ems:
        mov     dx,cs:[above_pid]
        mov     ah,ABOVE_DEALLOC
        int     67h
        cmp     ah,ABOVE_ERROR_BUSY
        je      reset_ems
reset_done:
        pop     dx
        pop     bx
        pop     ax
        ret

; This data is only used at INIT, but it must be protected from overwrite
;  by the DO_INIT code.
;
TERM_ADDR	LABEL	DWORD	; Address to return as break address in INIT packet
		DW	?	; Computed at INIT time
		DW	?	; INT13 CS filled in at INIT

;
; THIS CODE MUST BE IN RESIDENT PORTION BECAUSE IT WRITES IN THE AREA
;  OCCUPIED BY THE DISPOSABLE INIT CODE.
;

;**	DO_INIT - Initialize cache structures to "empty"
;
DO_INIT:
ASSUME	DS:INT13CODE
	MOV	AX,[SECTRACK]
	MOV	CL,9
	SHL	AX,CL			; AX is bytes per track buffer
	MOV	BX,[CACHE_CONTROL_PTR]
	MOV	CX,[TTRACKS]
	MOV	[CACHE_HEAD],BX
	MOV	[BX.BACK_LRU_LNK],-1
	MOV	WORD PTR [BX.BASE_OFFSET],0
	MOV	WORD PTR [BX.BASE_OFFSET+2],0
	MOV	[BX.TRACK_FLAGS],TRACK_FREE
	MOV	DI,BX
	ADD	BX,SIZE CACHE_CONTROL	; Next structure
	DEC	CX			; One less to do
	JCXZ	SETDONE 		; one buffer in cache
SETLOOP:
	MOV	[DI.FWD_LRU_LNK],BX
	MOV	[BX.BACK_LRU_LNK],DI
	MOV	[BX.TRACK_FLAGS],TRACK_FREE
	MOV	DX,WORD PTR [DI.BASE_OFFSET]
	ADD	DX,AX
	MOV	WORD PTR [BX.BASE_OFFSET],DX
	MOV	DX,WORD PTR [DI.BASE_OFFSET+2]
	ADC	DX,0
	MOV	WORD PTR [BX.BASE_OFFSET+2],DX
	MOV	DI,BX
	ADD	BX,SIZE CACHE_CONTROL	; Next structure
	LOOP	SETLOOP
SETDONE:
	MOV	[DI.FWD_LRU_LNK],-1
	MOV	[CACHE_TAIL],DI 	; That is the tail
;
;	NOTE FALL THROUGH!!!!!!!
;

;**	SETBPB - Set INIT packet I/O return values
;
;	This entry is used to set the INIT packet Break address
;
;	ENTRY
;	    TERM_ADDR set to device end
;	EXIT
;	    through DEVEXIT
;	USES
;	    DS, BX, CX
;
;	COMMON TO TYPE 1, 2 drivers
;

SETBPB:
ASSUME	DS:NOTHING
    ;
    ; 7.  Set the return INIT I/O packet values
    ;
	LDS	BX,[PTRSAV]
	MOV	CX,WORD PTR [TERM_ADDR]
	MOV	WORD PTR [BX.INIT_BREAK],CX		   ;SET BREAK ADDRESS
	MOV	CX,WORD PTR [TERM_ADDR + 2]
	MOV	WORD PTR [BX.INIT_BREAK + 2],CX
	JMP	DEVEXIT


	EVEN			; Make sure we get word alignment of the track
				;    buffer.

;
; The following items define the "track buffer". When we want to I/O a track
;    this is where we do it. We cannot I/O the track directly into extended
;    memory because we have no way to specify a 24 bit address to INT 13. We
;    Cannot I/O direct to expanded memory because DMA into the expanded memory
;    window is not supported. This buffer also "holds" one track, so we keep
;    track of the last track that was in here because it is faster to access
;    it here than through extended/expanded memory. A value of -1 in the
;    "currency" fields indicates that there is currently nothing interesting
;    in the track buffer. NOTE: It is ASSUMED that the track buffer always
;    represents a track that is IN the cache, therefore one must be sure to
;    invalidate the track buffer when the cache element it represents is
;    discarded. Runtime transfers address the track at TRACK_SEGMENT:0.
;    Initialization places the track buffer so
;    that it does not cause a DMA Boundary error which would slow things
;    down quite a bit.
;

;
; Cylinder and hd/drv of track in track buffer
;
TRACK_BUFFER_CYLN	DW	-1
TRACK_BUFFER_HDDR	DW	-1

;
; Pointer to track buffer. May be adjusted for DMA boundary error prevention.
;
TRACK_SEGMENT DW 0		; full track at segment:0

;
; Cache structure pointers
;

;
; Pointer to cache structures. The cache entries reuse discardable initialization space.
;
CACHE_CONTROL_PTR DW	?

;
; Cache head and tail pointers
;
CACHE_HEAD	DW	?
CACHE_TAIL	DW	?

;
; Cache controls reuse disposable initialization space after this point.
TRACK_BUFFER LABEL BYTE

BREAK	<COMMON INIT CODE>

;**	DISPOSABLE INIT DATA
;
; INIT data which need not be part of resident image
;

NUM_ARG 	DB	1	; Counter for numeric
				;    arguments	bbbb.

GOTSWITCH	DB	0	; Bit map of switches seen

 SWITCH_E	 EQU	 00000001B
 SWITCH_A	 EQU	 00000010B   ; Only switch allowed
 SWITCH_T	 EQU	 00000100B
 SWITCH_D	 EQU	 00001000B
 SWITCH_WT	 EQU	 00010000B
 SWITCH_WC	 EQU	 00100000B
 SWITCH_R	 EQU	 01000000B
 SWITCH_C	 EQU	 10000000B
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;**	PRINT - Print a "$" terminated message on stdout
;
;	This routine prints "$" terminated messages on stdout.
;	It may be called with only the DX part of the DS:DX message
;	pointer set, the routine puts the correct value in DS to point
;	at the INT13 messages.
;
;	ENTRY:
;	     DX pointer to "$" terminated message (INT13CODE relative)
;	EXIT:
;	     NONE
;	USES:
;	     AX
;
;	COMMON TO TYPE 1, 2, 3, 4 drivers
;

PRINT:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	PUSH	DS
	PUSH	CS
	POP	DS
	MOV	AH,Std_Con_String_Output
	INT	21H
	POP	DS
	RET

;**	ITOA - Print Decimal Integer on stdout
;
;	Print an unsigned 16 bit value as a decimal integer on stdout
;	with leading zero supression. Prints from 1 to 5 digits. Value
;	0 prints as "0".
;
;	Routine uses divide instruction and a recursive call. Maximum
;	recursion is four (five digit number) plus one word on stack
;	for each level.
;
;	ENTRY	AX has binary value to be printed
;	EXIT	NONE
;	USES	AX,CX,DX,FLAGS
;
;	COMMON TO TYPE 1, 2, 3, 4 drivers
;

ITOA:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING

	MOV	CX,10
	XOR	DX,DX
	DIV	CX			; DX is low digit, AX is higher digits
	OR	AX,AX
	JZ	PRINT_THIS_DIGIT	; No more higher digits
	PUSH	DX			; Save this digit
	CALL	ITOA			; Print higher digits first
	POP	DX			; Recover this digit
PRINT_THIS_DIGIT:
	ADD	DL,"0"			; Convert to ASCII
	MOV	AH,Std_CON_Output
	INT	21H
	RET


;**	INT13$INIT - Device Driver Initialization routine
;
; Validate the command line and BIOS geometry, then allocate the selected
; cache and its DMA-safe conventional track buffer. Install the vectors only
; after allocation and layout succeed. DOS discards the driver on failure.

INT13$INIT:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
    ;
    ; 1.  Initialize various global values
    ;
	MOV	WORD PTR [TERM_ADDR + 2],CS
    ;
    ; 2.  Check for correct DOS version and do changes to the device
    ;	     based on the DOS version if needed.
    ;
	CLD
	MOV	AH,GET_VERSION
	INT	21H
	XCHG	AH,AL
	CMP	AX,(2 SHL 8) + 00
	JB	BADVER			; Below 2.00, BAD
	CMP	AX,(3 SHL 8) + 00
	JB	VER2X			; 2.X requires some patches
	CMP	AX,(4 SHL 8) + 00
	JBE	VER_OK			; 3.X or 4.0 OK
BADVER:
	MOV	DX,OFFSET BADVERMES
	JMP	DEVABORT

VER2X:
	AND	[DEVATS],NOT DEVOPCL	    ; No such bit in 2.X
	MOV	BYTE PTR [INT13TBL],11	    ; Fewer functions too
VER_OK:

;;
; 3.  Set OLD_13, OLD_1C and Parse the command line and set values accordingly
;
	MOV	AX,(Get_Interrupt_Vector SHL 8) OR 13H
	INT	21H
	MOV	WORD PTR [OLD_13],BX
	MOV	WORD PTR [OLD_13 + 2],ES
	MOV	AX,(Get_Interrupt_Vector SHL 8) OR 1CH
	INT	21H
	MOV	WORD PTR [OLD_1C],BX
	MOV	WORD PTR [OLD_1C + 2],ES
	LDS	SI,[PTRSAV]
ASSUME	DS:NOTHING
	MOV	DX,OFFSET HEADERMES
	CALL	PRINT
	LDS	SI,[SI.INIT_BPB]    ; DS:SI points to config.sys
SKIPLP1:			    ; Skip leading delims to start of name
	LODSB
	CMP	AL," "
	JZ	SKIPLP1
	CMP	AL,9
	JZ	SKIPLP1
	CMP	AL,","
	JZ	SKIPLP1
	JMP	SHORT SKIPNM

ARGS_DONEJ:
	JMP	ARGS_DONE

SWITCHJ:
	JMP	SWITCH

SKIPLP2:			; Skip over device name
	LODSB
SKIPNM:
	CMP	AL,13
	JZ	ARGS_DONEJ
	CMP	AL,10
	JZ	ARGS_DONEJ
	CMP	AL," "
	JZ	FIRST_ARG
	CMP	AL,9
	JZ	FIRST_ARG
	CMP	AL,","
	JZ	FIRST_ARG
	CMP	AL,0		; Need this for 2.0 2.1
	JNZ	SKIPLP2
SCAN_LOOP:			; PROCESS arguments
	LODSB
FIRST_ARG:
	OR	AL,AL		; Need this for 2.0 2.1
	JZ	ARGS_DONEJ
	CMP	AL,13
	JZ	ARGS_DONEJ
	CMP	AL,10
	JZ	ARGS_DONEJ
	CMP	AL," "
	JZ	SCAN_LOOP
	CMP	AL,9
	JZ	SCAN_LOOP
	CMP	AL,","
	JZ	SCAN_LOOP
	CMP	AL,"/"
	JZ	SWITCHJ
	CMP	AL,"0"
	JB	BAD_PARMJ
	CMP	AL,"9"
	JA	BAD_PARMJ
	DEC	SI
	CALL	GETNUM
	CMP	[NUM_ARG],1
	JA	BAD_PARMJ		 ; Only 1 numeric argument
SET_SIZE:
	CMP	BX,128
	JB	BAD_PARMJ
	CMP	BX,8192
	JA	BAD_PARMJ
	MOV	[DEV_SIZE],BX
;A
	mov	[current_dev_size],bx
;A
	JMP	SHORT NUM_DONE

BAD_PARMJ:
	JMP	SHORT BAD_PARM

NUM_DONE:
	INC	[NUM_ARG]		; Next numeric argument
SCAN_LOOPJ:
	JMP	SCAN_LOOP

BAD_PARM:
	MOV	DX,OFFSET ERRMSG1
DEVABORT:
	CALL	PRINT
DEVABORT_NOMES:
;	INC	[NULDEV]		;Indicate NUL device
;	MOV	WORD PTR [TERM_ADDR],OFFSET ERROR_END ;Minimul null device
;	JMP	SETBPB			;and return
	LDS	BX,[PTRSAV]
	MOV	WORD PTR [BX].INIT_NUM,0
	MOV	WORD PTR [BX].INIT_BREAK[0],0
	MOV	WORD PTR [BX].INIT_BREAK[2],CS
	MOV	[DEVATS],0
	JMP	DEVEXIT

SWITCH:
	LODSB
	OR	AL,20H

if WINDOWS_SWITCHES eq 0
	CMP	AL,"e"
	JNZ	ABOVE_TEST
EXT_SET:
	TEST	[GOTSWITCH],SWITCH_E + SWITCH_A
	JNZ	BAD_PARM
	OR	[GOTSWITCH],SWITCH_E
	MOV	[DRIVER_SEL],0
	JMP	SCAN_LOOP

ABOVE_TEST:

endif	; WINDOWS_SWITCHES eq 0

	CMP	AL,"a"

if WINDOWS_SWITCHES
	jnz	bad_parm
else
	JNZ	DIS_TEST
endif	;WINDOWS_SWITCHES

ABOVE_SET:
	TEST	[GOTSWITCH],SWITCH_A	; Was SWITCH_E + SWITCH_A
	JNZ	BAD_PARM
	OR	[GOTSWITCH],SWITCH_A
	MOV	[DRIVER_SEL],1
	JMP	SCAN_LOOP

if WINDOWS_SWITCHES eq 0

DIS_TEST:
	CMP	AL,"d"
	JNZ	W_TEST
DIS_SET:
	TEST	[GOTSWITCH],SWITCH_D
	JNZ	BAD_PARM
	OR	[GOTSWITCH],SWITCH_D
	MOV	[ENABLE_13],0
	JMP	SCAN_LOOP

W_TEST:
	CMP	AL,"w"
	JNZ	T_TEST
	LODSW
	OR	AL,20H
	CMP	AX,":c"
	JNZ	WT_TEST
	LODSW
	OR	AX,2020H
	CMP	AX,"fo"
	JNZ	BAD_PARM
	LODSB
	OR	AL,20H
	CMP	AL,"f"
	JNZ	BAD_PARMJX
WC_SET:
	TEST	[GOTSWITCH],SWITCH_WC
	JNZ	BAD_PARMJX
	OR	[GOTSWITCH],SWITCH_WC
	MOV	[WRITE_BUFF],0
	JMP	SCAN_LOOP

WT_TEST:
	CMP	AX,":t"
	JNZ	BAD_PARMJX
	LODSW
	OR	AX,2020H
	CMP	AX,"no"
	JNZ	BAD_PARMJX
WT_SET:
	TEST	[GOTSWITCH],SWITCH_WT
	JNZ	BAD_PARMJX
	OR	[GOTSWITCH],SWITCH_WT
	MOV	[WRITE_THROUGH],1
	JMP	SCAN_LOOP

BAD_PARMJX:
	JMP	BAD_PARM

T_TEST:
	CMP	AL,"t"
	JNZ	R_TEST
	LODSW
	CMP	AL,":"
	JNZ	BAD_PARMJX
	CMP	AH,"0"
	JB	BAD_PARMJX
	CMP	AH,"9"
	JA	BAD_PARMJX
	DEC	SI
	CALL	GETNUM
T_SET:
	TEST	[GOTSWITCH],SWITCH_T
	JNZ	BAD_PARMJX
	OR	[GOTSWITCH],SWITCH_T
	MOV	[TICK_SETTING],BX
	JMP	SCAN_LOOP

R_TEST:
	CMP	AL,"r"
	JNZ	C_TEST
	LODSW
	OR	AH,20H
	CMP	AX,"o:"
	JNZ	BAD_PARMJX
	LODSB
	OR	AL,20H
	CMP	AL,"n"
	JNZ	BAD_PARMJX
	TEST	[GOTSWITCH],SWITCH_R
	JNZ	BAD_PARMJX
	OR	[GOTSWITCH],SWITCH_R
	MOV	[REBOOT_FLUSH],1
	JMP	SCAN_LOOP

C_TEST:
	CMP	AL,"c"
	JNZ	BAD_PARMJX
	LODSW
	OR	AH,20H
	CMP	AX,"o:"
	JNZ	BAD_PARMJX
	LODSB
	OR	AL,20H
	CMP	AL,"n"
	JNZ	BAD_PARMJX
	TEST	[GOTSWITCH],SWITCH_C
	JNZ	BAD_PARMJX
	OR	[GOTSWITCH],SWITCH_C
	MOV	[ALL_CACHE],1
	JMP	SCAN_LOOP
endif	;WINDOWS_SWITCHES eq 0

ARGS_DONE:
;
; 4.  Call a TYPE specific INIT routine based on the Parse
;	 to set up a specific driver TYPE.
;
	PUSH	CS
	POP	DS
ASSUME	DS:INT13CODE
	call	get_geometry
	jc	ini_ret
	MOV	AL,[DRIVER_SEL] 	; Find out which init to call
	OR	AL,AL
	JNZ	NEXTV
	CALL	XMS_INIT
	JMP	SHORT INI_RET

NEXTV:
	CALL	ABOVE_INIT
INI_RET:
	JNC	I001
	JMP	DEVABORT_NOMES

I001:
DRIVE_SET:
	call	set_reset
    ;
    ; update the current device size
    ;
	mov	ax,[dev_size]
	mov	[current_dev_size],ax
    ;
    ; 6.  Print out report of INT13 parameters
    ;
	MOV	DX,OFFSET STATMES1
	CALL	PRINT
	MOV	AX,[DEV_SIZE]
	CALL	ITOA
	MOV	DX,OFFSET STATMES1E
	CMP	[DRIVER_SEL],0
	JZ	PTYPX
	MOV	DX,OFFSET STATMES1A
PTYPX:
	CALL	PRINT
	MOV	DX,OFFSET STATMES2
	CALL	PRINT
	MOV	AX,[TTRACKS]
	CALL	ITOA
	MOV	DX,OFFSET STATMES3
	CALL	PRINT
	MOV	AX,[SECTRACK]
	CALL	ITOA
	MOV	DX,OFFSET STATMES4
	CALL	PRINT

ifdef	OMTI
	mov	dx,offset omti_msg
	call	print
endif
IF DEBUG
	MOV	DX,OFFSET STATMES5
	CALL	PRINT
	MOV	AX,CS
	CALL	ITOA
	MOV	DX,OFFSET STATMES6
	CALL	PRINT
ENDIF
    ;
    ; Turn on the cache by chaining INT 13, and INT 1C
    ;
	MOV	DX,OFFSET INT_13_HANDLER
	MOV	AX,(Set_Interrupt_Vector SHL 8) OR 13H
	INT	21H
;	MOV	DX,OFFSET INT_1C_HANDLER
;	MOV	AX,(Set_Interrupt_Vector SHL 8) OR 1CH
;	INT	21H
	JMP	DO_INIT

;**	DRIVEPARMS Initialize drive related cache parameters
;
;	ENTRY
;	    Stuff set so that BLKMOV can be used to access cache memory
;	    DEV_SIZE set to TRUE cache size in K
;	EXIT
;	    Carry Set
;		Error, message already printed
;	    Carry clear
;		TRACK_SEGMENT adjusted for DMA error prevention
;		CACHE_CONTROL_PTR set
;		TERM_ADDR set
;		TTRACKS set
;		SECTRACK set
;		SECTRKARRAY set
;		HDARRAY set (SUNILP)
;	USES
;	    ALL but DS
;
;	COMMON TO TYPE 1, 2 drivers
;
;
NO_HARDFILES:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	MOV	DX,OFFSET NOHARD
PEER:
	CALL	PRINT
	STC
	RET

TRACK_TOO_BIG:
	MOV	DX,OFFSET BIGTRACK
	JMP	PEER

GET_GEOMETRY:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
    ;
    ; First figure out sec/track of any hardfiles
    ;
	MOV	DL,80H
	MOV	AH,8
	INT	13H
	JC	NO_HARDFILES
	OR	DL,DL
	JZ	NO_HARDFILES
	AND	CL,00111111B
	MOV	[SECTRKARRAY],CL
	mov	[hdarray],dh
	XOR	CH,CH
	JCXZ	TRACK_TOO_BIG
	MOV	[SECTRACK],CX
	MOV	CL,DL
	DEC	CX
	JCXZ	FINISHED
	CMP	CX,MAX_HARD_FILES - 1
	JBE	DNUM_OK
	MOV	CX,MAX_HARD_FILES - 1
DNUM_OK:
	MOV	DL,81H
PARMLOOP:
	PUSH	CX
	PUSH	DX
	MOV	AH,8
	INT	13H
	JC	IGNORE_DRIVE
	AND	CL,00111111B
	POP	BX
	PUSH	BX
	AND	BX,0000000001111111B
	MOV	[BX.SECTRKARRAY],CL
	mov	[bx.hdarray],dh
	XOR	CH,CH
	CMP	CX,[SECTRACK]
	JBE	IGNORE_DRIVE
	MOV	[SECTRACK],CX
IGNORE_DRIVE:
	POP	DX
	INC	DL
	POP	CX
	LOOP	PARMLOOP
FINISHED:
	clc
	ret

DRIVEPARMS:
    ;
    ; Figure out number of full tracks that fit in cache
    ;
	MOV	AX,[SECTRACK]
	MOV	CX,512
	MUL	CX		; DX:AX = Bytes per track
	OR	DX,DX
	JNZ	TRACK_TOO_BIG
	MOV	BX,AX		; BX is bytes per track
	MOV	AX,[DEV_SIZE]
	MOV	CX,1024
	MUL	CX		; DX:AX = size of cache in bytes
	DIV	BX		; AX is full tracks in cache
	MOV	[TTRACKS],AX
    ; Keep the near-linked cache entries inside CS. Place the track itself
    ; after them at a paragraph boundary. Align to the next DMA page only
    ; if the BIOS transfer would cross a physical 64 KiB boundary.
	or      ax,ax
	jz      layout_error
	mov     [cache_control_ptr],offset track_buffer
	mov     cx,size cache_control
	mul     cx
	or      dx,dx
	jnz     layout_error
	add     ax,offset track_buffer
	jc      layout_error
	cmp     [xms_handle],0
	je      round_layout
	add     ax,xms_stack_size
	jc      layout_error
	and     ax,0fffeh
	mov     [xms_stack_top],ax
round_layout:
	add     ax,15
	jc      layout_error
	mov     cl,4
	shr     ax,cl
	mov     dx,cs
	add     ax,dx
	jc      layout_error
	mov     dx,ax
	and     dx,0fffh              ; paragraph offset within the DMA page
	mov     bx,[sectrack]
	mov     cl,5
	shl     bx,cl                 ; paragraphs in a track
	add     dx,bx
	cmp     dx,1000h
	jbe     track_fits
	or      ax,0fffh
	inc     ax
	jz      layout_error
track_fits:
	mov     [track_segment],ax
	add     ax,bx
	jc      layout_error
	; DOS 4 supplies its allocation ceiling in the INIT request.
	les     di,[ptrsav]
	cmp     word ptr es:[di.init_break],0
	jne     publish_layout
	cmp     word ptr es:[di.init_break+2],0
	je      publish_layout
	cmp     ax,word ptr es:[di.init_break+2]
	ja      layout_error
publish_layout:
	mov     word ptr [term_addr+2],ax
	mov     word ptr [term_addr],0
	CLC
	RET

layout_error:
	mov     dx,offset errmsg2
	jmp     peer

;**	GETNUM - Read an unsigned integer
;
;	This routine looks at DS:SI for a decimal unsigned integer.
;	It is up to the caller to make sure DS:SI points to the start
;	of a number. If it is called without DS:SI pointing to a valid
;	decimal digit the routine will return 0. Any non decimal digit
;	defines the end of the number and SI is advanced over the
;	digits which composed the number. Leading "0"s are OK.
;
;	THIS ROUTINE DOES NOT CHECK FOR NUMBERS LARGER THAN WILL FIT
;	IN 16 BITS. If it is passed a pointer to a number larger than
;	16 bits it will return the low 16 bits of the number.
;
;	This routine uses the MUL instruction to multiply the running
;	number by 10 (initial value is 0) and add the numeric value
;	of the current digit. Any overflow on the MUL or ADD is ignored.
;
;	ENTRY:
;	     DS:SI -> ASCII text of number
;	EXIT:
;	     BX is binary for number
;	     SI advanced to point to char after number
;	USES:
;	     AX,BX,DX,SI
;
;	COMMON TO TYPE 1, 2, 3, 4 drivers
;

GETNUM:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING

	XOR	BX,BX
GETNUM1:
	LODSB
	SUB	AL,"0"
	JB	NUMRET
	CMP	AL,9
	JA	NUMRET
	CBW
	XCHG	AX,BX
	MOV	DX,10
	MUL	DX
	ADD	BX,AX
	JMP	GETNUM1

NUMRET:
	DEC	SI
	RET

;**	SET_RESET - Set up INT 19/INT 9 vectors
;
;	This routine will install the INT 9 and INT 19
;	code by saving the current INT 9 and INT 19
;	vectors in OLD_9 and OLD_19 (NOTE: the change in the value of OLD_19
;	to something other than -1 indicates that the vectors have been
;	replaced), setting the vectors to point to INT_9 and INT_19.
;
;	ENTRY:
;	     NONE
;	EXIT:
;	     NONE
;	USES:
;	     None
;
;	COMMON TO TYPE 1, 2 drivers
;

SET_RESET:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
	PUSH	AX
	PUSH	DX
	PUSH	BX
	PUSH	ES
	MOV	AX,(Get_Interrupt_Vector SHL 8) OR 19H
	INT	21H
	MOV	WORD PTR [OLD_19],BX
	MOV	WORD PTR [OLD_19 + 2],ES
	MOV	DX,OFFSET INT_19
	MOV	AX,(Set_Interrupt_Vector SHL 8) OR 19H
	INT	21H
	MOV	AX,(Get_Interrupt_Vector SHL 8) OR 9H
	INT	21H
	MOV	WORD PTR [OLD_9],BX
	MOV	WORD PTR [OLD_9 + 2],ES
;	MOV	DX,OFFSET INT_9
;	MOV	AX,(Set_Interrupt_Vector SHL 8) OR 9H
;	INT	21H
	POP	ES
	POP	BX
	POP	DX
	POP	AX
RET005:
	RET

BREAK	</E INIT Code>

; Acquire one XMS block for the cache. A provider may implement only UMBs.
; On a geometry or layout error return the block before DOS finishes INIT.
XMS_INIT:
ASSUME DS:INT13CODE,ES:NOTHING,SS:NOTHING
	mov     ax,4300h
	int     2fh
	cmp     al,80h
	jne     xms_missing
	mov     ax,4310h
	int     2fh
	mov     word ptr [xms_entry],bx
	mov     word ptr [xms_entry+2],es
	mov     ah,08h
	call    [xms_entry]
	or      ax,ax
	jnz     xms_size
	cmp     bl,80h                  ; a UMB-only provider has no EMBs
	je      xms_missing
xms_no_space:
	mov     dx,offset errmsg2
	jmp     short xms_error
xms_size:
	cmp     ax,[dev_size]
	jae     xms_alloc
	cmp     ax,MIN_CACHE_SIZE_K
	jb      xms_no_space
	mov     [dev_size],ax
xms_alloc:
	mov     dx,[dev_size]
	mov     ah,09h
	call    [xms_entry]
	cmp     ax,1
	jne     xms_no_space
	mov     [xms_handle],dx
	call    driveparms
	jnc     xms_init_done
	mov     dx,[xms_handle]
	mov     ah,0ah
	call    [xms_entry]
	mov     [xms_handle],0
	stc
xms_init_done:
	ret
xms_missing:
        mov     dx,offset no_xms
xms_error:
        call    print
        stc
        ret

BREAK	</A INIT Code>

;**	EMM device driver name
;
;	The following datum defines the Above Board EMM 8 character
;	device driver name that is looked for as part of TYPE 2
;	specific initialization.
;
;	This datum is specific to TYPE 2 drivers
;

ABOVE_DEV_NAME	DB	"EMMXXXX0"

; Install the EMS cache through INT 67h.
ABOVE_INIT:
ASSUME	DS:INT13CODE,ES:NOTHING,SS:NOTHING
    ;
	mov	[cache_move],offset above_blkmov
    ; Check for presence of Above board memory manager
    ;
	MOV	AX,(Get_Interrupt_Vector SHL 8) OR 67H
	INT	21H
	MOV	DI,SDEVNAME
	MOV	SI,OFFSET ABOVE_DEV_NAME
	MOV	CX,8
	REPE	CMPSB
	JZ	GOT_MANAGER
	MOV	DX,OFFSET NO_ABOVE
ABOVE_ERR:
	CALL	PRINT
	STC
	RET

GOT_MANAGER:
    ;
    ; Check memory status
    ;
	MOV	CX,8000H
STLOOP:
	MOV	AH,ABOVE_STATUS
	INT	67H
	CMP	AH,ABOVE_SUCCESSFUL
	JZ	MEM_OK
	CMP	AH,ABOVE_ERROR_BUSY
	LOOPZ	STLOOP
ST_ERR:
	MOV	DX,OFFSET BAD_ABOVE
	JMP	ABOVE_ERR

MEM_OK:
    ;
    ; Get base address of map region and set BASE_ADDR
    ;
	MOV	AH,ABOVE_GET_SEG
	INT	67H
	CMP	AH,ABOVE_ERROR_BUSY
	JZ	MEM_OK
	CMP	AH,ABOVE_SUCCESSFUL
	JNZ	ST_ERR
	MOV	WORD PTR [BASE_ADDR],0
	MOV	WORD PTR [BASE_ADDR + 2],BX
    ;
    ; Allocate drive memory
    ;
GET_AVAIL:
	MOV	AH,ABOVE_GET_FREE
	INT	67H
	CMP	AH,ABOVE_ERROR_BUSY
	JZ	GET_AVAIL
	CMP	AH,ABOVE_SUCCESSFUL
	JNZ	ST_ERR
	MOV	AX,DX		; AX is total 16K pages
				; BX is un-allocated 16K pages
	MOV	DX,OFFSET NO_MEM
	OR	AX,AX
	JZ	ABOVE_ERR
	MOV	DX,OFFSET ERRMSG2
;
;   change in allocation strategy new default is all of available pages
;   < 8192K.
;
;   algorithm:	    if (free_pages < 8) then	error();
;		    else {
;			if (free_pages >  200h) then free_pages = 200h;
;			if (num_arg == 1) then dev_size = free_pages;
;			else dev_size = min (dev_size,free_pages)



	CMP	BX,8		; 128K = 16K * 8 = Min cache size
	JB	ABOVE_ERR
	cmp	bx,0200h	; 8192K = Max cache size
	jbe	ab0$1		; if less  or equal fine
	mov	bx,0200h	; else limit it to 8192K
ab0$1:
	mov	cx,4		; to convert number of pages into no of k
	shl	bx,cl
	cmp	[num_arg],1	; is numeric argument 1 ( means none )
	jne	ab0$2		; cache size has been requested
	mov	[dev_size],bx	; else use all of available cache
	jmp	short ab001	;
ab0$2:
	cmp	[dev_size],bx	; minimum of dev size and bx
	jb	ab001
	mov	[dev_size],bx	;


ab001:
	mov	bx,[dev_size]
	mov	[current_dev_size],bx ; Initialize current device size
    ;
    ; BX is K we want to allocate (limited by available K)
    ;  BX is at least 16
    ;
	MOV	AX,BX
	MOV	CX,4		; Convert back to # of 16K pages
	SHR	BX,CL
	TEST	AX,0FH		; Even????
	JZ	OKAYU		; Yes
	INC	BX		; Gotta round up
	PUSH	BX
	MOV	CX,4
	SHL	BX,CL
	MOV	[DEV_SIZE],BX	; Correct dev size too by rounding it up to
				;   next multiple of 16K, no sense wasting
				;   part of a page.
;A
	mov	[current_dev_size],bx ; Correct current device size also
;A
	POP	BX
OKAYU:
	MOV	AH,ABOVE_ALLOC
	INT	67H
	CMP	AH,ABOVE_ERROR_BUSY
	JZ	OKAYU
	CMP	AH,ABOVE_SUCCESSFUL
	JZ	GOT_ID
	CMP	AH,ABOVE_ERROR_MAP_CNTXT
	JZ	ST_ERRJ
	CMP	AH,ABOVE_ERROR_OUT_OF_PIDS
	JB	ST_ERRJ
	MOV	DX,OFFSET ERRMSG2
	JMP	ABOVE_ERR

ST_ERRJ:
	JMP	ST_ERR

GOT_ID:
	MOV	[ABOVE_PID],DX
    ;
    ; Validate the resident layout before hooking any vectors.
        call    driveparms
        jnc     RETYYY
        call    reset_system
        stc
RETYYY:
	RET

BREAK <messages and common data>

;**	Message texts and common data
;
;	Init data. This data is disposed of after initialization.
;	it is mostly texts of all of the messages
;
;	COMMON to TYPE 1 and 2 drivers
;
; THIS IS THE START OF DATA SUBJECT TO TRANSLATION

NO_ABOVE db	"SMARTDrive : Expanded Memory Manager not present",13,10,"$"
BAD_ABOVE db	"SMARTDrive : Expanded Memory Status shows error",13,10,"$"
NO_XMS	db	"SMARTDrive : Extended Memory Manager (XMS) required",13,10,"$"
NO_MEM	db	"SMARTDrive : No expanded memory available",13,10,"$"
ERRMSG1 db	"SMARTDrive : Invalid parameter",13,10,"$"
ERRMSG2 db	"SMARTDrive : Insufficient memory",13,10,"$"
INIT_IO_ERR db	"SMARTDrive : I/O error accessing cache memory",13,10,"$"
NOHARD	db	"SMARTDrive : No hard drives on system",13,10,"$"
BIGTRACK db	"SMARTDrive : Too many bytes per track on hard drive",13,10,"$"
BADVERMES db	13,10,"SMARTDrive : Incorrect DOS version",13,10,"$"

;
; This is the Int13 header message.
;
HEADERMES db	13,10,"Microsoft SMARTDrive Disk Cache v2.10",13,10,"$"

;
; This is the status message used to display INT13 configuration
;  it is:
;
;    STATMES1<size in K><STATMES1A|STATMES1E>STATMES2<# tracks in cache>STATMES3
;    <sectors per track>STATMES4
;
; It is up to translator to move the message text around the numbers
; so that the message is printed correctly when translated
;
STATMES1  db	"    Cache size: $"
STATMES1A db	"K in Expanded Memory$"
STATMES1E db	"K in Extended Memory (XMS)$"
STATMES2  db	13,10,"    Room for $"
STATMES3  db	" tracks of $"
STATMES4  db	" sectors each",13,10,13,10,"$"
ifdef	OMTI
omti_msg  db	"    OMTI controller release",13,10,"$"
endif

;-----------------------------------------------------------------------
;
; END OF DATA SUBJECT TO TRANSLATION
;

IF DEBUG
STATMES5  db	"Device CS = $"
STATMES6  db	" decimal",13,10,"$"
s5flagmsg db	" = S5 flag",13,10,"$"
U_msg	  db	" = U Switch", 13,10,'$'
ENDIF

	db	"This program is the property of Microsoft Corporation."

INT13_END	LABEL	BYTE

INT13CODE ENDS
	END
