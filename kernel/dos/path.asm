;	SCCSID = @(#)path.asm	1.1 85/04/10
TITLE	PATH - Directory related system calls
NAME	PATH

;
; Directory related system calls.  These will be passed direct text of the
; pathname from the user.  They will need to be passed through the macro
; expander prior to being sent through the low-level stuff.  I/O specs are
; defined in DISPATCH.	The system calls are:
;
;   $CURRENT_DIR  Written
;   $RMDIR	  Written
;   $CHDIR	  Written
;   $MKDIR	  Written
;
;
;   Modification history:
;
;	Created: ARR 4 April 1983
;		 MZ 10 May 1983     CurrentDir implemented
;		 MZ 11 May 1983     RmDir, ChDir, MkDir implemented
;		 EE 19 Oct 1983     RmDir no longer allows you to delete a
;				    current directory.
;		 MZ 19 Jan 1983     Brain damaged applications rely on success
;				    values of AL.
.xlist
;
; get the appropriate segment definitions
;
include dosseg.asm

CODE	SEGMENT BYTE PUBLIC  'CODE'
	ASSUME	SS:DOSGroup,CS:DOSGroup

.xcref
INCLUDE DOSSYM.INC
INCLUDE DEVSYM.INC
.cref
.list

	I_Need	ThisCDS,DWORD		; pointer to Current CDS
	I_Need	WFP_Start,WORD		; pointer to beginning of directory text
	I_Need	Curr_Dir_End,WORD	; offset to end of directory part
	I_Need	OpenBuf,128		; temp spot for translated name
	I_need	fSplice,BYTE		; TRUE => do splice
	I_Need	NoSetDir,BYTE		; TRUE => no exact match on splice
	I_Need	cMeta,BYTE
	I_Need	DrvErr,BYTE							;AN000;

        EXTRN FCB_SELECTED:NEAR
        DosCodeEntry $CURRENT_DIR,170
        DosCodeEntry $RMDIR,74
        DosCodeEntry $CHDIR,73
        DosCodeEntry $MKDIR,72
CODE ENDS

DOSCODE SEGMENT BYTE PUBLIC 'DOSCODE'
        ASSUME CS:DOSCODE,SS:DOSGROUP

BREAK <$CURRENT_DIR - dump the current directory into user space>
;
;   Assembler usage:
;		LDS	SI,area
;		MOV	DL,drive
;		INT	21h
;	    ; DS:SI is a pointer to 64 byte area that contains drive
;	    ; current directory.
;   Error returns:
;	    AX = error_invalid_drive
;

	procedure GetCurrentDirectory,NEAR
	ASSUME	CS:DOSCODE,DS:NOTHING,ES:NOTHING,SS:DOSGroup
	CallResident ECritDisk
	MOV	AL,DL			; get drive number (0=def, 1=A)
	invoke GetVisDrv		; grab it
	JNC	CurrentValidate 	; no error -> go and validate dir
CurdirErr:
	CallResident LCritDisk
	MOV	AL,[DrvErr]		;IFS.					;AN000;
	jmp	PathError
CurrentValidate:
	SaveReg <DS,SI> 		; save destination
	LDS	SI,ThisCDS
	TEST	[SI].curdir_flags,curdir_isnet
	JNZ	DoCheck
; Random optimization nuked due to some utilities using GetCurrentDir to do
; media check.
;	CMP	[SI].curdir_id,0
;	JZ	GetDst
DoCheck:
	MOV	NoSetDir,0		; interested only in contents
	MOV	DI,OFFSET DOSGroup:OpenBuf
	Invoke	ValidateCurrentDirectory		; output is ES:DI -> CDS
	SaveReg <ES,DI> 		; swap source and destination
	RestoreReg  <SI,DS>
GetDst:
	RestoreReg  <DI,ES>		; get real destination
	JC	CurdirErr
	ADD	SI,curdir_text
	ADD	SI,[SI.curdir_END]
	CMP	BYTE PTR [SI],'\'       ; root or subdirs present?
	JNZ	CurrentCopy
	INC	SI
CurrentCopy:
;	Invoke	FStrCpy
;; 10/29/86 E5 char
	PUSH	AX
	LODSB			      ; get char
	OR	AL,AL
	JZ	FOK
	CMP	AL,05
	JZ	FCHANGE
	JMP	FFF
FCPYNEXT:
	LODSB			      ; get char
FFF:
	CMP	AL,'\'                ; beginning of directory
	JNZ	FOK		      ; no
	STOSB			      ; put into user's buffer
	LODSB			      ; 1st char of dir is 05?
	CMP	AL,05H
	JNZ	FOK		      ; no
FCHANGE:
	MOV	AL,0E5H 	      ; make it E5
FOK:
	STOSB			      ; put into user's buffer
	OR	AL,AL		      ; final char
	JNZ	FCPYNEXT	      ; no
	POP	AX

;; 10/29/86 E5 char
	xor	AL,AL			; MZ 19 Jan 84
	CallResident LCritDisk
	jmp	PathSuccess
EndProc GetCurrentDirectory

BREAK <$RmDir -- Remove a directory>

; Inputs:
;	DS:DX Points to asciz name
; Function:
;	Delete directory if empty
; Returns:
;	STD XENIX Return
;	AX = error_path_not_found If path bad
;	AX = error_access_denied If
;		Directory not empty
;		Path not directory
;		Root directory specified
;		Directory malformed (. and .. not first two entries)
;		User tries to delete a current directory
;	AX = error_current_directory

	procedure RemoveUserDirectory,NEAR
	ASSUME	CS:DOSCODE,DS:NOTHING,ES:NOTHING,SS:DOSGroup

	push	dx			; Save ptr to name
	push	ds
	mov	si,dx			; Load ptr into si
	mov	di,offset DOSGroup:OpenBuf	; di = ptr to buf for trans name
	push	di
	Invoke	TranslatePathNoSet		; Translate the name
	pop	di			; di = ptr to buf for trans name
	jnc	rmlset			; If transpath succeeded, continue
	pop	ds
	pop	dx			; Restore the	 name
	mov	al,error_path_not_found
	jmp	PathError

rmlset:
	CMP	cMeta,-1		;   if (cMeta >= 0)
	Jnz	rmerr			;	return (-1);
	Context ES
	xor	al,al			; al = 0 , ie drive a:
rmloop: invoke LookupDriveCds		; Get curdir for drive in al
	jc	rmcont			; If error, exit loop & cont normally
	CallResident StrCmp			; Are the 2 paths the same?
	jz	rmerr			; Yes, report error.
	inc	al			; No, inc al to next drive number
	jmp	rmloop			; Go check next drive.

rmerr:
	pop	ds
	pop	dx			; Restore the	 name
	mov	al,error_current_directory
	jmp	PathError

rmcont:
	pop	ds
	pop	dx			; Restore the	 name
	call	PrepareDirectoryPath
	jc	RmDirDone
	invoke	RemoveDirectory
RmDirDone:
	jmp	DirectoryResult
EndProc RemoveUserDirectory

BREAK <$ChDir -- Change current directory on a drive>

;
; $ChDir - Top-level change directory system call.  This call is responsible
; for setting up the CDS for the specified drive appropriately.  There are
; several cases to consider:
;
;   o	Local, simple CDS.  In this case, we take the input path and convert
;	it into a WFP.	We verify the existance of this directory and then
;	copy the WFP into the CDS and set up the ID field to point to the
;	directory cluster.
;   o	Net CDS.  We form the path from the root (including network prefix)
;	and verify its existance (via DOS_Chdir).  If successful, we copy the
;	WFP back into the CDS.
;   o	SUBST'ed CDS.  This is no different than the local, simple CDS.
;   o	JOIN'ed CDS.  This is trouble as there are two CDS's at work.  If we
;	call TransPath, we will get the PHYSICAL CDS that the path refers to
;	and the PHYSICAL WFP that the input path refers to.  This is perfectly
;	good for the validation but not for currency.  We call TransPathNoSet
;	to process the path but to return the logical CDS and the logical
;	path.  We then copy the logical path into the logical CDS.
;
; Inputs:
;	DS:DX Points to asciz name
; Returns:
;	STD XENIX Return
;	AX = chdir_path_not_found if error

	procedure SetCurrentDirectory,NEAR
	ASSUME	CS:DOSCODE,DS:NOTHING,ES:NOTHING,SS:DOSGroup
	MOV	DI,OFFSET DOSGroup:OpenBuf  ; spot for translated name
	MOV	SI,DX			; get source
	Invoke	TranslatePath		; go munge the path and get real CDS
	JNC	ChDirCrack		; no errors, try path
ChDirErrP:
	MOV	AL,error_path_not_found
ChdirErr:
	jmp	PathError

ChDirCrack:
	Assume	DS:DOSGroup
	CMP	cMeta,-1		; No meta chars allowed.
	JNZ	ChDirErrP
;
; We cannot do a ChDir (yet) on a raw CDS.  This is treated as a path not
; found.
;
	LES	DI,ThisCDS
	CMP	DI,-1			;   if (ThisCDS == NULL)
	JZ	ChDirErrP		;	error ();
 ;
 ; Find out if the directory exists.
 ;
	Invoke	ChangeDirectory
	JC	ChDirErr
;
; Get back CDS to see if a join as seen.  Set the currency pointer (only if
; not network).  If one was seen, all we need to do is copy in the text
;
	LES	DI,ThisCDS
	TEST	ES:[DI].curdir_flags,curdir_splice
	JZ	GotCDS
;
; The CDS was joined.  Let's go back and grab the logical CDS.
;
	SaveReg <ES,DI,CX>		; save CDS and cluster...
	CallResident Get_User_Stack		; get original text
	ASSUME	DS:NOTHING
	MOV	DI,[SI.User_DX]
	MOV	DS,[SI.User_DS]
	MOV	SI,OFFSET DOSGroup:OpenBuf  ; spot for translated name
	XCHG	SI,DI
	XOR	AL,AL			; do no splicing
	SaveReg <DI>
	Invoke	TranslatePathNoSet		; Munge path
	RestoreReg  <SI>
	Assume	DS:DOSGroup
;
; There should NEVER be an error here.
;
IF FALSE
	JNC SKipErr
	fmt <>,<>,<"$p: Internal CHDIR error\n">
SkipErr:
ENDIF
	LES	DI,ThisCDS		; get new CDS
	MOV	ES:[DI].curdir_ID,-1	; no valid cluster here...
	RestoreReg  <CX,DI,ES>
;
; ES:DI point to the physical CDS, CX is the ID (local only)
;
GotCDS:
;
; wfp_start points to the text.  See if it is long enough
;
	CALL	Check_PathLen		;PTM.					;AN000;
	JA	ChDirErrP
	TEST	ES:[DI].curdir_flags,curdir_isnet
	JNZ	SkipRecency
	TEST	ES:[DI].curdir_flags,curdir_splice   ;PTM. for Join and Subst	;AN000;
	JZ	setdirclus			     ;PTM.			;AN000;
	MOV	CX,-1				     ;PTM.			;AN000;
setdirclus:
	MOV	ES:[DI].curdir_id,CX
	LES	DI,ThisCDS		; get logical CDS
SkipRecency:
	CallResident FStrCpy
	XOR	AL,AL
	jmp	PathSuccess
EndProc SetCurrentDirectory

BREAK <$MkDir - Make a directory entry>
; Inputs:
;	DS:DX Points to asciz name
; Function:
;	Make a new directory
; Returns:
;	STD XENIX Return
;	AX = mkdir_path_not_found if path bad
;	AX = mkdir_access_denied  If
;		Directory cannot be created
;		Node already exists
;		Device name given
;		Disk or directory(root) full

	procedure MakeUserDirectory,NEAR
	ASSUME	CS:DOSCODE,DS:NOTHING,ES:NOTHING,SS:DOSGroup
        call    PrepareDirectoryPath
        jc      PathError
        invoke  MakeDirectory
DirectoryResult:
        jc      PathError
PathSuccess:
        CallResident SYS_RET_OK
        ret
PathError:
        CallResident SYS_RET_ERR
        ret
EndProc MakeUserDirectory

; DS:DX is the caller's pathname. Translate it for DIRCALL and reject
; wildcards or an overlong result. Carry set returns the DOS error in AL.
PrepareDirectoryPath PROC NEAR
        mov     di,OFFSET DOSGROUP:OpenBuf
        mov     si,dx
        invoke  TranslatePath
        jc      InvalidDirectoryPath
        cmp     cMeta,-1
        jne     InvalidDirectoryPath
        call    Check_PathLen
        jbe     DirectoryPathOK
        mov     al,error_Access_Denied
        stc
        ret
InvalidDirectoryPath:
        mov     al,error_Path_Not_Found
        stc
        ret
DirectoryPathOK:
        clc
        ret
PrepareDirectoryPath ENDP

; Inputs:
;	nothing
; Function:
;	check if final path length greater than 67
; Returns:
;	Above flag set if > 67

	procedure Check_PathLen,NEAR
	ASSUME	CS:DOSCODE,DS:NOTHING,ES:NOTHING,SS:DOSGroup

	MOV	SI,Wfp_Start
  entry Check_PathLen2
	Context <DS>
	SaveReg <CX>
	CallResident DStrLen
	CMP	CX,DirStrLen
	RestoreReg  <CX>
	ret
EndProc Check_PathLen
DOSCODE ENDS

DOSEND SEGMENT BYTE PUBLIC 'DOSEND'
        PUBLIC PathEntries
PathEntries LABEL WORD
        DW OFFSET DOSGROUP:$CURRENT_DIR_VECTOR, OFFSET DOSGROUP:GetCurrentDirectory
        DW OFFSET DOSGROUP:$RMDIR_VECTOR, OFFSET DOSGROUP:RemoveUserDirectory
        DW OFFSET DOSGROUP:$CHDIR_VECTOR, OFFSET DOSGROUP:SetCurrentDirectory
        DW OFFSET DOSGROUP:$MKDIR_VECTOR, OFFSET DOSGROUP:MakeUserDirectory
        DW 0
DOSEND ENDS
END
