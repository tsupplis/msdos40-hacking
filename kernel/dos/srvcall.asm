;	SCCSID = @(#)srvcall.asm	1.4 85/08/02
TITLE SRVCALL - Server DOS call
NAME  SRVCALL
;
; Server DOS call functions
;
;
;   $ServerCall
;
;   Modification history:
;
;	Created: ARR 08 August 1983
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

AsmVars <Installed>

include dpl.asm

Installed = TRUE

	i_need	USER_ID,WORD
	i_need	PROC_ID,WORD
	i_need	SaveBX,WORD
	i_need	SaveDS,WORD
	i_need	SWAP_START,BYTE
	i_need	SWAP_ALWAYS,BYTE
	i_need	SWAP_END,BYTE
	I_Need	ThisSFT,DWORD
	I_need	fSharing,BYTE
	I_Need	ExtErr,WORD
	I_Need	ExtErr_Action,BYTE
	I_Need	ExtErrPt,DWORD
	I_Need	EXTERR_LOCUS,BYTE	; Extended Error Locus
	i_need	JShare,DWORD

        EXTRN FCB_SELECTED:NEAR
        DosCodeEntry ServerEntry,226
        DosCodeEntry RedispatchEntry,227

; REDISP can replace the DOS stack. Complete the gateway return first,
; leaving the original INT 21h dispatcher frame in place.
procedure $ServerCall,NEAR
        OR      AL,AL
        JNZ     ServerEntry
        CALL    RedispatchEntry
        transfer REDISP
EndProc $ServerCall

; The installed sharer and spooler run from resident CODE. The spooler
; reads the original subfunction in the word immediately above its INT frame.
CloseServerName PROC NEAR
if installed
        CALL    CS:[JShare + 5 * 4]
else
        Call    MFTcloN
endif
        RET
CloseServerName ENDP

CloseServerUser PROC NEAR
if installed
        CALL    CS:[JShare + 3 * 4]
else
        Call    MFTclU
endif
        RET
CloseServerUser ENDP

CloseServerProcess PROC NEAR
if installed
        CALL    CS:[JShare + 4 * 4]
else
        Call    MFTCloseP
endif
        RET
CloseServerProcess ENDP

GetServerOpenFile PROC NEAR
if installed
        CALL    CS:[JShare + 9 * 4]
else
        Call    MFT_get
endif
        RET
GetServerOpenFile ENDP

ServerSpool PROC NEAR
        CallInstall NETSpoolOper,multNet,37,AX,BX
        RET
ServerSpool ENDP
CODE ENDS

DOSCODE SEGMENT BYTE PUBLIC 'DOSCODE'
        ASSUME CS:DOSCODE,SS:DOSGROUP,DS:NOTHING,ES:NOTHING

ReadServerIds PROC NEAR
        MOV     SI,DX
        MOV     BX,[SI.DPL_UID]
        MOV     SS:[USER_ID],BX
        MOV     BX,[SI.DPL_PID]
        MOV     SS:[PROC_ID],BX
        RET
ReadServerIds ENDP

; Inputs:
;	DS:DX -> DPL (except spool operations 7-9 and retired call 0Bh)
; Function:
;	AL=0	Handled separately by PrepareServerCall
;	AL=1	Commit All files
;	AL=2	Close file by name (SHARING LOADED ONLY) DS:DX in DPL -> name
;	AL=3	Close all files for DPL_UID
;	AL=4	Close all files for DPL_UID/DPL_PID
;	AL=5	Get open file list entry
;		    IN: BX File Index
;			CX User Index
;		    OUT:ES:DI -> Name
;			BX = UID
;		    CX = # locked blocks held by this UID
;	AL=6	Get DOS data area
;		    OUT: DS:SI -> Start
;			CX size in bytes of swap if indos
;			DX size in bytes of swap always
;	AL=7	Get truncate flag
;	AL=8	Set truncate flag
;	AL=9	Close all spool files
;	AL=10	SetExtendedError

procedure DispatchServerCall,NEAR
        CMP     AL,7
        JB      WithServerDpl
        CMP     AL,9
        JA      CheckServerError
        CallResident ServerSpool
        JMP     SHORT CheckReturns
CheckServerError:
        CMP     AL,0Bh
        JE      BadServerCall           ; retired subfunction has no DPL
WithServerDpl:
        CALL    ReadServerIds
        CMP     AL,1
        JE      COMMIT_ALL
        CMP     AL,2
        JNE     CheckCloseUser
        CallResident CloseServerName
        JMP     SHORT CheckReturns
CheckCloseUser:
        CMP     AL,3
        JNE     CheckCloseProcess
        CallResident CloseServerUser
        JMP     SHORT CheckReturns
CheckCloseProcess:
        CMP     AL,4
        JNE     CheckGetList
        CallResident CloseServerProcess
CheckReturns:
        JC      ServerError
ServerOK:
        CallResident SYS_RET_OK
        RET
CheckGetList:
        CMP     AL,5
        JE      GET_LIST
        CMP     AL,6
        JNE     CheckExtendedError
        JMP     GET_DOS_DATA
CheckExtendedError:
        CMP     AL,0Ah
        JNE     BadServerCall
        JMP     $SetExtendedError
BadServerCall:
        MOV     SS:[EXTERR_LOCUS],errLoc_Unk
        MOV     AL,error_invalid_function
ServerError:
        CallResident SYS_RET_ERR
        RET

; Commit - iterate through the open file list and make sure that the
; directory entries are correctly updated.

COMMIT_ALL:
ASSUME	DS:NOTHING,ES:NOTHING
	XOR	BX,BX			;   for (i=0; ThisSFT=getSFT(i); i++)
	Context DS
	CallResident ECritSFT		; Gonna scan SFT cache, lock it down
CommitLoop:
	PUSH	BX			; restore the SFT index on either exit
	Invoke	LookupSystemFile
	JC	CommitDone
	CMP	ES:[DI].sf_Ref_Count,0	;	if (ThisSFT->refcount != 0)
	JZ	CommitNext
	CMP	ES:[DI].sf_Ref_Count,sf_busy  ; BUSY SFTs have god knows what
	JZ	CommitNext		      ;   in them.
	invoke	IsRemoteSft
	JNZ	CommitNext		;  Skip Network SFTs so the SERVER
					;	doesn't deadlock
	MOV	WORD PTR ThisSFT,DI
	MOV	WORD PTR ThisSFT+2,ES
	Invoke	CommitSFT		;	    DOSCommit ();
CommitNext:
	POP	BX
	INC	BX
	JMP	CommitLoop
CommitDone:
	CallResident LCritSFT
	POP	BX
	JMP	ServerOK

GET_LIST:
        CallResident GetServerOpenFile
        JC      ServerError
        CallResident get_user_stack
        MOV     [SI.user_BX],BX
        MOV     [SI.user_DI],DI
        MOV     [SI.user_ES],ES
SetCXOK:
	MOV	[SI.user_CX],CX
	JMP	ServerOK

GET_DOS_DATA:
ASSUME	DS:NOTHING,ES:NOTHING
	PUSH	SS
	POP	ES			; DOSGROUP segment
	MOV	DI,OFFSET DOSGROUP:SWAP_START
	MOV	DX,OFFSET DOSGROUP:SWAP_ALWAYS
	SUB	DX,DI
	MOV	CX,OFFSET DOSGROUP:SWAP_END
	SUB	CX,DI
	INC	CX
	AND	CX,0FFFEh		; Report the total rounded up to a word.
	CallResident GET_USER_STACK
	MOV	[SI.user_DS],ES 	     ;	set user regs
	MOV	[SI.user_SI],DI 	     ;
	MOV	[SI.user_DX],DX 	     ;
	JMP	SetCXOK 		     ;				      ;AN000;

Break	<$SetExtendedError - set extended error for later retrieval>

;
; $SetExtendedError takes extended error information and loads it up for the
; next extended error call.  This is used by interrupt-level proccessors to
; mask their actions.
;
;   Inputs: DS:SI points to DPL which contains all registers
;   Outputs: none
;

$SetExtendedError:
	ASSUME	DS:NOTHING,ES:NOTHING
	MOV	AX,[SI].dpl_AX
	MOV	[EXTERR],AX
	MOV	AX,[SI].dpL_di
	MOV	WORD PTR ExtErrPt,AX
	MOV	AX,[SI].dpL_ES
	MOV	WORD PTR ExtErrPt+2,AX
	MOV	AX,[SI].dpL_BX
	MOV	WORD PTR [EXTERR_ACTION],AX
	MOV	AX,[SI].dpL_CX
	MOV	[EXTERR_LOCUS],AH
	return
EndProc DispatchServerCall

; Rebuild the dispatcher's saved registers, preserving the caller's BP.
procedure PrepareServerCall,NEAR
        ASSUME DS:NOTHING,ES:NOTHING
        CALL    ReadServerIds
        PUSH    DS
        PUSH    SI
        CallResident GET_USER_STACK
        MOV     DI,SI
        PUSH    DS
        POP     ES
        POP     SI
        POP     DS
; We now copy the registers from DPL to save stack
;
	SaveReg <SI>
	MOV	CX,6
	REP	MOVSW			; Put in AX,BX,CX,DX,SI,DI
	INC	DI
	INC	DI			; Skip user_BP
	MOVSW				; DS
	MOVSW				; ES
	RestoreReg  <SI>		; DS:SI -> DPL
	MOV	AX,[SI.DPL_AX]
	MOV	BX,[SI.DPL_BX]
	MOV	CX,[SI.DPL_CX]
	MOV	DX,[SI.DPL_DX]
	MOV	DI,[SI.DPL_DI]
	MOV	ES,[SI.DPL_ES]
	PUSH	[SI.DPL_SI]
	MOV	DS,[SI.DPL_DS]
	POP	SI
	MOV	[SaveDS],DS
	MOV	[SaveBX],BX
	MOV	fSharing,-1		; set no redirect flag
	RET
EndProc PrepareServerCall

DOSCODE ENDS
DOSEND SEGMENT BYTE PUBLIC 'DOSEND'
        PUBLIC SrvCallEntries
SrvCallEntries LABEL WORD
        DW OFFSET DOSGROUP:ServerEntry_VECTOR, OFFSET DOSGROUP:DispatchServerCall
        DW OFFSET DOSGROUP:RedispatchEntry_VECTOR, OFFSET DOSGROUP:PrepareServerCall
        DW 0
DOSEND ENDS
    END
