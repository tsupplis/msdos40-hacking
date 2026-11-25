; Run twice from COMMAND on a DOS=UMB boot. The first child leaves all
; upper memory allocated on exit. The second must recover the same extent.
; Report the payload segment and largest free UMB size in paragraphs.
CODE SEGMENT PARA PUBLIC 'CODE'
	ASSUME	CS:CODE,DS:CODE
Start:
	; Return unused conventional memory before testing high-first fallback.
	MOV	BX,SS
	MOV	AX,ES
	SUB	BX,AX
	ADD	BX,16
	MOV	AH,4Ah
	INT	21h
	PUSH	CS
	POP	DS
	MOV	AX,5800h
	INT	21h
	JC	EarlyFailure
	MOV	OldStrategy,AX
	MOV	AX,5802h
	INT	21h
	JC	EarlyFailure
	XOR	AH,AH
	MOV	OldLink,AX
	MOV	AX,5803h
	MOV	BX,1
	INT	21h
	JC	EarlyFailure
	JMP	SHORT SetUpperOnly
EarlyFailure:
	JMP	Failed
SetUpperOnly:
	MOV	AX,5801h
	MOV	BX,40h
	INT	21h
	JNC	UpperOnlyReady
	JMP	RestoreLink
UpperOnlyReady:
	MOV	AH,48h
	MOV	BX,64
	INT	21h
	JC	RestoreStrategy
	CMP	AX,0A000h
	JB	RestoreStrategy
	CALL	PrintHex
	MOV	ES,AX
	MOV	WORD PTR ES:[1022],0A55Ah
	CMP	WORD PTR ES:[1022],0A55Ah
	JNE	RestoreStrategy
	MOV	AH,4Ah
	MOV	BX,128
	INT	21h
	JC	RestoreStrategy
	MOV	AH,49h
	INT	21h
	JC	RestoreStrategy
	MOV	AH,48h
	MOV	BX,0FFFFh
	INT	21h
	JNC	RestoreStrategy
	CMP	AX,8
	JNE	RestoreStrategy
	MOV	AX,BX
	CALL	PrintHex
TakeRegion:
	MOV	AH,48h
	INT	21h
	JC	RestoreStrategy
 ; Smaller regions can remain after the largest allocation.
        MOV     BX,0FFFFh
        MOV     AH,48h
        INT     21h
        JNC     RestoreStrategy
        CMP     AX,8
        JNE     RestoreStrategy
        OR      BX,BX
        JNZ     TakeRegion
	MOV	AX,5801h
	MOV	BX,80h
	INT	21h
	JC	RestoreStrategy
	MOV	AH,48h
	MOV	BX,1
	INT	21h
	JC	RestoreStrategy
	CMP	AX,0A000h
	JAE	RestoreStrategy
	MOV	Status,0
RestoreStrategy:
	MOV	AX,5801h
	MOV	BX,OldStrategy
	INT	21h
	JNC	RestoreLink
	MOV	Status,1
RestoreLink:
	MOV	AX,5803h
	MOV	BX,OldLink
	INT	21h
	JC	Failed
	CMP	Status,0
	JNE	Failed
	MOV	DX,OFFSET PassMsg
	JMP	SHORT Report
Failed:
	MOV	Status,1
	MOV	DX,OFFSET FailMsg
Report:
	MOV	AH,9
	INT	21h
	MOV	AL,Status
	MOV	AH,4Ch
	INT	21h

PrintHex PROC NEAR
	PUSH	AX
	PUSH	BX
	MOV	BX,AX
	MOV	CX,4
NextDigit:
	ROL	BX,1
	ROL	BX,1
	ROL	BX,1
	ROL	BX,1
	MOV	DL,BL
	AND	DL,0Fh
	ADD	DL,'0'
	CMP	DL,'9'
	JBE	ShowDigit
	ADD	DL,7
ShowDigit:
	MOV	AH,2
	INT	21h
	LOOP	NextDigit
	MOV	DL,' '
	INT	21h
	POP	BX
	POP	AX
	RET
PrintHex ENDP

OldStrategy DW	0
OldLink	DW	0
Status	DB	1
PassMsg	DB	'UMB PASS',13,10,'$'
FailMsg	DB	'UMB FAIL',13,10,'$'
CODE ENDS
STACKSEG SEGMENT PARA STACK 'STACK'
	DW	128 DUP (?)
STACKSEG ENDS
	END	Start
