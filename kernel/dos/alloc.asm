;	SCCSID = @(#)alloc.asm	1.1 85/04/09
TITLE ALLOC.ASM - memory arena manager
NAME Alloc
;
; Memory related system calls and low level routines for MSDOS 2.X.
; I/O specs are defined in DISPATCH.
;
;   $ALLOC
;   $SETBLOCK
;   $DEALLOC
;   $AllocOper
;   arena_free_process
;   arena_next
;   check_signature
;   Coalesce
;
;   Modification history:
;
;       Created: ARR 30 March 1983
;

.xlist
;
; get the appropriate segment definitions
;
include dosseg.asm

CODE    SEGMENT BYTE PUBLIC  'CODE'
	ASSUME  SS:DOSGROUP,CS:DOSGROUP

.xcref
INCLUDE DOSSYM.INC
INCLUDE DEVSYM.INC
.cref
.list

.lall

SUBTTL memory allocation utility routines
PAGE
;
; arena data
;
	i_need  arena_head,WORD         ; seg address of start of arena
	i_need  CurrentPDB,WORD         ; current process data block addr
	i_need  FirstArena,WORD         ; first free block found
	i_need  BestArena,WORD          ; best free block found
	i_need  LastArena,WORD          ; last free block found
	i_need	UMB_TOTAL,WORD
	i_need	UMB_HEAD,WORD
	i_need	UMB_BRIDGE,WORD
	i_need	UMB_LINKED,BYTE

ALLOC_HIGH_ONLY  EQU 40h
ALLOC_HIGH_FIRST EQU 80h
	i_need  AllocMethod,BYTE        ; how to alloc first(best)last
	I_need  EXTERR_LOCUS,BYTE       ; Extended Error Locus

;
; arena_free_process
; input:    BX - PID of process
; output:   free all blocks allocated to that PID
;
	procedure   arena_free_process,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	MOV     DI,arena_signature
	MOV     AX,[arena_head]
	CALL    Check_Signature         ; ES <- AX, check for valid block

arena_free_process_loop:
	retc
	PUSH    ES
	POP     DS
	CMP     DS:[arena_owner],BX     ; is block owned by pid?
	JNZ     arena_free_next         ; no, skip to next
	MOV     DS:[arena_owner],DI     ; yes... free him

arena_free_next:
	CMP     BYTE PTR DS:[DI],arena_signature_end
					; end of road, Jack?
	JNE     FreeFollowing
	MOV     AX,DS
	CMP     AX,[UMB_HEAD]
	JAE     FreeComplete
	MOV     AX,[UMB_HEAD]            ; reclaim even after the child unlinked
	CALL    Check_signature
	JMP     arena_free_process_loop
FreeComplete:
	RET
FreeFollowing:
	CALL    arena_next              ; next item in ES/AX carry set if trash
	JMP     arena_free_process_loop

EndProc arena_free_process

;
; arena_next
; input:    DS - pointer to block head
; output:   AX,ES - pointers to next head
;           carry set if trashed arena
;
	procedure   arena_next,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	MOV     AX,DS                   ; AX <- current block
	ADD     AX,DS:[arena_size]      ; AX <- AX + current block length
	INC     AX                      ; remember that header!
;
;       fall into check_signature and return
;
;       CALL    check_signature         ; ES <- AX, carry set if error
;       RET
EndProc arena_next

;
; check_signature
; input:    AX - address of block header
; output:   ES=AX, carry set if signature is bad
;
	procedure   check_signature,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	MOV     ES,AX                   ; ES <- AX
	CMP     BYTE PTR ES:[DI],arena_signature_normal
					; IF next signature = not_end THEN
	retz                            ;   GOTO ok
	CMP     BYTE PTR ES:[DI],arena_signature_end
					; IF next signature = end then
	retz                            ;   GOTO ok
	STC                             ; set error
	return

EndProc Check_signature

;
; Coalesce - combine free blocks ahead with current block
; input:    DS - pointer to head of free block
; output:   updated head of block, AX is next block
;           carry set -> trashed arena
;
	procedure   Coalesce,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	CMP     BYTE PTR DS:[DI],arena_signature_end
					; IF current signature = END THEN
	retz                            ;   GOTO ok
	CALL    arena_next              ; ES, AX <- next block, Carry set if error
	retc                            ; IF no error THEN GOTO check

coalesce_check:
	CMP     ES:[arena_owner],DI
	retnz                           ; IF next block isnt free THEN return
	MOV     CX,ES:[arena_size]      ; CX <- next block size
	INC     CX                      ; CX <- CX + 1 (for header size)
	ADD     DS:[arena_size],CX      ; current size <- current size + CX
	MOV     CL,ES:[DI]              ; move up signature
	MOV     DS:[DI],CL
	JMP     coalesce                ; try again
EndProc Coalesce

SUBTTL $Alloc - allocate space in memory
PAGE
;
;   Assembler usage:
;           MOV     BX,size
;           MOV     AH,Alloc
;           INT     21h
;         AX:0 is pointer to allocated memory
;         BX is max size if not enough memory
;
;   Description:
;           Alloc returns  a  pointer  to  a  free  block of
;       memory that has the requested  size  in  paragraphs.
;
;   Error return:
;           AX = error_not_enough_memory
;              = error_arena_trashed
;
	procedure   $ALLOC,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING

	EnterCrit   critMem
	XOR     AX,AX
	MOV     DI,AX

	MOV     [FirstArena],AX         ; init the options
	MOV     [BestArena],AX
	MOV     [LastArena],AX

	PUSH    AX                      ; alloc_max <- 0
	MOV     AX,[arena_head]         ; AX <- beginning of arena
	TEST    [AllocMethod],ALLOC_HIGH_FIRST OR ALLOC_HIGH_ONLY
	JZ      ScanStart
	CMP     [UMB_LINKED],0
	JE      ScanStart
	MOV     AX,[UMB_HEAD]
ScanStart:
	CALL    Check_signature         ; ES <- AX, carry set if error
	JC      alloc_err               ; IF error THEN GOTO err

alloc_scan:
	PUSH    ES
	POP     DS                      ; DS <- ES
	CMP     DS:[arena_owner],DI
	JZ      alloc_free              ; IF current block is free THEN examine

alloc_next:
        ; A high-first fallback need only scan conventional memory.
	TEST    [AllocMethod],ALLOC_HIGH_FIRST
	JZ      ScanFollowing
	MOV     AX,DS
	CMP     AX,[UMB_BRIDGE]
	JE      alloc_end
ScanFollowing:
	CMP     BYTE PTR DS:[DI],arena_signature_end
					; IF current block is last THEN
	JZ      alloc_end               ;   GOTO end
	CALL    arena_next              ; AX, ES <- next block, Carry set if error
	JNC     alloc_scan              ; IF no error THEN GOTO scan

alloc_err:
	POP     AX

alloc_trashed:
	LeaveCrit   critMem
	error   error_arena_trashed

alloc_end:
	CMP     [FirstArena],0
	JZ      NoFitThisArena
	JMP     alloc_do_split
NoFitThisArena:

	TEST    [AllocMethod],ALLOC_HIGH_FIRST
	JZ      alloc_fail
	TEST    [AllocMethod],ALLOC_HIGH_ONLY
	JNZ     alloc_fail
	MOV     AX,DS
	CMP     AX,[UMB_HEAD]
	JB      alloc_fail
	CMP     [UMB_LINKED],0
	JE      alloc_fail
	MOV     AX,[arena_head]
	JMP     ScanStart
alloc_fail:
	invoke  get_user_stack
	POP     BX
	MOV     [SI].user_BX,BX
	LeaveCrit   critMem
	error   error_not_enough_memory

alloc_free:
	CALL    coalesce                ; add following free block to current
	JC      alloc_err               ; IF error THEN GOTO err
	MOV     CX,DS:[arena_size]

	POP     DX                      ; check for max found size
	CMP     CX,DX
	JNA     alloc_test
	MOV     DX,CX

alloc_test:
	PUSH    DX
	CMP     BX,CX                   ; IF BX > size of current block THEN
	JA      alloc_next              ;   GOTO next

	CMP     [FirstArena],0
	JNZ     alloc_best
	MOV     [FirstArena],DS         ; save first one found
alloc_best:
	CMP     [BestArena],0
	JZ      alloc_make_best         ; initial best
	PUSH    ES
	MOV     ES,[BestArena]
	CMP     ES:[arena_size],CX      ; is size of best larger than found?
	POP     ES
	JBE     alloc_last
alloc_make_best:
	MOV     [BestArena],DS          ; assign best
alloc_last:
	MOV     [LastArena],DS          ; assign last
	JMP     alloc_next

;
; split the block high
;
alloc_do_split_high:
	MOV     DS,[LastArena]
	MOV     CX,DS:[arena_size]
	SUB     CX,BX
	MOV     DX,DS
	JE      alloc_set_owner         ; sizes are equal, no split
	ADD     DX,CX                   ; point to next block
	MOV     ES,DX                   ; no decrement!
	DEC     CX
	XCHG    BX,CX                   ; bx has size of lower block
	JMP     alloc_set_sizes         ; cx has upper (requested) size

;
; we have scanned memory and have found all appropriate blocks
; check for the type of allocation desired; first and best are identical
; last must be split high
;
alloc_do_split:
	MOV     AL,[AllocMethod]
	AND     AL,3
	CMP     AL,1
	JA      alloc_do_split_high
	MOV     DS,[FirstArena]
	JB      alloc_get_size
	MOV     DS,[BestArena]
alloc_get_size:
	MOV     CX,DS:[arena_size]
	SUB     CX,BX                   ; get room left over
	MOV     AX,DS
	MOV     DX,AX                   ; save for owner setting
	JE      alloc_set_owner         ; IF BX = size THEN (don't split)
	ADD     AX,BX
	INC     AX                      ; remember the header
	MOV     ES,AX                   ; ES <- DS + BX (new header location)
	DEC     CX                      ; CX <- size of split block
alloc_set_sizes:
	MOV     DS:[arena_size],BX      ; current size <- BX
	MOV     ES:[arena_size],CX      ; split size <- CX
	MOV     BL,arena_signature_normal
	XCHG    BL,DS:[DI]              ; current signature <- 4D
	MOV     ES:[DI],BL              ; new block sig <- old block sig
	MOV     ES:[arena_owner],DI

alloc_set_owner:
	MOV     DS,DX
	MOV     AX,[CurrentPDB]
	MOV     DS:[arena_owner],AX
	MOV     AX,DS
	INC     AX
	POP     BX
	LeaveCrit   critMem
	transfer    SYS_RET_OK

EndProc $alloc


SUBTTL $SETBLOCK - change size of an allocated block (if possible)
PAGE
;
;   Assembler usage:
;           MOV     ES,block
;           MOV     BX,newsize
;           MOV     AH,setblock
;           INT     21h
;         if setblock fails for growing, BX will have the maximum
;         size possible
;   Error return:
;           AX = error_invalid_block
;              = error_arena_trashed
;              = error_not_enough_memory
;              = error_invalid_function
;
	procedure   $SETBLOCK,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	EnterCrit   critMem
	MOV     DI,arena_signature
	MOV     AX,ES
	DEC     AX
	CALL    check_signature
	JNC     setblock_grab

setblock_bad:
	JMP     alloc_trashed

setblock_grab:
	MOV     DS,AX
	CALL    coalesce
	JC      setblock_bad
	MOV     CX,DS:[arena_size]
	PUSH    CX
	CMP     BX,CX
	JBE     alloc_get_size
	JMP     alloc_fail
EndProc $setblock

SUBTTL $DEALLOC - free previously allocated piece of memory
PAGE
;
;   Assembler usage:
;           MOV     ES,block
;           MOV     AH,dealloc
;           INT     21h
;
;   Error return:
;           AX = error_invalid_block
;              = error_arena_trashed
;
	procedure   $DEALLOC,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	EnterCrit   critMem
	MOV     DI,arena_signature
	MOV     AX,ES
	DEC     AX
	CALL    check_signature
	JC      dealloc_err
	MOV     ES:[arena_owner],DI
	LeaveCrit   critMem
	transfer    SYS_RET_OK

dealloc_err:
	LeaveCrit   critMem
	error   error_invalid_block
EndProc $DEALLOC

SUBTTL $AllocOper - get/set allocation mechanism
PAGE
;
;   Assembler usage:
;           MOV     AH,AllocOper
;           MOV     BX,method
;           MOV     AL,func
;           INT     21h
;
;   Error return:
;           AX = error_invalid_function
;
	procedure   $AllocOper,NEAR
	ASSUME  DS:NOTHING,ES:NOTHING
	CMP     AL,0FFh		; DOS UMB pool size in paragraphs
	JNE     CheckAllocOp
	MOV     AX,[UMB_TOTAL]
	transfer SYS_RET_OK
CheckAllocOp:
	CMP     AL,1
	JB      AllocOperGet
	JZ      AllocOperSet
	CMP     AL,2
	JE      GetUmbLink
	CMP     AL,3
	JNE     InvalidAllocOp
	CMP     BX,1
	JA      InvalidAllocOp
	CMP     [UMB_HEAD],0
	JE      InvalidAllocOp
	CMP     BL,[UMB_LINKED]
	JE      AllocOpDone
	MOV     AX,[arena_head]
	XOR     DI,DI
LinkWalk:
	CALL    Check_signature
	JC      InvalidAllocOp
	MOV     DS,AX
	ADD     AX,DS:[arena_size]
	INC     AX
	CMP     AX,[UMB_BRIDGE]
	JE      LinkFound
	JA      InvalidAllocOp
	JMP     LinkWalk
LinkFound:
	MOV     AL,arena_signature_end
	OR      BL,BL
	JZ      StoreLink
	MOV     AL,arena_signature_normal
StoreLink:
	MOV     DS:[DI],AL
	MOV     [UMB_LINKED],BL
AllocOpDone:
	MOV     AX,5803h
	transfer	SYS_RET_OK
GetUmbLink:
	XOR     AX,AX
	MOV     AL,[UMB_LINKED]
	transfer	SYS_RET_OK
InvalidAllocOp:
	MOV     EXTERR_LOCUS,errLoc_mem ; Extended Error Locus
	error   error_invalid_function
AllocOperGet:
	MOV     AL,BYTE PTR [AllocMethod]
	XOR     AH,AH
	transfer    SYS_RET_OK
AllocOperSet:
	MOV     AX,BX
	AND     AX,NOT (ALLOC_HIGH_ONLY OR ALLOC_HIGH_FIRST)
	CMP     AX,2
	JA      InvalidAllocOp
	MOV     AX,5801h
	MOV     [AllocMethod],BL
	transfer    SYS_RET_OK
EndProc $AllocOper

; EXEC sizes its image from the largest block before allocating it. With
; high-first selected, prefer an upper block meeting the minimum in AX.
procedure ExecLargest,NEAR
	TEST	[AllocMethod],ALLOC_HIGH_FIRST
	JZ	ExecLargestAny
	CMP	[UMB_LINKED],0
	JE	ExecLargestAny
	PUSH	AX
	MOV	AL,[AllocMethod]
	PUSH	AX
	OR	[AllocMethod],ALLOC_HIGH_ONLY
	MOV	BX,0FFFFh
	invoke	$ALLOC
	POP	AX
	MOV	[AllocMethod],AL
	POP	AX
	CMP	BX,AX
	JAE	ExecLargestDone
ExecLargestAny:
	MOV	BX,0FFFFh
	transfer $ALLOC
ExecLargestDone:
	return
EndProc ExecLargest

CODE    ENDS
    END
