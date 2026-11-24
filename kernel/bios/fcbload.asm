; Place the FCB and shared read/write routines. All installation tables are discarded at boot.
SYSINITSEG SEGMENT PUBLIC 'SYSTEM_INIT'
        ASSUME  CS:SYSINITSEG,DS:SYSINITSEG
        INCLUDE fcbsizes.inc
        EXTRN   FcbNative:BYTE,FcbUpper:BYTE,FcbBridges:BYTE
        EXTRN   FcbRelative:WORD,FcbSegments:WORD,FcbEntries:WORD,FcbVectors:WORD
        EXTRN   ROUND:NEAR
        EXTRN   FINAL_DOS_LOCATION:WORD,MEMHI:WORD,HMA_REQUESTED:BYTE
        PUBLIC  InitDosCode,PlaceDosCode,GateBody,GateStart,GateXms

        PUBLIC ReserveDosCode
; CX is the first paragraph above the available boot workspace. SYSINIT
; relocates below the returned limit. DOS reclaims this space after boot.
ReserveDosCode PROC NEAR
        SUB     CX,(FcbHiLength+15)/16
        MOV     DX,CX
        SUB     DX,10h                  ; temporary body starts at offset 100h
        MOV     [GateBody],DX
        RET
ReserveDosCode ENDP

; Before DOSINIT. Install a temporary entry while device drivers initialize.
InitDosCode PROC NEAR
        PUSH    DS
        PUSH    ES
        PUSH    CS
        POP     DS
        MOV     BX,[FINAL_DOS_LOCATION]
        MOV     [KernelSeg],BX
        MOV     ES,[GateBody]
        MOV     DI,100h
        MOV     SI,OFFSET FcbUpper
        MOV     CX,FcbLegacyLength
        REP     MOVSB
        MOV     DS,BX                   ; linked DOSCODE comes from MSDOS.SYS
        MOV     SI,FcbLinked+FcbLegacyLength
        MOV     CX,FcbLength-FcbLegacyLength
        REP     MOVSB
        PUSH    CS
        POP     DS
        MOV     SI,OFFSET FcbBridges
        MOV     CX,FcbHiLength-FcbLength
        REP     MOVSB
        MOV     DX,OFFSET GateStart
        MOV     CL,4
        SHR     DX,CL
        MOV     SI,CS
        ADD     DX,SI
        CALL    PatchCallbacks
InitDispatch:
        MOV     ES,BX
        MOV     SI,OFFSET FcbEntries
InitSlot:
        LODSW
        CMP     AX,-1
        JE      InitGate
        MOV     DI,AX
        MOV     WORD PTR ES:[DI],FcbEntryIP
        LODSW
        JMP     InitSlot
InitGate:
        MOV     AX,OFFSET GateStart
        MOV     CL,4
        SHR     AX,CL
        MOV     BX,CS
        ADD     AX,BX
        MOV     WORD PTR ES:[FcbGatePtr],0
        MOV     ES:[FcbGatePtr+2],AX
        MOV     WORD PTR ES:[CallbackPtr],GateBack-GateStart
        MOV     ES:[CallbackPtr+2],AX
        POP     ES
        POP     DS
        RET
InitDosCode ENDP

; Called with DS=CS and MEMHI paragraph aligned, after driver installation.
PlaceDosCode PROC NEAR
        CMP     [HMA_REQUESTED],0
        JE      PlaceLow
        MOV     AX,4300h
        INT     2fh
        CMP     AL,80h
        JNE     PlaceLow
        MOV     AX,4310h
        INT     2fh
        MOV     WORD PTR [GateXms],BX
        MOV     WORD PTR [GateXms+2],ES
        MOV     DX,0FFFFh
        MOV     AH,1
        CALL    DWORD PTR [GateXms]
        CMP     AX,1
        JNE     PlaceLow
        MOV     AH,5
        CALL    DWORD PTR [GateXms]
        CMP     AX,1
        JNE     ReleaseHma
        JMP     PlaceHigh
ReleaseHma:
        MOV     AH,2
        CALL    DWORD PTR [GateXms]
PlaceLow:
        MOV     AX,[MEMHI]
        SUB     AX,[KernelSeg]
        CMP     AX,1000h-((FcbLength+15)/16)
        JA      PlaceFarLow
        MOV     CL,4
        SHL     AX,CL
        MOV     DX,AX                   ; native offset in DOSGROUP
        MOV     ES,[KernelSeg]
        ADD     [MEMHI],(FcbLength+15)/16
        CALL    ROUND
        MOV     DI,DX
        MOV     SI,OFFSET FcbNative
        MOV     CX,FcbLegacyLength
        REP     MOVSB
        MOV     DS,[GateBody]
        MOV     SI,100h+FcbLegacyLength
        MOV     CX,FcbLength-FcbLegacyLength
        REP     MOVSB
        PUSH    CS
        POP     DS
        MOV     SI,OFFSET FcbRelative
        MOV     BX,FcbLinked
        SUB     BX,DX
PlaceFix:
        LODSW
        CMP     AX,-1
        JE      PlaceSlots
        MOV     DI,AX
        ADD     DI,DX
        ADD     ES:[DI],BX
        JMP     PlaceFix
PlaceSlots:
        MOV     WORD PTR ES:[CallbackPtr],NativeCallback
        MOV     ES:[CallbackPtr+2],ES
        MOV     SI,OFFSET FcbVectors       ; followed by FcbEntries
PlaceSlot:
        LODSW
        CMP     AX,-1
        JE      PlaceDone
        MOV     DI,AX
        LODSW
        ADD     AX,DX
        MOV     ES:[DI],AX
        JMP     PlaceSlot
PlaceDone:
        CLC                             ; conventional placement
        RET
PlaceFarLow:
        MOV     AX,[MEMHI]
        ADD     [MEMHI],(FcbHiLength+15)/16
        CALL    ROUND
        SUB     AX,10h
        JMP     SHORT PlaceCopy
PlaceHigh:
        MOV     AX,0FFFFh
PlaceCopy:
        MOV     ES,AX
        MOV     DI,100h
        MOV     DS,[GateBody]
        MOV     SI,100h
        MOV     CX,FcbHiLength
        REP     MOVSB
        PUSH    CS
        POP     DS
        MOV     DX,[MEMHI]
        PUSH    AX
        CALL    PatchCallbacks
        POP     DX
        MOV     ES,[MEMHI]
        MOV     CX,(GateLength+15)/16
        ADD     [MEMHI],CX
        CALL    ROUND
        XOR     DI,DI
        MOV     SI,OFFSET GateStart
        MOV     CX,GateLength
        REP     MOVSB
        MOV     ES:[GateBody-GateStart],DX
        MOV     BX,ES
        MOV     ES,[KernelSeg]
        MOV     ES:[FcbGatePtr+2],BX
        MOV     ES:[CallbackPtr+2],BX
        CMP     DX,0FFFFh
        JNE     PlaceDone
        MOV     AH,6
        CALL    DWORD PTR [GateXms]
        CMP     AX,1
        JNE     PlaceA20Error
        STC                             ; successful HMA placement
        RET
PlaceA20Error:
        MOV     SI,OFFSET GateMsg       ; DS is the unnormalized SYSINIT segment
        JMP     GateDisplay
PlaceDosCode ENDP

; ES:100h = FCB overlay, DX = normalized conventional gateway segment.
PatchCallbacks PROC NEAR
        MOV     SI,OFFSET FcbSegments
PatchNext:
        LODSW
        CMP     AX,-1
        JE      PatchDone
        MOV     DI,AX
        MOV     WORD PTR ES:[DI-2],GateBack-GateStart
        MOV     ES:[DI],DX
        JMP     PatchNext
PatchDone:
        RET
PatchCallbacks ENDP

; Normalized at offset zero. Only the far and HMA layouts retain this code.
        ALIGN   16
GateStart:
        PUSH    BP
        MOV     BP,SP
        PUSHF                           ; pass the caller's flags into the service
        SUB     SP,4
        PUSH    AX
        PUSH    BX
        CALL    GateEnable
        MOV     BX,[BP-8]
        MOV     BL,BH
        XOR     BH,BH
        SHL     BX,1
        MOV     AX,CS:[BX+GateTable-GateStart]
        MOV     [BP-6],AX
        MOV     AX,CS:[GateBody-GateStart]
        MOV     [BP-4],AX
        POP     BX
        POP     AX
        CMP     AH,45                   ; pathname calls return the DPB in ES:BP
        MOV     AX,[BP+2]               ; original AX before gate selection
        JB      GateCall
        PUSH    WORD PTR [BP-2]
        POPF
        PUSH    CS
        CALL    GatePath
        PUSH    SI
        MOV     SI,SP
        MOV     SS:[SI+8],BP            ; return the pathname routine's BP
        POP     SI
        JMP     SHORT GateResult
GateCall:
        PUSH    WORD PTR [BP-2]
        POPF
        CALL    DWORD PTR [BP-6]
GateResult:
        POP     BP                      ; discard the saved input flags with the target
        POP     BP
        POP     BP
        POP     BP
        CALL    GateDisable
        PUSH    BP
        MOV     BP,SP
        PUSH    AX
        MOV     AX,[BP+4]
        MOV     [BP+2],AX
        PUSH    WORD PTR CS:[KernelSeg-GateStart]
        POP     WORD PTR [BP+4]
        POP     AX
        POP     BP
        RETF
GatePath:
        PUSH    WORD PTR [BP-4]
        PUSH    WORD PTR [BP-6]
        MOV     BP,[BP]                 ; original BP on device paths
        RETF
GateBack:
        ; A low call can switch stacks to abort or restart the operation.
        ; Release before entering it. Only a normal return reacquires A20.
        PUSH    CS
        CALL    GateInvoke              ; low RETF resumes here
        CALL    GateEnable
        RETF
GateInvoke:
        PUSH    BP
        MOV     BP,SP
        PUSH    AX
        PUSH    BX
        PUSH    ES
        LES     BX,[BP+6]               ; skip the conventional resume address
        MOV     AX,ES:[BX]
        CALL    GateDisable             ; inline target is in the overlay
        LEA     BX,[BX+2]
        MOV     [BP+6],BX
        MOV     BX,[BP]
        MOV     WORD PTR [BP],LowReturn
        XCHG    AX,[BP-2]
        MOV     BP,BX
        POP     ES
        POP     BX
        ; Insert the kernel segment after the target IP to enter DOSGROUP.
        PUSH    AX
        PUSH    BP
        MOV     BP,SP
        MOV     AX,[BP+4]
        XCHG    AX,[BP+2]
        PUSH    WORD PTR CS:[KernelSeg-GateStart]
        POP     WORD PTR [BP+4]
        POP     BP
        RETF

; Preserve the low routine's arguments, results and condition flags.
GateEnable:
        PUSHF
        PUSH    AX
        MOV     AH,5
        JMP     SHORT GateToggle
GateDisable:
        PUSHF
        PUSH    AX
        MOV     AH,6
GateToggle:
        CMP     WORD PTR CS:[GateBody-GateStart],0FFFFh
        JNE     GateReady
        PUSH    BX
        CALL    DWORD PTR CS:[GateXms-GateStart]
        CMP     AX,1
        POP     BX
        JNE     GateFault
GateReady:
        POP     AX
        POPF
        RET

GateFault:
        PUSH    CS
        POP     DS
        MOV     SI,GateMsg-GateStart
GateDisplay:
        CLD
        MOV     AH,0Fh
        INT     10h
        MOV     BL,7
GatePrint:
        LODSB
        OR      AL,AL
        JZ      GateStop
        MOV     AH,0Eh
        INT     10h
        JMP     GatePrint
GateStop:
        STI
        HLT
        JMP     GateStop
        INCLUDE msbio.cl6
GateXms DD      0
GateBody DW     0
GateTable LABEL WORD
        INCLUDE fcbtable.inc
KernelSeg DW 0                          ; multiplex calls may arrive on a user stack
GateLength EQU $-GateStart
SYSINITSEG ENDS
        END
