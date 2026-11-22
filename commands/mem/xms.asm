_TEXT	SEGMENT BYTE PUBLIC 'CODE'
	ASSUME	CS:_TEXT
	PUBLIC	_XmsPool

; Caller supplies three zeroed DWORDs: total, free and largest free KB.
_XmsPool PROC NEAR
	PUSH	BP
	MOV	BP,SP
	PUSH	SI
	PUSH	DI
	MOV	AX,4300h
	INT	2Fh
	CMP	AL,80h
	JE	XmsPresent
	JMP	XmsDone
XmsPresent:
	MOV	AX,4310h
	INT	2Fh
	PUSH	ES
	PUSH	BX			; XMS entry at SS:[BP-8]
	MOV	DI,[BP+4]
	XOR	AH,AH
	CALL	DWORD PTR [BP-8]
	OR	AX,AX			; UMB-only provider
	JZ	XmsExit
	MOV	AH,08h
	XOR	DX,DX
	CALL	DWORD PTR [BP-8]
	MOV	[DI+8],AX
	MOV	[DI+4],DX
	MOV	[DI],DX

; HIMEM exports its handle table via INT 2Fh/4309h. Used entries
; describe allocated extended memory, even when the free pool is empty.
	MOV	AX,4309h
	INT	2Fh
	CMP	AL,43h
	JNE	XmsScan
	CMP	WORD PTR ES:[BX],0A01h
	JNE	XmsScan
	MOV	CX,ES:[BX+2]
	LES	SI,ES:[BX+4]
	JCXZ	XmsExit
XmsTable:
	CMP	BYTE PTR ES:[SI],2
	JNE	XmsNext
	MOV	AX,ES:[SI+6]
	ADD	[DI],AX
	MOV	AX,ES:[SI+8]
	ADC	[DI+2],AX
XmsNext:
	ADD	SI,10
	LOOP	XmsTable
	JMP	SHORT XmsExit

; Other XMS 2 managers expose block sizes through function 0Eh.
; Handles are opaque 16-bit values; gaps do not indicate the end.
XmsScan:
	XOR	SI,SI
XmsHandle:
	INC	SI
	JZ	XmsExit
	MOV	DX,SI
	MOV	AH,0Eh
	CALL	DWORD PTR [BP-8]
	OR	AX,AX
	JZ	XmsInvalid
	ADD	[DI],DX
	ADC	WORD PTR [DI+2],0
	JMP	SHORT XmsHandle
XmsInvalid:
	CMP	BL,80h			; handle information unsupported
	JNE	XmsHandle
XmsExit:
	ADD	SP,4
XmsDone:
	POP	DI
	POP	SI
	POP	BP
	RET
_XmsPool ENDP
_TEXT	ENDS
	END
