_TEXT	SEGMENT BYTE PUBLIC 'CODE'
	ASSUME	CS:_TEXT
	PUBLIC	_XmsPool

; Caller supplies three zeroed DWORDs: total, free and largest free KB.
; Return 0 for no XMS, 1 for free-space data, 2 for a table-based total.
_XmsPool PROC NEAR
	PUSH	BP
	MOV	BP,SP
	PUSH	SI
	PUSH	DI
	MOV	AX,4300h
	INT	2Fh
	CMP	AL,80h
	JE	XmsPresent
	XOR	AX,AX
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
	JNE	XmsFreeOnly
	CMP	WORD PTR ES:[BX],0A01h
	JNE	XmsFreeOnly
	MOV	CX,ES:[BX+2]
	LES	SI,ES:[BX+4]
	JCXZ	XmsTotal
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
XmsTotal:
	MOV	AX,2
	JMP	SHORT XmsExit
XmsFreeOnly:
	MOV	AX,1
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
