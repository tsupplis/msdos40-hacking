; 1 tab = 4 spaces

;
; This is a rewrite of Marco van Zwetselaar's USE!UMBS.SYS v2.0 from 1991.
;
; Changes in this version (v2.2);
; * UMBs are now initialized to avoid parity errors.
; * Minor size optimizations.
;
; Changes in the previous version (v2.1);
; * This file assembles in NASM.
; * Optimizations to reduce memory usage.
; * Command line parameters are now used in CONFIG.SYS to specify address ranges for UMBs.
;
;   Example for a single 128 KB UMB starting at segment D000h:
;
;   DEVICE=UMBS.SYS D000-F000
;
; Please report bugs to me at krille_n_@hotmail.com
;
; Thanks!
;
; Krister Nordvall
;


CODE SEGMENT PARA PUBLIC 'CODE'
	ASSUME CS:CODE, DS:CODE

		TAB						equ		9
		CR						equ		13
		SPACE					equ		32

		bRH_Command				equ		2
		wRH_Status				equ		3
		fpRH_BreakAddress		equ		14
		fpRH_CommandLine		equ		18


		org 0


		fpNextDeviceDriver		dd		-1
		wDeviceAttributeWord	dw		0E000h
		wOffsetStrategyRoutine	dw		StrategyRoutine
		wOffsetInterruptRoutine	dw		InterruptRoutine
		sDeviceName				db		'ZwetsUMB'

		fpRequestHeader			dd		0

Interrupt2FhHandler:
		cmp		ax, 4300h
		je		ReturnHandlerExists
		cmp		ax, 4310h
		je		RequestIsForMe

		db		0EAh					; Far jump opcode
fpOldInterrupt2FhHandler	dd		0						; Pointer filled in during initialization

RequestIsForMe:
		mov		bx, OFFSET UMBController
		push	cs
		pop		es
		iret

ReturnHandlerExists:
		mov		al, 80h
		iret


StrategyRoutine:
		mov		WORD PTR cs:[fpRequestHeader], bx
		mov		WORD PTR cs:[fpRequestHeader+2], es
		retf


InterruptRoutine:
		push	es
		push	bx
		push	ax

		les		bx, cs:[fpRequestHeader]
		mov		al, es:[bx+bRH_Command]
		test	al, al
		jz		Install

		cmp		al, 10h
		jbe		NotImplemented
		mov		ax, 8003h				; "Unknown command"
		db	03Dh	; immediate operand follows
NotImplemented:
		xor		ax, ax

Return:
		or		ax, 100h				; Set Done bit
		mov		es:[bx+wRH_Status], ax

		pop		ax
		pop		bx
		pop		es
		retf


UMBController:
; The first 5 bytes of Himem handlers are special and must not be changed.
		jmp		SHORT CheckIfUMBorXMSrequest
		nop
		nop
		nop

CheckIfUMBorXMSrequest:
		cmp		ah, 10h
		je		UMBrequest

JMPtoOurXMShandler:
		jmp		SHORT XMSrequest		; This jump is patched out during init if an existing XMS handler is detected
fpOldXMShandler	equ	JMPtoOurXMShandler+1
		db		3
		db		0
		db		0

UMBrequest:
		push	si
		push	cx
		push	bx

		db	0BEh	; immediate operand follows
FreeListOperand	dw		0						; Offset filled in during init

		xor		cx, cx
		xchg	dx, cx					; DX = 0, CX = Requested block size

Search:
		db	2Eh		; CS override for LODSW
		lodsw							; Load start address of range
		test	ax, ax					; Are we at the end of the list?
		jz		NoBlockFound		; Jump if so
		mov		bx, ax					; Segment is returned in BX
		inc		ax						; Block already given away?
		db	2Eh		; CS override for LODSW
		lodsw							; Load length of block
		jz		Search			; If yes, get next block
		cmp		dx, ax					; Is it larger than the largest found so far?
		ja		CheckSize		; If not, check size to see if it's large enough
		mov		dx, ax					; It is so save it as the largest so far

CheckSize:
		cmp		cx, ax					; Large enough to fulfill request?
		ja		Search			; Jump if not

		mov		WORD PTR cs:[si-4], 0FFFFh	; Mark as given away
		mov		dx, 1					; Return Success in AX and size of block in DX
		xchg	dx, ax
		pop		cx						; Remove BX from stack
		jmp		SHORT UmbReturn

NoBlockFound:
		pop		bx						; Restore BX
		mov		bl, 0B0h				; Return "Smaller UMB available" in BL
		test	dx, dx					; Size of largest block found = 0?
		jnz		UmbReturn			; If not, assumption was correct
		inc		bx						; Yes, return "No UMBs available" instead

UmbReturn:
		pop		cx
		pop		si
		retf


XMSrequest:
		test	ah, ah					; Get XMS version?
		jnz		NotGetVersion

		xor		bx, bx					; Internal revision number
		cwd								; HMA not present
		jmp		SHORT XmsReturn

NotGetVersion:
		cmp		ah, 8					; Query extended memory?
		jne		NotQueryExtendedMem
		cwd								; 0 KB extended memory

NotQueryExtendedMem:
		mov		bl, 80h					; Error: Not implemented

XmsReturn:
		xor		ax, ax					; Always return failure
		retf


Install:
		push	cx
		push	dx
		push	ds
		push	si

		push	cs
		pop		ds

		; Is there an XMS handler already?
		mov		ax, 4300h
		int		2Fh
		cmp		al, 80h
		jne		OKtoInstall		; No, it's OK to install (with our handler)

		; Yes, patch out the short unconditional jump to our XMS handler
		mov		BYTE PTR [JMPtoOurXMShandler], 0EAh		; 'jmp far ...'

		; Then get the address to the old handler and store it
		mov		ax, 4310h
		int		2Fh
		mov		WORD PTR [fpOldXMShandler], bx
		mov		WORD PTR [fpOldXMShandler+2], es

		; To reduce memory usage we also move the breakpoint to exclude our XMS handler
		mov		WORD PTR [BreakOperand], OFFSET XMSrequest

		; Tell the user we found an existing handler
		mov		ah, 9
		mov		dx, OFFSET s$XMMfound
		int		21h

		; Check if it services UMBs by trying to allocate far too much
		mov		ah, 10h
		cwd
		dec		dx
		call	DWORD PTR [fpOldXMShandler]

		; Assume we are not needed
		mov		dx, OFFSET s$NotInstalled
		xor		ax, ax

		cmp		bl, 80h					; Error: Not implemented?
		je		OKtoInstall
		jmp		StoreBreakPointer

OKtoInstall:
		; Get the breakpoint (Install or XMSrequest) to BX and store it as the start of the FreeUMBs list
		mov		bx, [BreakOperand]
		mov		[FreeListOperand], bx

		; Time to interpret the command line in CONFIG.SYS
		lds		si, [fpRequestHeader]
		lds		si, [si+fpRH_CommandLine]

		push	cs						; For restoring DS later

		mov		cx, 4					; Hex digit count in CH = 0, Shift count in CL = 4
		xor		ah, ah					; WORD parameter count in AH
		; First scan until we find a whitespace (tab or space) to find the start of parameters
SearchForWhiteSpace:
		lodsb
		cmp		al, CR
		je		EndOfLineEncountered
		cmp		al, SPACE
		je		SearchForParameter
		cmp		al, TAB
		jne		SearchForWhiteSpace

		; We've found the first whitespace which means we've reached the end of the path+filename
SearchForParameter:
		lodsb
		cmp		al, CR
		je		EndOfLineEncountered
		cmp		al, SPACE
		je		SearchForParameter
		cmp		al, TAB
		je		SearchForParameter

		; We have the first byte of a parameter
		dec		si
NextHexDigit:
		lodsb
		inc		ch
		cmp		al, '9'
		jbe		NotAtoF
		and		al, 0DFh
		cmp		al, 'F'
		ja		ParameterError
		cmp		al, 'A'
		jb		ParameterError
		sub		al, 7
NotAtoF:
		sub		al, '0'
		jb		ParameterError
		shl		dx, cl
		or		dl, al
		and		ch, 3
		jnz		NextHexDigit

		; We have a complete WORD in DX
		inc		ah						; Increment WORD count
		sahf							; WORD count Odd or Even?
		jc		FirstWordOfParameter
		sub		dx, cs:[bx-2]			; Convert end of range to length
		jbe		ParameterError	; End of range below or equal to start of range
FirstWordOfParameter:
		mov		cs:[bx], dx
		inc		bx
		inc		bx
		lodsb
		sahf
		jc		CheckIfDash
		cmp		al, CR
		je		EndOfLineEncountered
		cmp		al, SPACE
		je		SearchForParameter
		cmp		al, TAB
		je		SearchForParameter
		db	0B8h	; immediate operand follows						; Fall through to ParameterError
CheckIfDash:
		cmp		al, '-'
		je		NextHexDigit

ParameterError:
		pop		ds						; DS = CS

		mov		dx, OFFSET s$ParamError
		xor		ax, ax
		jmp		SHORT StoreBreakPointer

EndOfLineEncountered:
		call	CheckRanges
		jc		ParameterError
		test	ah, ah
		jz		ParameterError	; No parameters at all

		pop		ds						; DS = CS

		mov		WORD PTR [bx], 0			; End of Free UMBs block marker
		inc		bx
		inc		bx
		mov		[BreakOperand], bx

		; We need to initialize the UMBs by writing to every address to avoid parity errors later when reading
		mov		si, [FreeListOperand]
		push	di

InitNextBlock:
		lodsw							; Segment address of UMB to AX
		test	ax, ax
		jz		AllBlocksInitialized
		xchg	bx, ax					; Save address in BX
		lodsw							; Block size in paragraphs to AX
		xor		dx, dx
		xchg	dx, ax					; DX = Paragraph count, AX = Zero
		xor		di, di					; Point ES:DI to start of UMB
InitNextSegment:
		mov		es, bx
		cmp		dh, 10h					; Block larger than or equal to a full segment?
		jb		LessThan64KB
		mov		cx, 8000h				; We need to write (at least) a full 64 KB segment
		add		bh, 10h					; Add 64 KB to the segment address for the next iteration (if any)
		sub		dh, 10h					; Subtract 64 KB from the paragraph count
		rep		stosw
		jmp		SHORT InitNextSegment
LessThan64KB:
		mov		cl, 3
		shl		dx, cl					; Paragraphs to WORDs
		mov		cx, dx					; WORD count to CX
		rep		stosw
		jmp		SHORT InitNextBlock

AllBlocksInitialized:
		pop		di

		; Get handler for Interrupt 2Fh and store it
		mov		ax, 352Fh
		int		21h
		mov		WORD PTR [fpOldInterrupt2FhHandler], bx
		mov		WORD PTR [fpOldInterrupt2FhHandler+2], es

		; Then hook it
		mov		ax, 252Fh
		mov		dx, OFFSET Interrupt2FhHandler
		int		21h

		; Tell the user we are installed
		mov		dx, OFFSET s$Installed
		db	0B8h	; immediate operand follows
BreakOperand	dw		Install					; Default breakpoint offset is Install

StoreBreakPointer:
		les		bx, [fpRequestHeader]
		mov		es:[bx+fpRH_BreakAddress], ax
		mov		es:[bx+fpRH_BreakAddress+2], cs

		mov		ah, 9
		int		21h						; Print Installed/NotInstalled/ParamError

		xor		ax, ax					; No errors
		pop		si
		pop		ds
		pop		dx
		pop		cx
		jmp		Return


; Check each range against earlier ranges before initializing any memory.
CheckRanges:
		push	si
		push	di
		mov		di, cs:[FreeListOperand]
NextRange:
		cmp		di, bx
		jae		RangesChecked
		mov		si, cs:[FreeListOperand]
EarlierRange:
		cmp		si, di
		je		RangeChecked
		mov		dx, cs:[si]
		add		dx, cs:[si+2]
		cmp		dx, cs:[di]
		jbe		Disjoint
		mov		dx, cs:[di]
		add		dx, cs:[di+2]
		cmp		cs:[si], dx
		jb		RangesChecked			; Carry set on overlap
Disjoint:
		add		si, 4
		jmp		SHORT EarlierRange
RangeChecked:
		add		di, 4
		jmp		SHORT NextRange
RangesChecked:
		pop		di
		pop		si
		ret

s$XMMfound		db			'UMBS: Found XMS manager.',0Dh,0Ah,'$'
s$Installed		db			'$' ; UMBS: V2.3 installed',0Dh,0Ah,'$'
s$NotInstalled	db			'UMBS: Found UMB managed.',0Dh,0Ah,'$'
s$ParamError	db			'UMBS: Invalid command line.',0Dh,0Ah,'$'


CODE ENDS
	END
