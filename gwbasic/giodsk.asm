; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	SUBTTL  GLOBAL TEMPS and DEFS
	TITLE   GIODSK - BASIC-86 Generalized I/O Disk Driver

COMMENT	*

--------- --- ---- -- ---------
COPYRIGHT (C) 1982 BY MICROSOFT
--------- --- ---- -- ---------

        T. Corbett      Microsoft   for BASIC-86 Generalized I/O
                        Based on code written for BASCOM-86
        *
	INCLUDE	GIO86U

CPM86=0

	INCLUDE	MSDOSU

	.SALL
	.RADIX	10


	EXTRN	CHRGTR:NEAR,SYNCHR:NEAR,OUTDO:NEAR
	EXTRN	DERNMF:NEAR,DERBFM:NEAR,DERBRN:NEAR,DERFAO:NEAR,FCERR:NEAR
	EXTRN	DERTMF:NEAR,SaveDosError:NEAR
	EXTRN	DERFAE:NEAR,DERFNF:NEAR,DERIOE:NEAR,DERDFL:NEAR,DERFOV:NEAR
	EXTRN	CONIA:NEAR,MAKINT:NEAR,MOVE1:NEAR,$NORMD:NEAR
	EXTRN	DEVBOT:NEAR,DEVBIN:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'		
	ASSUME DS:DSEG
	EXTRN	DFACLO:WORD,FAC:WORD,VALTYP:WORD
	EXTRN	FILNAM:WORD,FILNA2:WORD
DSEG	ENDS

	ASCCR=13D		;Ascii carriage return
	ASCCTZ=26D		;END OF FILE CHARACTER

;Disk Dispatch Table
;
	PUBLIC	DSKDSP
DSKDSP:
	DW	(DSKEOF)	;test EOF for file opened to this device
	DW	(DSKLOC)	;LOC - sequential records / last random record
	DW	(DSKLOF)	;LOF - file size
	DW	(DSKCLS)	;perform special CLOSE functions for this device
	DW	(FCERR)		;set device width
	DW	(DSKRND)	;GET/PUT random record from/to this device
	DW	(DSKOPN)	;perform special OPEN functions for this device
	DW	(DSKSIN)	;input 1 byte from file opened on this device
	DW	(DSKSOT)	;output 1 byte to file opened on this device
	DW	(DSKGPS)	;POS
	DW	(DSKGWD)	;get device width
	DW	(DSKSCW)	;set device comma width
	DW	(DSKGCW)	;get device comma width
	DW	(DEVBIN)	;block input from file opened on this device
	DW	(DEVBOT)	;block output to file opened on this device

	SUBTTL  Misc. Disk Routines

;DSKEOF - test for End-Of-File on device.
; Entry - SI points to File-Data-Block.
; Exit  - [BX] = -1 if EOF, 0 if not EOF
;
DSKEOF:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO	;EOF( ) is Illegal
	JE	ER_BFM		; for Sequential Output
ORNCHK:
	XOR	AL,AL
	CMP	BYTE PTR F_ORCT[SI],AL	;zero if End of File
	JE	WASEOF		;Brif EOF
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_RND	;If mode is Random
	JZ	NOTEOF		; then don't return true EOF
	CMP	BYTE PTR F_BREM[SI],AL	;Any bytes left in buffer?
	JNZ	CHKCTZ		;Yes, look for Control-Z
	CALL	$READS		;Fill the Buffer
	JMP	SHORT ORNCHK	; and try again...
CHKCTZ:
	xor bx,bx
        mov bl,F_ORCT[si]
	SUB	BL,BYTE PTR F_BREM[SI]	;[BX] = char offset
	CMP	BYTE PTR DATOFS[BX+SI],LOW OFFSET ASCCTZ	;check for EOF
	JNZ	NOTEOF		;Brif next char not EOF
WASEOF:
	MOV	BX,-1		; -1 if EOF
	RET	
NOTEOF:
	XOR	BX,BX		;0 = not EOF
	RET	

ER_BFM:	JMP	DERBFM		;"Bad File mode"

;DSKLOC - Number of Bytes in input buffer.
; Entry - SI points to File-Data-Block.
; Exit  - [BX] = result.
;
DSKLOC:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_RND
	MOV	BX,WORD PTR F_CLOC[SI]	;Use current for Sequential
	JNE	LOC1
	MOV	BX,WORD PTR FD_LOG[SI]	;Use logical for Random
LOC1:	RET	

;DSKLOF - return file size in bytes.
; Entry - SI points to File-Data-Block.
; Exit  - [Floating-Point-Accumulator] = result.
;
DSKLOF:
        cmp byte ptr F_MODE[si],MD_SQO
        jne ReadLength
        cmp byte ptr FD_CHAR[si],0
        jne ReadLength
        mov ax,word ptr FCB_RN[si]
        mov dx,word ptr FCB_RN+2[si]
        call SectorBytes
        xor cx,cx
        mov cl,F_ORCT[si]
        add ax,cx
        adc dx,0
        call ExtendLength
ReadLength:
	LEA	DX,DWORD PTR FCB_FS[SI]	;[DX] points to file size
        MOV     BX,OFFSET DFACLO-1	;[BX] Target
	MOV	BYTE PTR 0[BX],LOW 0	;zero overflow byte
	INC	BX
	MOV	CH,LOW 4
        push si                 ; MOVE1 consumes its source and destination.
	CALL	MOVE1		;Move file length to FAC
        pop si
        cmp byte ptr FD_CHAR[si],0
        je LengthReady
        cmp byte ptr F_MODE[si],MD_SQO
        jne LengthReady
        mov ax,word ptr FCB_FS[si]
        or ax,word ptr FCB_FS+2[si]
        jnz LengthReady
        mov byte ptr DFACLO,1   ; LOF of an empty sequential output device.
LengthReady:
	MOV	BYTE PTR FAC+1,CH	;zero sign
	MOV	WORD PTR 0[BX],CX	;zero high bytes of FAC
	MOV	WORD PTR 2[BX],OFFSET ((128+56)*256)	;Initialize Exponent
	MOV	BYTE PTR VALTYP,LOW 8	;Dbl prec value
	JMP	$NORMD		;Normalize value
;DSKGPS - return current file position.
; Entry - SI points to File-Data-Block.
; Exit  - [AH] = current file column. (0-relative)
;         All other registers preserved
;
DSKGPS:	MOV	AH,BYTE PTR F_POS[SI]	;[AH]=current column
	RET	

;DSKGWD - get device width
; Exit  - [AH] = device width as set by xxxSWD
;         All other registers preserved
;
DSKGWD:	MOV	AH,LOW 255D	;disk files always have infinite width
	RET	

;DSKSCW - set device comma width
; Entry - [BX] = new device comma width
; Exit  - SI, DI can be changed.
;         All other registers preserved
;
DSKSCW:

;DSKGCW - get device comma width
; Exit  - [BX] = device comma width as set by xxxSCW
;         All other registers preserved
;
DSKGCW:	RET	

	SUBTTL  OPEN hook for Disk and all Directory handling

	EXTRN	INIFDB:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
        extrn FileAccess:byte
	EXTRN	FILMOD:WORD,FREFDB:WORD
DSEG	ENDS


;DSKOPN - perform any device dependent open functions.
; Entry - [AL] = FILDEV = device id
;                0 if default device,
;                1..n for Disk A:, B:, ...
;                -1..-n for non-disk devices
;         [BX] = file number (0..n)
;         [CX] = random record size if [FILMOD] = random
;                (if [CX] = 0, use default record size)
;         [DI] = device offset (2=DSKD, 4=SCRN, etc.)
;         [FILMOD] = file mode
;                    MD.SQI = 1 ;sequential input
;                    MD.SQO = 2 ;sequential output
;                    MD.RND = 3 ;random
;                    MD.APP = 4 ;append
;         [FILNAM] = filename
;         [FILEXT] = 1..3 byte filename extension
; Exit  - [SI] points to new FDB
;         FDB is linked into FDB chain with all standard
;         fields initialized.
;         All other registers are preserved.
;
DSKOPN:				;note: save [AL]=device ID till INIFDB
	CMP	BYTE PTR FILMOD,LOW OFFSET MD_RND
	JNZ	DSKOP2		;branch if not OPEN RANDOM
	OR	CX,CX
	JNZ	DSKOP2		;branch if user requested Record-Size
	MOV	CX,OFFSET DATPSC	;default to Bytes per Sector
DSKOP2:	PUSH	CX		;save user requested Random-Record-Size
	ADD	CX,OFFSET FD_DAT-FDBSIZ	;add standard Disk FDB requirements
	MOV	AH,LOW 255D	;all file-modes are legal for Disk
	MOV	DX,255D		;[DH]=initial file column position
				;[DL]=initial file width
	CALL	INIFDB		;SI points to new file's FDB
	MOV	WORD PTR FREFDB,SI	;save pointer to FDB so FINPRT will
				;release it if error occurs before file
				;gets completely opened.
	PUSH	SI		;save FDB pointer
	LEA	DI,DWORD PTR FCB_DV[SI]	;DI points to filename field within FDB
	MOV	SI,OFFSET FILNAM
	MOV	CX,OFFSET FNAML+1	;Moving drive,name,ext
	CLD			;Set Post-Increment mode
 REP	MOVSB			; to FDB's FCB
        pop si
        mov word ptr FCB_RN[si],0
        mov word ptr FCB_RN+2[si],0
        call ResolveDrive       ; Remember the drive even if the default changes.
        pop ax
        mov FD_SIZ[si],ax
        call ClassifyFile
        cmp byte ptr FD_CHAR[si],0
        je OpenDisk
        mov ax,3d02h            ; Random device file: bidirectional.
        mov cl,byte ptr FILMOD
        cmp cl,MD_RND
        je OpenDevice
        mov al,1
        cmp cl,MD_SQI
        jne OpenDevice
        dec al
OpenDevice:
        mov dx,offset FILNA2
        int 21h
        jnc DeviceOpened
        jmp OpenFailure
DeviceOpened:
        mov F_HANDLE[si],ax
        xor ax,ax
        mov word ptr FCB_FS[si],ax
        mov word ptr FCB_FS+2[si],ax
        jmp short OPNSET
OpenDisk:
        call OpenDiskFile
OPNSET:
	XOR	CX,CX
	MOV	WORD PTR F_CLOC[SI],CX	;Clear curloc
	MOV	WORD PTR F_CLOC+2[SI],CX	;Clear numloc
	MOV	AL,BYTE PTR FILMOD
	CMP	AL,LOW OFFSET MD_RND
	JZ	RNDFIN		;Brif finish random open
	CMP	AL,LOW OFFSET MD_APP
	JZ	APPFIN		;Brif finish append open
	CMP	AL,LOW OFFSET MD_SQI
	JNZ	OPNFIN		;If not input get text pointer/exit
	CALL	$READS		;Read 1st data block into buffer
OPNFIN:	MOV	WORD PTR FREFDB,0	;file is completely open.
				;FINPRT won't release FDB.
	RET	
RNDFIN:
        mov word ptr FD_LOG[si],0
        mov word ptr FD_OPS[si],0
	JMP	SHORT OPNFIN

; Append - Seek to eof, read a sector, find byte eof,
;          correct no. of bytes remaining, finish up
;          by changing file mode to sequential output.
APPFIN:
        cmp byte ptr FD_CHAR[si],0
        jne EmptyAppend
	CMP	WORD PTR FCB_FS[SI],CX	;Test for empty file
	JNZ	NTZRF1		;Brif file not empty
	CMP	WORD PTR FCB_FS+2[SI],CX
	JNZ	NTZRF1
EmptyAppend:
	MOV	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO	;Change mode to Seq output
	JMP	SHORT OPNFIN	; and exit
NTZRF1:
	LEA	DI,DWORD PTR FCB_RN[SI]	;DI points to random record# field
	PUSH	SI		;Save FDB pointer
	ADD	SI,OFFSET FCB_FS	;Move to File Size
	TEST	BYTE PTR 0[SI],LOW 127D	;See if multiple of 128
	CLD			;Set Post-Inc mode for next 10 lines
	PUSHF			;and remember
	LODSB			;Get low order of size
	ADD	AL,AL		;Rotate hi bit into carry
	LODSW			;Get middle word
	ADC	AX,AX		;carry in, hi bit out
	STOSW			;Save low word of rec no.
	LODSB			;Get high byte
	MOV	AH,LOW 0	;Clear hi byte of rec no.
	ADC	AX,AX		;consider carry
	STOSW			;Store hi word of rec no.
	POPF			;get record flag
	POP	SI
	JNZ	NOMTRC		;Brif record not empty
	CALL	BAKURN		; else backup so can align
NOMTRC:
	CALL	$READS		;read a sector
	CALL	BAKURN		;back up 1 record
        xor bx,bx
AppendScan:
        cmp bl,F_ORCT[si]
        je AppendEnd
        cmp byte ptr DATOFS[bx+si],ASCCTZ
        je AppendEnd
        inc bx
        jmp short AppendScan
AppendEnd:
        mov dx,bx
SETSQO:
	MOV	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO	;now we're Seq output
	LEA	DI,DWORD PTR F_CLOC[SI]
	XOR	AX,AX
	CLD			;Set Post-Increment mode
	STOSW			;zero curloc since empty
	MOV	BYTE PTR 0[DI],DL	;store no. of bytes left
	MOV	BYTE PTR F_POS[SI],AL	;zero print position
	JMP	SHORT OPNFIN
; All named character device operations use the same DOS handle. Let DOS
; complete a failed request before dispatching the BASIC critical error.
DSEG SEGMENT PUBLIC 'DATASG'
        extrn DeviceCall:byte,DeviceError:byte
DSEG ends
DeviceIO:
        call DeviceRequest
        jc DeviceIOFailure
        ret
DeviceRequest:
        mov bx,F_HANDLE[si]
        mov DeviceError,0
        mov DeviceCall,1
        int 21h
        mov DeviceCall,0
        jnc DeviceIODone
        mov dl,DeviceError
        or dl,dl
        jnz CriticalDeviceError
        call SaveDosError
        stc
        ret
CriticalDeviceError:
        jmp ERROR
DeviceIOFailure:
        cmp ax,21h              ; DOS lock violation.
        je LockIOError
        cmp ax,5
        jne OtherIOError
LockIOError:
        mov dl,70
        jmp ERROR
OtherIOError:
        jmp DERIOE
DeviceIODone:
        ret

; IOCTL passes binary control strings (including embedded NULs) through
; the same DOS handle owned by OPEN. DOS returns the actual input length.
        public IOCTL,IoctlFunc
        extrn FILSCN:near,DERBFN:near,STRINI:near,PUTNEW:near
DSEG SEGMENT PUBLIC 'DATASG'
; An IOCTL$ result is copied to BASIC before returning. Directory statements
; evaluate their argument before building the ASCIIZ path in the same space.
ControlReply label byte
DirPath db 259 dup (?)          ; 255-byte path, optional *.*, NUL.
DSEG ends
IOCTL:
        call ControlFile
        push dx                 ; FDB addresses may move during string evaluation.
        call SYNCHR
        db ','
        call FRMEVL
        push bx
        call FRESTR
        xor cx,cx
        mov cl,[bx]
        mov di,[bx+1]
        pop bx
        pop dx
        push bx
        mov al,dl
        extrn FDBPTR:near
        call FDBPTR
        jz ControlBadFile
        mov dx,di
        mov ax,4403h
        call ControlTransfer
        pop bx
        ret
IoctlFunc:
        call CHRGTR
        call SYNCHR
        db '$'
        call SYNCHR
        db '('
        call ControlFile
        push si
        call SYNCHR
        db ')'
        pop si
        push bx
        mov dx,offset ControlReply
        mov cx,255
        mov ax,4402h
        call ControlTransfer
        cmp ax,255
        ja ControlInvalid
        push ax
        call STRINI
        mov di,dx
        pop cx
        mov si,offset ControlReply
        cld
        rep movsb
        jmp PUTNEW
ControlFile:
        call FILSCN
        jnz ControlFileDone
ControlBadFile:
        jmp DERBFN
ControlFileDone:
        ret
ControlTransfer:
        cmp word ptr F_HANDLE[si],-1
        je ControlInvalid
        cmp byte ptr FD_CHAR[si],0
        je ControlInvalid
        call DeviceRequest
        jnc ControlDone
ControlInvalid:
        jmp FCERR
ControlDone:
        ret

; FindFirst returns the device attribute in the caller's disk transfer area.
ClassifyFile:
        push bx
        push dx
        push si
        lea dx,DATOFS[si]
        CALLOS C_BUFF
        mov di,offset FILNA2
        call DiskName
        mov dx,offset FILNA2
        mov cx,37h
        mov ah,4eh
        int 21h
        pop si
        mov byte ptr FD_CHAR[si],0
        jc ClassifyDone
        mov al,DATOFS+21[si]    ; FindFirst attribute byte
        and al,40h
        mov FD_CHAR[si],al
ClassifyDone:
        pop dx
        pop bx
        ret

        public LockStmt,UnlockStmt
        extrn $TO:abs,FRCDBL:near
DSEG segment public 'DATASG'
LockFirst dd ?
LockSize dw ?
LockAction db ?
DSEG ends

LockStmt:
        xor ax,ax
        jmp short LockFile
UnlockStmt:
        mov ax,1
LockFile:
        mov LockAction,al
        call ControlFile
        push dx                 ; Resolve the file number after expression evaluation.
        xor ax,ax
        cmp byte ptr F_MODE[si],MD_RND
        jne LockUnits
        cmp byte ptr F_DEV[si],0
        jl LockUnits
        mov ax,FD_SIZ[si]
LockUnits:
        mov LockSize,ax
        xor ax,ax
        mov word ptr LockFirst,ax
        mov word ptr LockFirst+2,ax
        dec ax
        mov di,ax
        mov si,ax               ; Default to the entire file.
        cmp byte ptr [bx],','
        jne LockRangeReady
        call CHRGTR
        cmp al,offset $TO
        je LockTo
        call LockRecord
        sub ax,1
        sbb dx,0
        mov word ptr LockFirst,ax
        mov word ptr LockFirst+2,dx
        mov di,LockSize
        xor si,si
        cmp byte ptr [bx],offset $TO
        jne LockRangeReady
LockTo:
        call CHRGTR
        call LockRecord         ; End is exclusive after scaling the 1-based record.
        cmp LockSize,0
        je LockWhole
        call LockScale
        push dx
        push ax
        mov ax,word ptr LockFirst
        mov dx,word ptr LockFirst+2
        call LockScale
        mov word ptr LockFirst,ax
        mov word ptr LockFirst+2,dx
        pop di
        pop si
        sub di,ax
        sbb si,dx
        jc LockBadRecord
        mov ax,si
        or ax,di
        jz LockBadRecord
        jmp short LockDispatch
LockRangeReady:
        cmp LockSize,0
        jne LockRangeScale
LockWhole:
        ; Sequential streams accept the range syntax and lock the whole file.
        xor ax,ax
        mov word ptr LockFirst,ax
        mov word ptr LockFirst+2,ax
        dec ax
        mov si,ax
        mov di,ax
        jmp short LockDispatch
LockRangeScale:
        mov ax,word ptr LockFirst
        mov dx,word ptr LockFirst+2
        call LockScale
        mov word ptr LockFirst,ax
        mov word ptr LockFirst+2,dx
LockDispatch:
        pop ax
        push bx
        push si
        call FDBPTR             ; AL = original BASIC file number
        jz LockDenied
        mov bx,F_HANDLE[si]
        pop si
        cmp bx,-1
        je LockDenied
        mov cx,word ptr LockFirst+2
        mov dx,word ptr LockFirst
        mov al,LockAction
        mov ah,5ch
        int 21h
        jc LockDosError
        pop bx
        ret
LockDosError:
        call SaveDosError
LockDenied:
        mov dl,70
        jmp ERROR
LockBadRecord:
        jmp DERBRN

; Return a positive record number in DX:AX from the high 32 bits of the
; double-precision MBF mantissa. Keep the expression's text pointer in BX.
LockRecord:
        call FRMEVL
        push bx
        call FRCDBL
        cmp LockSize,0
        jne LockCheckNumber
        mov ax,1
        xor dx,dx
        pop bx
        ret
LockCheckNumber:
        mov cl,byte ptr FAC
        mov dx,word ptr FAC-2
        or dx,dx
        js LockBadRecord
        cmp cl,81h
        jb LockBadRecord
        cmp cl,9fh
        ja LockBadRecord
        mov ax,word ptr FAC-4
        or dh,80h
        neg cl
        add cl,0a0h
LockShift:
        shr dx,1
        rcr ax,1
        dec cl
        jnz LockShift
        pop bx
        ret
LockScale:
        push cx
        mov cx,ax
        mov ax,dx
        mul LockSize
        or dx,dx
        jnz LockBadRecord
        push ax
        mov ax,cx
        mul LockSize
        pop cx
        add dx,cx
        jc LockBadRecord
        pop cx
        ret

DiskName:
        mov al,FCB_DV[si]
        or al,al
        jz DiskBase
        add al,'A'-1
        stosb
        mov al,':'
        stosb
DiskBase:
        lea bx,FCB_FN[si]
        mov cx,8
DiskCopy:
        mov al,[bx]
        cmp al,' '
        je DiskExtension
        stosb
        inc bx
        loop DiskCopy
DiskExtension:
        lea bx,FCB_FT[si]
        cmp byte ptr [bx],' '
        je DiskNameEnd
        mov al,'.'
        stosb
        mov cx,3
DiskSuffix:
        mov al,[bx]
        cmp al,' '
        je DiskNameEnd
        stosb
        inc bx
        loop DiskSuffix
DiskNameEnd:
        xor al,al
        stosb
        ret

; ClassifyFile has built the ASCIIZ name. Keep one DOS handle until CLOSE.
OpenDiskFile:
        mov dx,offset FILNA2
        cmp byte ptr FILMOD,MD_APP
        je OpenCheckName
        cmp byte ptr FILMOD,MD_SQO
        jne OpenExisting
OpenCheckName:
        call CHKFOP
        cmp byte ptr FILMOD,MD_SQO
        jne OpenExisting
        cmp FileAccess,0ffh
        jne OpenExisting
        mov ah,3ch              ; Plain OPEN FOR OUTPUT in compatibility mode.
        xor cx,cx
        int 21h
        jc OpenFailure
        jmp short OpenSize
OpenExisting:
        mov al,FileAccess
        cmp al,0ffh
        jne OpenByMode
        mov al,2
        cmp byte ptr FILMOD,MD_SQI
        jne OpenByMode
        xor al,al
OpenByMode:
        mov ah,3dh
        int 21h
        jnc OpenGranted
        cmp ax,2
        jne OpenFailure
        cmp byte ptr FILMOD,MD_SQI
        je OpenMissing
        mov ah,5bh              ; Fail if another process created the file.
        xor cx,cx
        int 21h
        jc OpenFailure
        cmp FileAccess,0ffh
        je OpenSize
        mov bx,ax               ; DOS 3.x create-new has no sharing operand.
        mov ah,3eh
        int 21h
        jc OpenFailure
        mov dx,offset FILNA2
        mov al,FileAccess
        mov ah,3dh
        int 21h
        jc OpenFailure
OpenGranted:
        cmp byte ptr FILMOD,MD_SQO
        jne OpenSize
        mov bx,ax
        mov F_HANDLE[si],ax
        xor cx,cx               ; Truncate only after obtaining write access.
        mov ah,40h
        int 21h
        jc OpenFailure
        mov ax,bx
OpenSize:
        mov F_HANDLE[si],ax
        mov bx,ax
        mov ax,4202h
        xor cx,cx
        xor dx,dx
        int 21h
        jc OpenFailure
        mov word ptr FCB_FS[si],ax
        mov word ptr FCB_FS+2[si],dx
        ret
OpenMissing:
        jmp ER_FNF
OpenFailure:
        call SaveDosError
        cmp ax,4                ; DOS handle table exhausted.
        jne OpenPermission
        jmp DERTMF
OpenPermission:
        cmp ax,5
        je AccessDenied
        cmp ax,20h              ; Sharing violation.
        je AccessDenied
        cmp ax,21h              ; Lock violation.
        je AccessDenied
        jmp DERIOE
AccessDenied:
        mov dl,70
        jmp ERROR

ER_FNF: call SaveDosError
        jmp DERFNF

BAKURN:
	SUB	WORD PTR FCB_RN[SI],1	;Random rec no. -1
	JAE	BAKRET		;Brif no underflow
	DEC	WORD PTR FCB_RN+2[SI]	;hi word -1
BAKRET:	RET	

	SUBTTL  CLOSE (CLSFIL) hook for Disk files

;DSKCLS - perform any device dependent close functions.
; Entry - SI points to File-Data-Block.
; Exit  - All registers used.
;         This routine is called before BASIC releases the
;         file-data-block associated with this file.
;
DSKCLS:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO
	JNE	NOFORC		;Don't dump buffer unless Seq Output
	MOV	AL,LOW OFFSET ASCCTZ
	CALL	FILOU4		;Write EOF char
	CMP	BYTE PTR F_ORCT[SI],LOW 0
	JE	NOFORC		;Brif buffer flushed
	CALL	$WRITS		;Flush the buffer
NOFORC:
        mov ah,3eh              ; Report DOS close errors to the caller.
        call DeviceIO
        mov word ptr F_HANDLE[si],-1
        ret

	SUBTTL Disk Sequential Input

;DSKSIN - Sequential Input.
; Entry - SI points to File-Data-Block.
; Exit  - [AL] = next byte from file,
;         carry set if EOF.
;         All other registers preserved
;
DSKSIN:	CALL	DSKINP		;get next byte from file
	JB	DSYEOF		;branch if End-Of-File
	CMP	AL,LOW OFFSET ASCCTZ	;check for CTL-Z
	JNE	DSNEOF		;branch if not
	CMP	BYTE PTR F_CODE[SI],LOW OFFSET FC_BIN
	JE	DSNEOF		;CTL-Z is not EOF for Binary files
DSYEOF:	STC			;set carry indicating EOF
	RET	
DSNEOF:	OR	AL,AL		;clear carry (no eof)
	RET	

;DSKINP - get next byte from file [SI]
; Exit  - Carry set if EOF, else [AL]=next byte from file
;         All other registers preserved
;
DSKINP:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_RND
	JNE	SINP1		;Brif not Random
	JMP	SHORT SINP50	;Do Serial input from random
SINP1:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQO	;If trying input on output file
	JE	FILLS1		; then give "Input past end"
	CMP	BYTE PTR F_BREM[SI],LOW 0
	JE	FILLSQ		;If buffer empty, get another
	PUSH	BX
	XOR	BX,BX
	MOV	BL,BYTE PTR F_ORCT[SI]
	SUB	BL,BYTE PTR F_BREM[SI]
	DEC	BYTE PTR F_BREM[SI]	;number left -1
	MOV	AL,BYTE PTR DATOFS[BX+SI]	;Get the character
	POP	BX
	OR	AL,AL		;Clear carry
	RET	
FILLSQ:
	CMP	BYTE PTR F_ORCT[SI],LOW 0
	JE	FILLS1		;Brif EOF
	CALL	$READS		;read next sector
	JNE	SINP1		;If not EOF try again
FILLS1:
	STC			;Return with carry
	MOV	AL,LOW OFFSET ASCCTZ	; and EOF character
	RET	

SINP50:				;Serial Input from Random File
	PUSH	BX
	CALL	FOVCHK		;Field overflow check
	MOV	AL,BYTE PTR FD_DAT-1[BX+SI]	;Get character
	CLC	
	POP	BX
	RET	
FOVCHK:
	MOV	BX,WORD PTR FD_OPS[SI]	;Get current posn
	CMP	BX,WORD PTR FD_SIZ[SI]	;check for end of field
	JE	ER_FOV		;Brif field overflow
	INC	BX		;posn +1
	MOV	WORD PTR FD_OPS[SI],BX	;store new posn
	RET	
ER_FOV:
	JMP	DERFOV		;"Field Overflow"

	SUBTTL Disk Sequential Output

;DSKSOT - Sequential Output.
; Entry - SI points to File-Data-Block.
;         [AL] = byte to be output.
; Exit  - All registers preserved.
;
DSKSOT:
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_SQI	;If input then must be echoing
	JZ	FILOUX		; or "Extra ignored", so toss it
	CMP	BYTE PTR F_MODE[SI],LOW OFFSET MD_RND
	JNZ	FILOU4		;branch if sequential access
	PUSH	BX		;Do Serial output to random
	CALL	FOVCHK		;check for FIELD overflow
	MOV	BYTE PTR FD_DAT-1[BX+SI],AL	;store character
	POP	BX
	JMP	SHORT SOUTPS	;Update posn and exit
FILOU4:
        cmp byte ptr FD_CHAR[si],0
        je BufferedOutput
        ; Keep an unacknowledged byte across ON ERROR and RESUME. A later
        ; write or CLOSE retries it before appending the next byte.
        cmp byte ptr F_ORCT[si],0
        je DeviceAppend
        call WriteDeviceByte
DeviceAppend:
        ; Count a new byte before issuing the request. RESUME can inspect LOC
        ; after a failed write. Retrying the pending byte does not advance it.
        inc word ptr F_CLOC[si]
        add word ptr FCB_FS[si],1
        adc word ptr FCB_FS+2[si],0
        mov byte ptr DATOFS[si],al
        mov byte ptr F_ORCT[si],1
        call WriteDeviceByte
        jmp short SOUTPS
WriteDeviceByte:
        push ax
        push bx
        push cx
        push dx
        lea dx,DATOFS[si]
        mov cx,1
        mov ah,40h
        call DeviceIO
        cmp ax,cx
        jne DeviceWriteError
        pop dx
        pop cx
        pop bx
        mov byte ptr F_ORCT[si],0
        pop ax
        ret
DeviceWriteError:
        jmp DERIOE
BufferedOutput:
	CMP	BYTE PTR F_ORCT[SI],LOW OFFSET DATPSC
	JNE	SOUT2		;Brif not at end of sector
	CALL	$WRITS		;Write previous sector
SOUT2:
	PUSH	BX
	XOR	BX,BX
	MOV	BL,BYTE PTR F_ORCT[SI]	;[BX] = Buffer offset
	MOV	BYTE PTR DATOFS[BX+SI],AL	;store char
	POP	BX
	INC	BYTE PTR F_ORCT[SI]
SOUTPS:
	CMP	AL,LOW OFFSET ASCCR
	JNE	SOUT3
	MOV	BYTE PTR F_POS[SI],LOW 0	;reset posn on CR
FILOUX:
	RET	

SOUT3:
	CMP	AL,LOW " "
	CMC	
	ADC	BYTE PTR F_POS[SI],LOW 0	;posn +1  if printable char
	RET	


	SUBTTL GET and PUT for Disk Files

	PGFLAG=1		;On = PUT, Off = GET
	RELFLG=2		;On = Relative, Off = Sequential

ER_BRN:	JMP	DERBRN		;bad record number error

;DSKRND - perform random I/O.
; Entry  - [AL] = function to be performed:
;                 0: get next record
;                 1: put next record
;                 2: get record [DX] (1-relative)
;                 3: put record [DX] (1-relative)
;          [SI] points to File-Data-Block
; Exit   - All registers are used.
;
DSKRND:
	TEST	AL,LOW OFFSET RELFLG
	JNZ	RAND1		;Brif not relative I/O
	MOV	DX,WORD PTR FD_LOG[SI]	;[DX] = current logical record
	INC	DX		;Logical +1
	JMP	SHORT RAND2
RAND1:
	OR	DX,DX		;See if ok
	JLE	ER_BRN		;Error if record number .LEQ. 0
RAND2:
	MOV	WORD PTR FD_LOG[SI],DX	;Store next logical
	DEC	DX		;[DX] = current logical
	MOV	WORD PTR FD_OPS[SI],0	;Clear output posn
	MOV	BX,WORD PTR FD_SIZ[SI]	;[BX] = logical record length
        cmp byte ptr FD_CHAR[si],0
        jne RandomTransfer
        push ax
        mov ax,bx
        mul dx                  ; (record - 1) * record size
        mov cx,dx
        mov dx,ax
        call HandleSeek
        pop ax
RandomTransfer:
        push ax
        mov cx,FD_SIZ[si]
        lea dx,FD_DAT[si]
        mov ah,3fh
        test al,PGFLAG
        jz RandomDevice
        mov ah,40h
RandomDevice:
        call DeviceIO
        pop bx                  ; Original GET/PUT flags.
        cmp byte ptr FD_CHAR[si],0
        jne DeviceRecordSize
        test bl,PGFLAG
        jnz UpdateRecordSize
        sub cx,ax               ; A short random read pads the FIELD with zeros.
        mov di,dx
        add di,ax
        xor ax,ax
        rep stosb
        ret
UpdateRecordSize:
        cmp ax,cx
        jne DeviceWriteErrorFar
        mov ax,FD_LOG[si]
        mul word ptr FD_SIZ[si]
ExtendLength:
        cmp dx,word ptr FCB_FS+2[si]
        jb DeviceRecordDone
        ja StoreRecordSize
        cmp ax,word ptr FCB_FS[si]
        jbe DeviceRecordDone
StoreRecordSize:
        mov word ptr FCB_FS[si],ax
        mov word ptr FCB_FS+2[si],dx
        ret
DeviceRecordSize:
        cmp ax,cx
        je DeviceRecordDone
DeviceWriteErrorFar:
        jmp DERIOE
DeviceRecordDone:
        ret
	SUBTTL Primitive Disk sector I/O routines

;$READS - Read sector from file
; Entry - SI points to FDB
; Exit  - [AL] = 0 if no error.  FLAGS used.
;         All other registers are preserved
;
$READS:
	PUSH	CX
	PUSH	DI
	MOV	CX,OFFSET DATPSC/2
	XOR	AX,AX
	LEA	DI,DWORD PTR DATOFS[SI]
	CLD			;Set Post-Increment mode
 REP	STOSW			;zero physical buffer
        push bx
        push dx
        cmp byte ptr FD_CHAR[si],0
        jne HandleRead
        call SectorSeek
HandleRead:
        mov cx,DATPSC
        lea dx,DATOFS[si]
        mov ah,3fh
        call DeviceIO
        pop dx
        pop bx
        call AdvanceSector
	MOV	BYTE PTR F_ORCT[SI],AL	;Clear offset into buffer
	MOV	BYTE PTR F_BREM[SI],AL	;Set number of bytes left
	OR	AL,AL		;zero if EOF
	POP	DI
	POP	CX
	RET	

;$WRITS - Write sector to file
; Entry - SI points to FDB
; Exit  - All registers preserved
;
$WRITS: PUSH AX
        push bx
        push cx
        push dx
        call SectorSeek
        xor cx,cx
        mov cl,F_ORCT[si]
        lea dx,DATOFS[si]
        mov ah,40h
        call DeviceIO
        cmp ax,cx
        jne HandleDiskFull
        pop dx
        pop cx
        pop bx
        mov byte ptr F_ORCT[si],0
        call AdvanceSector
        pop ax
        ret
HandleDiskFull:
        jmp DERDFL

; Commit the file position only after DOS completed the transfer. A failed
; buffered write must still address the same sector when BASIC retries it.
AdvanceSector:
        add word ptr FCB_RN[si],1
        adc word ptr FCB_RN+2[si],0
        inc word ptr F_CLOC[si]
        ret

; Seek to the next 128-byte sector (also used to reposition for APPEND).
SectorSeek:
        mov ax,word ptr FCB_RN[si]
        mov dx,word ptr FCB_RN+2[si]
        call SectorBytes
        mov cx,dx
        mov dx,ax
HandleSeek:
        mov ax,4200h
        jmp DeviceIO

SectorBytes:
        mov cl,7
SeekShift:
        shl ax,1
        rcl dx,1
        dec cl
        jnz SeekShift
        ret

	SUBTTL CHKFOP - Check for file already OPEN

DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	STKLOW:WORD
DSEG	ENDS

; OPEN, KILL and NAME compare the saved drive and the 8.3 filename.
ResolveDrive:
        cmp byte ptr FCB_DV[si],0
        jne DriveReady
        CALLOS C_GDRV
        inc al
        mov FCB_DV[si],al
DriveReady:
        ret

; SI points to the FDB to check. Uses CX and DI.
CHKFOP:
        push ax
        call ResolveDrive
	push    si
        extrn FirstFile:near
        call FirstFile
        mov di,si
        pop si
CHKNFL:
	CMP	DI,WORD PTR STKLOW
	JE	CHKFLX		;branch if at end of FDB chain
	CMP	SI,DI
	JE	IGNTFL		;branch if same as FDB in question
	PUSH	SI
	PUSH	DI
	ADD	SI,OFFSET F_FCB
	ADD	DI,OFFSET F_FCB
	MOV	CX,OFFSET FNAML+1
;compare filenames, mapping lower case to upper case
CMPLOP:
	MOV	AL,BYTE PTR 0[SI]	;get char from filename1
	CALL	MAKUPC		;[AL]=uppercase([AL])
	MOV	AH,AL
	MOV	AL,BYTE PTR 0[DI]	;get char from filename2
	CALL	MAKUPC		;[AL]=uppercase([AL])
	CMP	AL,AH
	JNE	NTSAME		;branch if not the same filename
	INC	SI		;bump filename1 pointer
	INC	DI		;bump filename2 pointer
	LOOP	CMPLOP		;compare all characters in filenames
	JMP	DERFAO		;error, file already open
NTSAME:	POP	DI
	POP	SI
IGNTFL:
	MOV	DI,WORD PTR F_NEXT[DI]	;get next FDB in chain
	JMP	SHORT CHKNFL
CHKFLX:
	POP	AX
	RET	

MAKUPC:
	CMP	AL,LOW "a"
	JB	NOTLC		;branch if not a..z
	CMP	AL,LOW OFFSET "z"+1
	JNB	NOTLC		;branch if not a..z
	AND	AL,LOW 337O	;map a..z to A..Z
NOTLC:
	RET	

	SUBTTL  PROSAV - Protected SAVE
	PUBLIC	PROSAV,CMPFBC
	EXTRN	SCCPTR:NEAR,GTMPRT:NEAR,BINPSV:NEAR,$EXPCN:NEAR,$LOGP:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	TXTTAB:WORD,VARTAB:WORD,CURLIN:WORD,PROFLG:WORD,TEMP:WORD
DSEG	ENDS

PROSAV:	CALL	CHRGTR		;skip "P"
	MOV	WORD PTR TEMP,BX	;Save text pointer
	CALL	SCCPTR		;Get rid of GOTO pointers
	CALL	PENCOD		;Encode binary
	MOV	AL,LOW 254D	;ID byte for Protected files
	CALL	BINPSV		;Do the SAVE
	CALL	PDECOD		;Decode binary
	JMP	GTMPRT		;return to NEWSTT

GETFSZ:	MOV	BX,OFFSET FD_SIZ	;Point to record size
	JMP	SHORT GETFP1	;Continue
GETFPS:	MOV	BX,OFFSET FD_OPS	;Point to output position
GETFP1:	ADD	BX,CX		;Add offset into buffer
	MOV	DX,WORD PTR 0[BX]	;Get value
	RET	

CMPFBC:	MOV	CX,BX		;Copy file data block into [CX]
CMPFPS:	CALL	GETFPS		;Get present posit
	PUSH	DX		;Save it
	CALL	GETFSZ		;Get file size
	MOV	BX,DX		;into [BX]
	POP	DX		;Get back posit
	CMP	BX,DX		;See if were at end
RET12:	RET	

	N1=11D			;Number of bytes to use from ATNCON
	N2=13D			;Number of bytes to use from SINCON

	PUBLIC	PENCOD
PENCOD:	MOV	CX,OFFSET N1+N2*256D	;Initialize both counters
	MOV	BX,WORD PTR TXTTAB	;Starting point
	MOV	DX,BX		;Into [DX]
ENCDBL:	MOV	BX,WORD PTR VARTAB	;At end?
	CMP	BX,DX		;Test
	JZ	RET12		;Yes
	MOV	BX,OFFSET $EXPCN
	MOV	AL,CL		;Use [CL] to index into it
	CBW	
	ADD	BX,AX
	MOV	SI,DX
	CLD			;Set Post-Increment mode
	LODSB			;[AL]=byte from program
	SUB	AL,CH		;Subtract counter for no reason
	XOR	AL,BYTE PTR CS:0[BX]	;XOR entry
	PUSH	AX		;Save result
	MOV	BX,OFFSET $LOGP
	MOV	AL,CH
	CBW	
	ADD	BX,AX
	POP	AX		;Get back current byte
	XOR	AL,BYTE PTR CS:0[BX]	;XOR on this one too
	ADD	AL,CL		;Add counter for randomness
	MOV	DI,DX
	CLD			;Set Post-Increment mode
	STOSB			;store back in program
	INC	DX		;Incrment pointer
	DEC	CL		;decrment first table index
	JNZ	CNTZER		;Still non-Zero
	MOV	CL,LOW OFFSET N1	;Re-initialize counter 1
CNTZER:	DEC	CH		;dedecrement counter-2
	JNZ	ENCDBL		;Still non-zero, go for more
	MOV	CH,LOW OFFSET N2	;Re-initialize counter 2
	JMP	SHORT ENCDBL	;Keep going until done
	PUBLIC	PROLOD
PROLOD:
PDECOD:	MOV	CX,OFFSET N1+N2*256	;Initialize both counters
	MOV	BX,WORD PTR TXTTAB	;Starting point
	MOV	DX,BX		;Into [D,E]
DECDBL:	MOV	BX,WORD PTR VARTAB	;At end?
	CMP	BX,DX		;Test
	JZ	RET12		;Yes
	MOV	BX,OFFSET $LOGP
	MOV	AL,CH
	CBW	
	ADD	BX,AX
	MOV	SI,DX
	CLD			;Set Post-Increment mode
	LODSB			;[AL]=byte from program
	SUB	AL,CL		;Subtract counter for randomness
	XOR	AL,BYTE PTR CS:0[BX]	;XOR on this one too
	PUSH	AX		;Save result
	MOV	BX,OFFSET $EXPCN
	MOV	AL,CL		;Use [CL] to index into it
	CBW	
	ADD	BX,AX
	POP	AX		;Get back current byte
	XOR	AL,BYTE PTR CS:0[BX]	;XOR entry
	ADD	AL,CH		;Add counter for no reason
	MOV	DI,DX
	CLD			;Set Post-Increment mode
	STOSB			;store [AL] back in program
	INC	DX		;Increment pointer
	DEC	CL		;decrment first table index
	JNZ	CNTZR2		;Still non-Zero
	MOV	CL,LOW OFFSET N1	;Re-initialize counter 1
CNTZR2:	DEC	CH
	JNZ	DECDBL		;Decrement counter-2, Still non-zero, go for more
	MOV	CH,LOW OFFSET N2	;Re-initialize counter 2
	JMP	SHORT DECDBL	;Keep going until done

	PUBLIC	PROCHK,PRODIR
PRODIR:	PUSH	BX		;Save [H,L]
	MOV	BX,WORD PTR CURLIN	;Get current line #
	INC	BX		;Direct? (if BX=0, direct)
	POP	BX		;Restore [H,L]
	JZ	PROCHK
	RET	

PROCHK:	PUSHF			;Save flags
	MOV	AL,BYTE PTR PROFLG	;Is this a protected file?
	OR	AL,AL		;Set CC's
	JNZ	FCERRA		;Yes, give error
	POPF			;Restore flags
	RET	

FCERRA:	JMP	FCERR
	PAGE	
	SUBTTL  KILL, FILES, NAME commands

	PUBLIC	FILES,KILL,NAME
	EXTRN	FRMEVL:NEAR,FRESTR:NEAR,CRDO:NEAR,POLKEY:NEAR
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	LINLEN:WORD,BUF:WORD
DSEG	ENDS

;Assumptions:
; FILNAM and FILNA2 are 33 byte buffers (for temp FCBs)

; FILES [filespec]. DOS returns the 8.3 name and attributes in the DTA.
DSEG segment public 'DATASG'
        extrn FilesDTA:byte
FilesDrive db ?
DSEG ends
        extrn PTRWID:near,CRDONZ:near,STROUT:near
FILES:
        cld                     ; Direct-mode line editing can leave DF set.
        mov di,offset DirPath
        je FilesWildcard
        call NAMFIL
        mov di,offset DirPath
        cld
        rep movsb
        cmp byte ptr [di-1],':'
        je FilesWildcard
        cmp byte ptr [di-1],'\'
        jne FilesPathEnd
FilesWildcard:
        mov ax,'.*'
        stosw
        mov al,'*'
        stosb
FilesPathEnd:
        mov byte ptr [di],0
        push bx                 ; BASIC text pointer
        mov ah,19h
        int 21h
        cmp byte ptr DirPath+1,':'
        jne FilesDriveSet
        mov al,DirPath
        and al,0dfh
        sub al,'A'
FilesDriveSet:
        inc al
        mov FilesDrive,al
        mov dl,al
        mov si,offset FilesDTA
        mov ah,47h
        int 21h
        jc FilesBadPath
        mov al,FilesDrive
        add al,'A'-1
        call OUTDO
        mov al,':'
        call OUTDO
        mov al,'\'
        call OUTDO
FilesPathChar:
        lodsb
        or al,al
        jz FilesFirst
        call OUTDO
        jmp short FilesPathChar
FilesBadPath:
        jmp ER_FNF
FilesFirst:
        call CRDO
        mov dx,offset DirPath
        mov cx,10h              ; Include subdirectories.
        mov ah,4eh
        call FilesFind
        jc FilesBadPath
        xor di,di               ; Columns used by completed entries on this line.
FilesEntry:
        call POLKEY
        mov si,offset FilesDTA+30
        mov cx,8
FilesStem:
        lodsb
        or al,al
        jz FilesPadStem
        cmp al,'.'
        je FilesPadStem
        call OUTDO
        loop FilesStem
        lodsb
FilesPadStem:
        mov dl,al
        mov al,' '
        jcxz FilesExtension
FilesPad:
        call OUTDO
        loop FilesPad
FilesExtension:
        mov cx,4
        cmp dl,'.'
        jne FilesPadExt
        mov al,dl
FilesExtChar:
        call OUTDO
        dec cx
        lodsb
        or al,al
        jnz FilesExtChar
FilesPadExt:
        mov al,' '
        jcxz FilesAttr
FilesFill:
        call OUTDO
        loop FilesFill
FilesAttr:
        mov bx,offset FilesPlain
        test FilesDTA+21,10h
        jz FilesSuffix
        mov bx,offset FilesDir
FilesSuffix:
        call STROUT
        add di,18               ; Start column of the next entry.
        lea dx,[di+18]
        call PTRWID             ; AH = output width.
        mov al,ah
        xor ah,ah
        cmp dx,ax               ; Room for another complete entry?
        ja FilesEndRow
        mov al,' '
        call OUTDO
        jmp short FilesNext
FilesEndRow:
        call CRDO
        xor di,di
FilesNext:
        mov ah,4fh
        call FilesFind
        jnc FilesEntry
        cmp ax,18               ; No more files.
        je FilesComplete
        jmp ER_FNF
FilesComplete:
        call CRDONZ
        mov dl,FilesDrive
        mov ah,36h
        int 21h
        cmp ax,0ffffh
        je FilesBadDrive
        mul cx                  ; AX = bytes/cluster on DOS FAT volumes.
        mul bx                  ; DX:AX = bytes available.
        push ax
        mov al,' '
        call OUTDO
        pop ax
        mov bx,10
        call FilesDecimal
        mov bx,offset FilesFree
        call STROUT
        call CRDO
        call CRDO
        pop bx
        ret
FilesBadDrive:
        jmp ER_FNF
FilesPlain db '     ',0
FilesDir   db '<DIR>',0
FilesFree  db ' Bytes free',0

; Convert unsigned DX:AX without losing precision on large volumes.
FilesDecimal:
        mov si,ax
        mov ax,dx
        xor dx,dx
        div bx
        xchg ax,si
        div bx
        push dx
        mov dx,si
        or si,ax
        jz FilesDigit
        call FilesDecimal
FilesDigit:
        pop ax
        add al,'0'
        jmp OUTDO

; Install the search DTA only for the DOS call. BASIC output and break
; handling run with the caller's DTA even if they unwind the BASIC stack.
FilesFind:
        push ds
        push es
        push di
        push si
        mov di,ax
        mov si,dx
        mov ah,2fh
        int 21h
        push es
        push bx
        mov dx,offset FilesDTA
        mov ah,1ah
        int 21h
        mov ax,di
        mov dx,si
        int 21h
        pop dx
        pop ds
        pushf
        push ax
        mov ah,1ah
        int 21h
        pop ax
        popf
        pop si
        pop di
        pop es
        pop ds
        ret

;KILL filename
; Entry - [BX] = text pointer
; Exit -  [BX] = text pointer
;
KILL:
	CALL	NAMFIL		;[SI] points to 1st byte of filename
				;[CX] = number of bytes in filename
	CALL	FILFCB		;FILNAM=un-opened FCB for filename
	PUSH	BX		;save text pointer
	MOV	DX,OFFSET FILNAM
	PUSH	DX		;Save FCB pointer
	CALLOS	C_OPEN		;Open file
	INC	AL
	JNZ	KILL2		;Brif file found
	JMP	ER_FNF		;File not found
KILL2:	POP	DX		;DX points to FCB
	PUSH	DX
	CALLOS	C_CLOS		;Close file
	MOV	SI,OFFSET FILNAM-F_FCB	;Pretend we are FDB
	CALL	CHKFOP		;Check for conflict with open files
				;jumps to error if file is now opened
	POP	DX		;DX points to FCB
	CALLOS	C_DELE		;Delete file
	POP	BX		;text pointer
	RET	

;NAME oldname AS newname
; Entry - [BX] = text pointer
; Exit  - [BX] = text pointer
;
NAME:
	CALL	NAMFIL		;[SI] points to 1st byte of old filename
				;[CX] = number of bytes in filename
	PUSH	BX		;save text pointer
	CALL	FILFCB		;FILNAM=un-opened FCB for old filename
	MOV	DX,OFFSET FILNA2	;tells OS to put FCB for matching directory
	CALLOS	C_BUFF		; entries in FILNA2
	MOV	DX,DI		;[DX] = search FCB (FILNAM)
	CALLOS	C_SEAR		;Search 1st
	INC	AL
	JZ	NA_FNF		;File not found
	MOV	SI,OFFSET FILNAM-F_FCB	;Pretend we are FDB
	CALL	CHKFOP		;Check for conflict with open files
				;jumps to error if file is now opened
	MOV	SI,OFFSET FILNAM	;save old filename in FILNA2
	MOV	DI,OFFSET FILNA2
	MOV	CX,OFFSET FNAML+1	;+1 for drive
	CLD			;Set Post-Increment mode
 REP	MOVSB			;Move drive,name,ext from FILNAM to FILNA2
	POP	BX		;text pointer
	CALL	SYNCHR
	DB	OFFSET "A"	; must see "AS"
	CALL	SYNCHR
	DB	OFFSET "S"
	CALL	NAMFIL		;[SI] points to 1st byte of newfilename
				;[CX] = number of bytes in filename
	PUSH	BX		;text pointer
	CALL	FILFCB		;FILNAM=un-opened FCB for new filename
	MOV	AL,BYTE PTR FILNAM	;[AL]=drive for New filename
	OR	AL,AL		;test drive id of New filename
	JZ	SAMDRV		;branch if default drive
	CMP	AL,BYTE PTR FILNA2	;Compare with drive of original name
	JZ	SAMDRV		;branch if both drives are the same
EXTRN	DERRAD:NEAR
	JMP	DERRAD		;Rename Across Disks Error
SAMDRV:
	MOV	SI,OFFSET FILNAM+1	;move new filename,ext to FILNA2+17
	MOV	DI,OFFSET FILNA2+17D	;[DI] = dest for new file name
	MOV	CX,OFFSET FNAML	;No drive code
	CLD			;Set Post-Increment mode
 REP	MOVSB			;Move name
	MOV	DX,OFFSET FILNA2	;Point to FCB which contains both filenames
	CALLOS	C_RENA		;Rename file
	INC	AL		;error if attempted to create file which
	JE	NA_FAE		; already existed
	POP	BX		;text pointer
	RET	

NA_FNF:	JMP	ER_FNF		;file not found
NA_FAE:	CALL	SaveDosError
	JMP	DERFAE		;file already exists

; Directory statements adapted from TK Chia's GWBASICA DOS backend.
        PUBLIC MKDIR,RMDIR,CHDIR
        EXTRN ERRACC:ABS,ERRPNF:ABS,ERROR:NEAR
MKDIR:  mov ah,39h
        jmp short DirectoryCall
RMDIR:  mov ah,3ah
        jmp short DirectoryCall
CHDIR:  mov ah,3bh
DirectoryCall:
        push ax
        call NAMFIL
        mov dx,offset DirPath
        mov di,dx
        cld
        rep movsb
        xor al,al
        stosb
        pop ax
        push bx
        int 21h
        pop bx
        jnc DirectoryDone
        mov dl,offset ERRPNF
        cmp ax,2                ; DOS can report either file or path missing.
        je DirectoryError
        cmp ax,3
        je DirectoryError
        mov dl,offset ERRACC
DirectoryError:
        call SaveDosError
        jmp ERROR
DirectoryDone:
        ret

;NAMFIL - Scan a file name for NAME, KILL, or FILES command
; Entry - [BX] = text pointer
; Exit  - [BX] = text pointer
;         [SI] points to 1st byte of filename
;         [CX] = number of bytes in filename string
; Uses  - [AX]
;
NAMFIL:
	CALL	FRMEVL		;Evaluate string
	PUSH	BX		;save text pointer
	CALL	FRESTR		;Free the temp
	MOV	CL,BYTE PTR 0[BX]
	XOR	CH,CH		;[CX] = String len
	JCXZ	ER_NMF		;If null then bad name
	MOV	SI,WORD PTR 1[BX]	;[SI] = Filename string
	POP	BX
	RET	

ER_NMF:	JMP	DERNMF		;"Bad file name"

;FILFCB - Given filename "d:name:ext", create an un-opened FCB
; Entry - [SI] = points 1st byte of filename
;         [CX] = number of bytes in filename string
; Exit  - FILNAM is un-opened FCB equivalent for filename
;         [DI] points to 1st byte of FCB FILNAM
;         [AL] = FF if illegal drive or filename,
;                 1 if filename contained any "?" or "*" characters
;                 0 otherwise
; Uses  - BUF
;
FILFCB:
	MOV	DI,OFFSET BUF	;move filename to BUF buffer
	CLD			;Set Post-Increment mode

STRTNM:	XOR	AH,AH		;Count of chars in name portion:=0.
NAMORE:	OR	CX,CX		;Anything left?
	JE	TRMSTR		;No, go terminate the string in BUF.
	MOV	AL,BYTE PTR 0[SI]	;Yes, AL:=get next char of string.
	MOVSB			;Copy it to BUF.
	DEC	CX		;Decrement the length.
	CMP	AL,LOW ":"	;Colon indicating we were looking at a
				;device name?
	JE	STRTNM		;Yes, restart the count since we are now
				;looking at the filename.
	CMP	AL,LOW "."	;No, dot indicating start of extension?
	JE	FINNAM		;Yes, end of name.
	CMP	AL,LOW "*"	;The asterisk wild card also terminates the
	JE	FINNAM		;name for our purposes.
	CMP	AH,LOW 8D	;Have we already seen 8 name characters?
	JAE	LNGNAM		;Yes, the excess chars become the extension.
	INC	AH		;No, increment the name character count.
	JMP	SHORT NAMORE	;Go look at the next char.

LNGNAM:	MOV	BYTE PTR -1[DI],LOW "."	;Put in the dot so the extra chars look
	MOV	BYTE PTR 0[DI],AL	;like an extension.
	INC	DI
FINNAM:	OR	CX,CX		;Anything left?
	JE	TRMSTR		;No, terminate the string.  (Avoid REP with
                     ;a zero count.)
 REP	MOVSB			;Copy the remainder of the string to BUF.
TRMSTR:	MOV	BYTE PTR 0[DI],LOW 0	;store string terminator
	MOV	SI,OFFSET BUF	;parse 0 terminated filename in BUF
	MOV	DI,OFFSET FILNAM	; filling FDB FILNAM
	XOR	AL,AL		; don't skip any separators
	CALLOS	C_PARS
	OR	AL,AL		;test for legal filename
	JNE	FLFCBX		;branch if error or non-empty filename
	CMP	BYTE PTR FILNAM+1,LOW " "	;test 1st byte of filename
	JNE	FLFCBX		;branch if non-empty filename
	DEC	AL		;[AL] = FF (illegal filename)
FLFCBX:
	RET	

	SUBTTL  RESET and SYSTEM statements
;
; Entry/exit:   [BX] = text pointer

	PUBLIC	RESET
	EXTRN	CLSALL:NEAR,TKEYOF:NEAR

RESET:
	JNZ	RESETX		;if wasn't EOS
	PUSH	BX		;text pointer
	CALL	CLSALL		;Close all files
	CALLOS	C_GDRV		;Get drive number
	PUSH	AX
	CALLOS	C_REST		;Restore
	POP	AX
	MOV	DL,AL
	CALLOS	C_SDRV		;Set drive number
	POP	BX		;text pointer
RESETX:
	RET	


; SYSTEM - Exit BASIC

	PUBLIC	SYSTEM,SYSTME

	EXTRN	GWTERM:NEAR

SYSTEM:
	JNZ	RESETX		;If wasn't EOS
	CALL	CLSALL		;Close all files
SYSTME:
EXTRN	GIOTRM:NEAR
	CALL	GIOTRM		;call device termination routines
	CALL	GWTERM		;Do OEM specific termination processing
DSEG	SEGMENT PUBLIC 'DATASG'
	EXTRN	CPMEXT:WORD	;MSDOS exit jump vector.
DSEG	ENDS
;translator can't handle JMPI ,adr yet
	PUSH	WORD PTR CPMEXT+2	;put segment adr on stack
	PUSH	WORD PTR CPMEXT	;put offset on stack
dumy  PROC    FAR
	RET			;intra-segment return
dumy  ENDP

CSEG	ENDS
	END
