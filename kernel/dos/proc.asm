;	SCCSID = @(#)proc.asm	1.1 85/04/10
TITLE	IBMPROC - process maintenance
NAME	IBMPROC

;
; Process related system calls and low level routines for DOS 2.X.
; I/O specs are defined in DISPATCH.
;
;   $WAIT
;   $EXEC
;   $Keep_process
;   Stay_resident
;   $EXIT
;   $ABORT
;   abort_inner
;
;   Modification history:
;
;	Created: ARR 30 March 1983
;

.xlist
;
; get the appropriate segment definitions
;
include dosseg.asm

CODE	SEGMENT BYTE PUBLIC  'CODE'
	ASSUME	SS:DOSGROUP,CS:DOSGROUP

.xcref
INCLUDE DOSSYM.INC
INCLUDE DEVSYM.INC
.cref
.list

SAVEXIT 	EQU	10

    i_need  CurrentPDB,WORD
    i_need  CreatePDB,BYTE
    i_need  Exit_type,BYTE
    i_need  INDOS,BYTE
    i_need  DMAADD,DWORD
    i_need  DidCTRLC,BYTE
    i_need  exit_type,BYTE
    i_need  exit_code,WORD
    i_need  OpenBuf,128
    I_need  EXTERR_LOCUS,BYTE		; Extended Error Locus

IF	BUFFERFLAG
	extrn	restore_user_map:near
ENDIF

        EXTRN FCB_SELECTED:NEAR
        DosCodeEntry $Exec,102
        DosCodeEntry Reset_Version,103
        DosCodeEntry $WAIT,104
        DosCodeEntry $Keep_Process,105
        DosCodeEntry $EXIT,106
        DosCodeEntry $ABORT,107
        DosCodeEntry exit_inner,108

; DS:SI = child entry, AX:DI = child stack, DX = PSP, BX = initial AX.
; The resident callback has returned control to the kernel segment.
procedure StartChild,NEAR
	CLI
	MOV	BYTE PTR INDOS,0
	ASSUME	SS:NOTHING
	MOV	SS,AX			; set up user's stack
	MOV	SP,DI			; and SP
	STI
	PUSH	DS			; fake long call to entry
	PUSH	SI
	MOV	ES,DX			; set up proper seg registers
	MOV	DS,DX
	MOV	AX,BX			; set up proper AX


IF	BUFFERFLAG
	invoke	restore_user_map
ENDIF

	RETF
EndProc StartChild

	procedure   Stay_resident,NEAR
	ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	MOV	AX,(Keep_process SHL 8) + 0 ; Lower part is return code
	ADD	DX,15
	RCR	DX,1
	MOV	CL,3
	SHR	DX,CL

	transfer    COMMAND
EndProc Stay_resident

CODE ENDS

DOSCODE SEGMENT BYTE PUBLIC 'DOSCODE'
        ASSUME CS:DOSCODE,SS:DOSGROUP

SUBTTL $WAIT - return previous process error code
PAGE
;
; process control data
;
	i_need	exit_code,WORD		; code of exit

;
;   Assembler usage:
;	    MOV     AH, WaitProcess
;	    INT     int_command
;	  AX has the exit code
	procedure   GetExitStatus,NEAR
	ASSUME	DS:NOTHING,ES:NOTHING
	XOR	AX,AX
	XCHG	AX,exit_code
	CallResident SYS_RET_OK
	RET
EndProc GetExitStatus

include exec.asm

SUBTTL Terminate and stay resident handler
PAGE
;
; Input:    DX is  an  offset  from  CurrentPDB  at which to
;	    truncate the current block.
;
; output:   The current block is truncated (expanded) to be [DX+15]/16
;	    paragraphs long.  An exit is simulated via resetting CurrentPDB
;	    and restoring the vectors.
;
	procedure   KeepProcess,NEAR
	ASSUME DS:NOTHING,ES:NOTHING,SS:DOSGROUP

	PUSH	AX			; keep exit code around
	MOV	BYTE PTR [Exit_type],Exit_keep_process
	MOV	ES,[CurrentPDB]
	CMP	DX,6h			; keep enough space around for system
	JAE	Keep_shrink		; info
	MOV	DX,6h
keep_shrink:
	MOV	BX,DX
	PUSH	BX
	PUSH	ES
	invoke  ResizeBlock		; ignore return codes.
	POP	DS
	POP	BX
	JC	keep_done		; failed on modification
	MOV	AX,DS
	ADD	AX,BX
	MOV	DS:[PDB_block_len],AX

keep_done:
	POP	AX
	JMP	SHORT FinishProcess	; and let abort take care of the rest

EndProc KeepProcess

SUBTTL $EXIT - return to parent process
PAGE
;
;   Assembler usage:
;	    MOV     AL, code
;	    MOV     AH, Exit
;	    INT     int_command
;   Error return:
;	    None.
;
	procedure   ExitProcess,NEAR
	ASSUME	DS:NOTHING,ES:NOTHING,SS:DOSGROUP
	XOR	AH,AH
	XCHG	AH,BYTE PTR [DidCTRLC]
	OR	AH,AH
	MOV	BYTE PTR [Exit_type],exit_terminate
	JZ	FinishProcess
	MOV	BYTE PTR [Exit_type],exit_ctrl_c

	entry	FinishProcess

	CallResident get_user_stack
	PUSH	[CurrentPDB]
	POP	[SI.user_CS]
	JMP	SHORT abort_inner
EndProc ExitProcess

BREAK <$ABORT -- Terminate a process>

; Inputs:
;	user_CS:00 must point to valid program header block
; Function:
;	Restore terminate and Cntrl-C addresses, flush buffers and transfer to
;	the terminate address
; Returns:
;	TO THE TERMINATE ADDRESS

	procedure   AbortProcess,NEAR
ASSUME	DS:NOTHING,ES:NOTHING

	XOR	AL,AL
	MOV	[exit_type],exit_abort

;
; abort_inner must have AL set as the exit code!  The exit type is retrieved
; from exit_type.  Also, the PDB at user_CS needs to be correct as the one
; that is terminating.
;
	entry	abort_inner

	MOV	AH,[exit_type]
	MOV	[exit_code],AX
	CallResident get_user_stack
	MOV	DS,[SI.user_CS] 	; set up old interrupts
	XOR	AX,AX
	MOV	ES,AX
	MOV	SI,SAVEXIT
	MOV	DI,addr_int_terminate
	MOVSW
	MOVSW
	MOVSW
	MOVSW
	MOVSW
	MOVSW
	CallResident reset_environment	; restores the parent stack and IRETs
EndProc AbortProcess

DOSCODE ENDS

; Initialization reads pairs of resident vectors and linked service offsets.
DOSEND SEGMENT BYTE PUBLIC 'DOSEND'
        PUBLIC ProcEntries
ProcEntries LABEL WORD
        DW OFFSET DOSGROUP:$Exec_VECTOR, OFFSET DOSGROUP:LoadProgram
        DW OFFSET DOSGROUP:Reset_Version_VECTOR, OFFSET DOSGROUP:ResetExecVersion
        DW OFFSET DOSGROUP:$WAIT_VECTOR, OFFSET DOSGROUP:GetExitStatus
        DW OFFSET DOSGROUP:$Keep_Process_VECTOR, OFFSET DOSGROUP:KeepProcess
        DW OFFSET DOSGROUP:$EXIT_VECTOR, OFFSET DOSGROUP:ExitProcess
        DW OFFSET DOSGROUP:$ABORT_VECTOR, OFFSET DOSGROUP:AbortProcess
        DW OFFSET DOSGROUP:exit_inner_VECTOR, OFFSET DOSGROUP:FinishProcess
        DW 0
DOSEND ENDS
    END
