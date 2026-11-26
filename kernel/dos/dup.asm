;	SCCSID = @(#)dup.asm	1.1 85/04/10
;	SCCSID = @(#)dup.asm	1.1 85/04/10
TITLE	DOS_DUP - Internal SFT DUP (for network SFTs)
NAME	DOS_DUP
; Low level DUP routine for use by EXEC when creating a new process. Exports
;   the DUP to the server machine and increments the SFT ref count
;
; DOS_DUP
;
;   Modification history:
;
;	Created: ARR 30 March 1983
;

;
; get the appropriate segment definitions
;
.xlist
include dosseg.asm

CODE	SEGMENT BYTE PUBLIC  'CODE'
	ASSUME	SS:DOSGROUP,CS:DOSGROUP

.xcref
INCLUDE DOSSYM.INC
INCLUDE DEVSYM.INC
.cref
.list

	i_need	THISSFT,DWORD

        EXTRN FCB_SELECTED:NEAR
        DosCodeEntry DOS_DUP,137
        DosCodeEntry Dos_Dup_Direct,138
CODE ENDS
DOSCODE SEGMENT BYTE PUBLIC 'DOSCODE'
        ASSUME CS:DOSCODE,SS:DOSGROUP
BREAK <DuplicateCurrentSft -- DUP SFT across network>

; Inputs:
;	[THISSFT] set to the SFT for the file being DUPed
;		(a non net SFT is OK, in this case the ref
;		 count is simply incremented)
; Function:
;	Signal to the devices that alogical open is occurring
; Returns:
;	ES:DI point to SFT
;    Carry clear
;	SFT ref_count is incremented
; Registers modified: None.
; NOTE:
;	This routine is called from $CREATE_PROCESS_DATA_BLOCK at DOSINIT
;	time with SS NOT DOSGROUP. There will be no Network handles at
;	that time.

	procedure   DuplicateCurrentSft,NEAR
	ASSUME	ES:NOTHING,SS:NOTHING,DS:DOSGROUP

	LES	DI,ThisSFT
	JMP DuplicateSft

        Entry DuplicateSelectedSft
        ; The handle path supplies the JFN segment in DS and DOSGROUP in SS.
        PUSH DS
        PUSH SS
        POP DS
        CALL DuplicateSft
        POP DS
        RET
DuplicateSft:
	Assert	ISSFT,<ES,DI>,"DOSDup"
	CallResident IsSFTNet,DS
	JNZ	DO_INC
	invoke  OpenDeviceSft
DO_INC:
	Assert	ISSFT,<ES,DI>,"DOSDup/DoInc"
	INC	ES:[DI.sf_ref_count]	; Clears carry (if this ever wraps
					;   we're in big trouble anyway)
	return

EndProc DuplicateCurrentSft
DOSCODE ENDS
DOSEND SEGMENT BYTE PUBLIC 'DOSEND'
        PUBLIC DupEntries
DupEntries LABEL WORD
        DW OFFSET DOSGROUP:DOS_DUP_VECTOR, OFFSET DOSGROUP:DuplicateCurrentSft
        DW OFFSET DOSGROUP:Dos_Dup_Direct_VECTOR, OFFSET DOSGROUP:DuplicateSelectedSft
        DW 0
DOSEND ENDS
    END
