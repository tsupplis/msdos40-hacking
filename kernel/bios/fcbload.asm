; Place the FCB and shared read/write routines. All installation tables are discarded at boot.
SYSINITSEG SEGMENT PUBLIC 'SYSTEM_INIT'
        ASSUME  CS:SYSINITSEG,DS:SYSINITSEG
        INCLUDE fcbsizes.inc
        EXTRN   FcbNative:BYTE,FcbUpper:BYTE
        EXTRN   FcbRelative:WORD,FcbSegments:WORD,FcbEntries:WORD
        EXTRN   ROUND:NEAR
        EXTRN   FINAL_DOS_LOCATION:WORD,MEMHI:WORD,HMA_REQUESTED:BYTE
        PUBLIC  InitFcbCode,PlaceFcbCode,GateBody,GateStart,GateXms

; Before DOSINIT. Install a temporary entry while device drivers initialize.
InitFcbCode PROC NEAR
        PUSH    DS
        PUSH    ES
        PUSH    CS
        POP     DS
        MOV     AX,OFFSET FcbUpper
        MOV     CL,4
        SHR     AX,CL
        MOV     BX,CS
        ADD     AX,BX
        SUB     AX,10h
        MOV     [GateBody],AX
        MOV     BX,[FINAL_DOS_LOCATION]
        MOV     [KernelSeg],BX
        MOV     DX,OFFSET GateStart
        SHR     DX,CL
        MOV     SI,CS
        ADD     DX,SI
        MOV     ES,AX
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
        POP     ES
        POP     DS
        RET
InitFcbCode ENDP

; Called with DS=CS and MEMHI paragraph aligned, after driver installation.
PlaceFcbCode PROC NEAR
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
        JE      PlaceHigh
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
        MOV     CX,FcbLength
        REP     MOVSB
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
        MOV     SI,OFFSET FcbEntries
PlaceSlot:
        LODSW
        CMP     AX,-1
        JE      PlaceVectors
        MOV     DI,AX
        LODSW
        ADD     AX,DX
        MOV     ES:[DI],AX
        JMP     PlaceSlot
        ; Near vectors for the handle and device entry points.
PlaceVectors:
        MOV     AX,ReadBody
        ADD     AX,DX
        MOV     ES:[ReadVector],AX
        MOV     AX,WriteBody
        ADD     AX,DX
        MOV     ES:[WriteVector],AX
PlaceDone:
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
        MOV     SI,OFFSET FcbUpper
        MOV     CX,FcbHiLength
        REP     MOVSB
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
        CMP     DX,0FFFFh
        JNE     PlaceDone
        MOV     AH,6
        CALL    DWORD PTR [GateXms]
        CMP     AX,1
        JE      PlaceDone
        MOV     SI,OFFSET GateMsg       ; DS is the unnormalized SYSINIT segment
        JMP     GateDisplay
PlaceFcbCode ENDP

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
        SUB     SP,4
        PUSH    AX
        PUSH    BX
        CALL    GateEnable
        MOV     BX,[BP-6]
        MOV     BL,BH
        XOR     BH,BH
        SHL     BX,1
        MOV     AX,CS:[BX+GateTable-GateStart]
        MOV     [BP-4],AX
        MOV     AX,CS:[GateBody-GateStart]
        MOV     [BP-2],AX
        POP     BX
        POP     AX
        MOV     AX,[BP+2]               ; original AX before gate selection
        CALL    DWORD PTR [BP-4]
        POP     BP
        POP     BP
        POP     BP
        CALL    GateDisable
        PUSH    BP
        MOV     BP,SP
        PUSH    AX
        MOV     AX,[BP+4]
        MOV     [BP+2],AX
        MOV     [BP+4],SS
        POP     AX
        POP     BP
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
        MOV     [BP+4],SS
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
GateMsg DB      13,10,'DOS: A20 error. Restart required.',13,10,0
GateXms DD      0
GateBody DW     0
GateTable LABEL WORD
        INCLUDE fcbtable.inc
GateLength EQU $-GateStart
KernelSeg DW 0
SYSINITSEG ENDS
        END
