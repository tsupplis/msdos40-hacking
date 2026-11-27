; Run on scratch media. Fill B: to exercise the DOS short-write contract.
CODE    SEGMENT PARA PUBLIC 'CODE'
        ASSUME  CS:CODE,DS:CODE
Check   MACRO   condition
        LOCAL   ok
        condition ok
        JMP     Failed
ok:
        ENDM

        INCLUDE hma.inc
Start:  MOV     AL,ES:[82h]             ; expected layout from command tail
        PUSH    CS
        POP     DS
        CMP     AL,'s'
        JNE     CheckLayout
        JMP     CheckShare
CheckLayout:
        MOV     AH,ES:[83h]             ; ! requests only the placement check
        MOV     ProbeMode,AH
        MOV     Layout,AL
        MOV     AX,3521h
        INT     21h
        MOV     AL,'n'
        MOV     BX,ES
        CMP     ES:[CallbackSeg],BX
        JE      Placed
        MOV     ES,ES:[GateSeg]
        MOV     AL,'h'
        CMP     WORD PTR ES:[BodyOff],0FFFFh
        JE      Placed
        MOV     BX,ES:[BodyOff]
        ADD     BX,10h                  ; first byte of body is at offset 100h
        MOV     AL,'u'
        CMP     BX,0A000h
        JAE     Placed
        MOV     AL,'f'
Placed: CMP     AL,Layout
        Check   JE
        MOV     AX,58FEh                ; MEM's residency query agrees with the gateway
        INT     21h
        Check   JNC
        CMP     Layout,'h'
        JNE     ExpectLow
        DEC     AX
ExpectLow:
        OR      AX,AX
        Check   JZ
        MOV     AL,Layout
        CMP     ProbeMode,'!'
        JNE     CheckIO
        MOV     DX,OFFSET LayoutOK
        JMP     PrintResult
CheckIO: CMP     AL,'h'
        JNE     RunIO
        MOV     AX,58FFh                ; both options in "dos=high, umb"
        INT     21h
        Check   JNC
        OR      AX,AX
        Check   JNZ
        CALL    GetXmsEntry
        MOV     CX,2000                 ; known leap day on this scratch boot
        MOV     DX,021Dh
        MOV     AH,2Bh
        INT     21h
        OR      AL,AL
        Check   JZ
        CALL    SwapHooks
        MOV     Hooked,1
RunIO:  CALL    CheckMultiplex
        CALL    CheckParse
        CALL    CheckPath
        CALL    CheckFind
        MOV     DX,OFFSET NameB
        XOR     CX,CX
        MOV     AH,5Bh                  ; create-new succeeds exactly once
        INT     21h
        Check   JNC
        MOV     BX,AX
        MOV     CX,1                    ; distinct pre-commit size and data
        MOV     DX,OFFSET Payload+1
        CALL    WriteFile
        CALL    Close
        MOV     DX,OFFSET NameB
        XOR     CX,CX
        MOV     AH,5Bh
        INT     21h
        Check   JC
        CMP     AX,80
        Check   JE
        MOV     DX,OFFSET NameB
        XOR     CX,CX
        MOV     AH,3Ch
        INT     21h
        Check   JNC
        MOV     BX,AX
        MOV     CX,1                    ; recreate truncated the old contents
        MOV     DX,OFFSET Cache
        MOV     AH,3Fh
        INT     21h
        Check   JNC
        OR      AX,AX
        Check   JZ
        MOV     DX,OFFSET Payload
        MOV     CX,4
        CALL    WriteFile
        CMP     AX,CX
        Check   JE
        MOV     AX,5702h                ; local EA size query
        XOR     CX,CX
        INT     21h
        Check   JNC
        CMP     CX,2
        Check   JE
        CALL    CheckInvalidFileTime
        ; Committing a dirty file must keep the shared SFT usable.
        MOV     AH,45h                  ; duplicate the open handle
        INT     21h
        Check   JNC
        PUSH    BX
        MOV     BX,AX
        MOV     AH,68h
        INT     21h
        Check   JNC
        PUSH    BX
        CALL    CheckCommitted
        POP     BX
        CALL    Close                   ; original handle remains open
        POP     BX
        ; Overwrite from byte three across sector and cluster boundaries.
        MOV     DX,3
        CALL    Seek
        MOV     DI,OFFSET Cache
        MOV     CX,1539
        MOV     AX,0137h
Pattern:
        MOV     [DI],AL
        ADD     AX,013Dh
        XCHG    AL,AH
        INC     DI
        LOOP    Pattern
        MOV     DX,OFFSET Cache
        MOV     CX,1539
        CALL    WriteFile
        CMP     AX,CX
        Check   JE
        CALL    Close
        MOV     DX,OFFSET NameB
        MOV     AX,3D02h
        INT     21h
        Check   JNC
        MOV     BX,AX
        MOV     DX,OFFSET Cache+1540
        MOV     CX,1543                 ; read one byte past EOF
        MOV     AH,3Fh
        INT     21h
        Check   JNC
        CMP     AX,1542
        Check   JE
        CMP     WORD PTR Cache+1540,4241h
        Check   JE
        CMP     BYTE PTR Cache+1542,'C'
        Check   JE
        PUSH    DS
        POP     ES
        MOV     SI,OFFSET Cache
        MOV     DI,OFFSET Cache+1543
        MOV     CX,1539
        REPE    CMPSB
        Check   JE
        MOV     AX,4200h                ; seek beyond the capacity of B:
        MOV     CX,0040h
        XOR     DX,DX
        INT     21h
        Check   JNC
        MOV     DX,OFFSET Cache
        MOV     CX,1
        MOV     AH,3Fh
        INT     21h
        Check   JNC
        OR      AX,AX
        Check   JZ
        MOV     DX,2
        CALL    Seek
        XOR     CX,CX
        CALL    WriteFile               ; truncate to two bytes
        OR      AX,AX
        Check   JZ
        XOR     DX,DX
        CALL    Seek
        MOV     DX,OFFSET Cache
        MOV     CX,4
        MOV     AH,3Fh
        INT     21h
        Check   JNC
        CMP     AX,2
        Check   JE
        CMP     WORD PTR Cache,4241h
        Check   JE
        MOV     AH,3Fh
        INT     21h
        Check   JNC
        OR      AX,AX
        Check   JZ
        MOV     DX,OFFSET Cache
        MOV     CX,4096
        MOV     SI,362                  ; 1.44M scratch floppy
Fill:   CALL    WriteFile
        ADD     WORD PTR Filled,AX
        ADC     WORD PTR Filled+2,0
        CMP     AX,CX
        JB      Full
        Check   JE
        DEC     SI
        JNZ     Fill
        JMP     Failed
Full:   CALL    WriteFile
        OR      AX,AX
        Check   JZ
        CALL    Close
        MOV     DX,OFFSET NameB
        MOV     AX,3D00h
        INT     21h
        Check   JNC
        MOV     BX,AX
        MOV     AX,4202h                ; persisted size includes partial write
        XOR     CX,CX
        XOR     DX,DX
        INT     21h
        Check   JNC
        CMP     AX,WORD PTR Filled
        Check   JE
        CMP     DX,WORD PTR Filled+2
        Check   JE
        MOV     CX,1
        MOV     AH,40h
        INT     21h
        Check   JC
        CMP     AX,5
        Check   JE
        CALL    Close
        MOV     DX,OFFSET NullDev
        MOV     AX,3D02h
        INT     21h
        Check   JNC
        MOV     BX,AX
        MOV     DX,OFFSET Cache
        MOV     CX,4
        CALL    WriteFile
        CMP     AX,CX
        Check   JE
        MOV     AH,3Fh
        INT     21h
        Check   JNC
        OR      AX,AX
        Check   JZ
        CALL    Close
        MOV     DX,OFFSET Cache
        MOV     AH,1Ah
        INT     21h
        MOV     AH,16h                  ; create, write and reopen an FCB
        CALL    FcbCall
        MOV     WORD PTR Cache,1234h
        MOV     AH,15h
        CALL    FcbCall
        MOV     AH,10h
        CALL    FcbCall
        MOV     AH,0Fh
        CALL    FcbCall
        MOV     BYTE PTR Fcb+32,0       ; OPEN leaves the caller's current record intact
        CMP     Hooked,0
        JE      ReadFirstRecord
        CALL    CheckLockViolation
ReadFirstRecord:
        MOV     WORD PTR Cache,0
        MOV     AH,14h
        CALL    FcbCall
        CMP     WORD PTR Cache,1234h
        Check   JE
        MOV     AH,10h
        CALL    FcbCall
        MOV     DX,OFFSET FindFCB
        MOV     AH,11h                  ; FCB first returns the padded name at DTA+1
        INT     21h
        OR      AL,AL
        Check   JZ
        PUSH    DS
        POP     ES
        MOV     SI,OFFSET Cache+1
        MOV     DI,OFFSET FcbName
        MOV     CX,11
        REPE    CMPSB
        Check   JE
        MOV     DX,OFFSET FindFCB
        MOV     AH,12h                  ; exact name has no second match
        INT     21h
        CMP     AL,0FFh
        Check   JE
        MOV     AH,13h                  ; delete the exact FCB match, then verify absence
        MOV     DX,OFFSET FindFCB
        INT     21h
        OR      AL,AL
        Check   JZ
        MOV     AH,11h
        MOV     DX,OFFSET FindFCB
        INT     21h
        CMP     AL,0FFh
        Check   JE
        JMP     SHORT Passed
CheckShare:
        MOV     AX,1000h                ; share installation check
        INT     2Fh
        CMP     AL,0FFh
        Check   JE
        MOV     DX,OFFSET NameB
        MOV     AX,3D10h                ; open read, deny all
        INT     21h
        Check   JNC
        MOV     BX,AX
        MOV     DX,OFFSET NameB
        MOV     AX,3D40h                ; second read conflicts
        INT     21h
        Check   JC
        CMP     AX,5                    ; open reports access denied
        Check   JE
        PUSH    BX
        XOR     BX,BX
        MOV     AH,59h                  ; extended error identifies sharing
        INT     21h
        POP     BX
        CMP     AX,32
        Check   JE
        CALL    Close
        CALL    CheckShareRetry
Passed: MOV     DX,OFFSET Success
        JMP     SHORT Print
Failed: MOV     DX,OFFSET Failure
Print:  CMP     Hooked,0
        JE      PrintResult
        PUSH    DX
        CALL    SwapHooks
        POP     DX
        CMP     Seen,127                ; includes the rename/delete sharing callback
        JNE     BadCallback
        CMP     CallbackA20,0
        JE      PrintResult
BadCallback:
        MOV     DX,OFFSET Failure
PrintResult:
        MOV     AH,9
        INT     21h
        MOV     AX,4C00h
        INT     21h
; Observe the documented INT 2Ah enter notification on this scratch boot.
; Enable only the entry hook and consume its notifications locally.
CheckInvalidFileTime:
        PUSH    BX                      ; open file handle
        MOV     AX,352Ah
        INT     21h
        MOV     WORD PTR OldInt2A,BX
        MOV     WORD PTR OldInt2A+2,ES
        MOV     DX,OFFSET ObserveEnter
        MOV     AX,252Ah
        INT     21h
        MOV     AX,3521h
        INT     21h                     ; ES = resident DOS segment
        POP     BX
        MOV     AL,50h                  ; PUSH AX enables the CRIT hook
        XCHG    AL,ES:[EnterSft]
        PUSH    AX
        MOV     AX,5702h                ; positive control: valid EA size query
        XOR     CX,CX
        INT     21h
        MOV     CL,EnterCount
        MOV     AX,5705h                ; unsupported, must never enter
        INT     21h
        POP     DX
        MOV     ES:[EnterSft],DL
        PUSHF
        PUSH    AX
        PUSH    DS
        LDS     DX,OldInt2A
        MOV     AX,252Ah
        INT     21h
        POP     DS
        POP     AX
        POPF
        Check   JC
        CMP     AX,1
        Check   JE
        OR      CL,CL
        Check   JNZ
        CMP     CL,EnterCount
        Check   JE
        RET
ObserveEnter:
        PUSHF
        CMP     AX,8001h                ; disk and SFT share this hook
        JNE     ChainInt2A
        INC     CS:EnterCount
        POPF
        IRET
ChainInt2A:
        POPF
        JMP     DWORD PTR CS:OldInt2A
OldInt2A DD     ?
EnterCount DB   0

SwapVector MACRO slot, vector
        MOV     AX,WORD PTR vector
        XCHG    AX,ES:[ShareTable+4*slot]
        MOV     WORD PTR vector,AX
        MOV     AX,WORD PTR vector+2
        XCHG    AX,ES:[ShareTable+4*slot+2]
        MOV     WORD PTR vector+2,AX
        ENDM

SwapHooks:
        MOV     AX,3521h
        INT     21h
        PUSHF
        CLI
        SwapVector 8,RangeEntry
        SwapVector 14,UpdateEntry
        SwapVector 10,SaveEntry
        SwapVector 11,CheckEntry
        SwapVector 13,DeleteEntry
        POPF
        RET

; Refuse a new file at SHARE slot 1. Exercise the public multiplex entry
; inside DOS, then let ShareEnter exhaust its retries and undo the create.
CheckShareRetry:
        MOV     AX,58FEh                ; observe A20 only when DOS uses the HMA
        INT     21h
        Check   JNC
        OR      AX,AX
        JZ      InstallShareHooks
        CALL    GetXmsEntry
InstallShareHooks:
        MOV     AX,3524h
        INT     21h
        MOV     WORD PTR OldInt24Share,BX
        MOV     WORD PTR OldInt24Share+2,ES
        MOV     DX,OFFSET ShareCritical
        MOV     AX,2524h
        INT     21h
        CALL    SwapShareEnter
        MOV     DX,OFFSET ShareName
        XOR     CX,CX
        MOV     AH,3Ch
        INT     21h
        PUSHF
        CALL    SwapShareEnter
        PUSH    DS
        LDS     DX,OldInt24Share
        MOV     AX,2524h
        INT     21h
        POP     DS
        POPF
        Check   JC
        CMP     CallbackA20,0
        Check   JE
        CMP     MultiplexResult,1
        Check   JE
        CMP     ShareCalls,4
        Check   JE
        CMP     AttemptsBeforeRetry,DefaultShareTries
        Check   JE
        CMP     ShareAttempts,DefaultShareTries
        Check   JE
        MOV     DX,OFFSET ShareName
        MOV     AX,4300h                ; the failed create removed its entry
        INT     21h
        Check   JC
        CMP     AX,2
        Check   JE
        RET

SwapShareEnter:
        MOV     AX,3521h
        INT     21h
        PUSHF
        CLI
        SwapVector 1,ShareEntry
        POPF
        RET

RefuseShare:
        PUSHF
        CMP     CS:ShareCalls,4         ; bound an erroneous retry after Fail
        JB      RefuseActive
        POPF
        JMP     CS:ShareEntry
RefuseActive:
        POPF
        INC     CS:ShareAttempts
        CALL    ObserveShareA20
        CMP     CS:ShareCalls,0
        JNE     ReturnConflict
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    BP
        MOV     AX,32                  ; stacked error for INT 2Fh/120Ah
        PUSH    AX
        MOV     AX,120Ah
        INT     2Fh
        POP     AX
        JC      MultiplexDone          ; first handler reply was Retry
        PUSH    AX
        MOV     AX,120Ah
        INT     2Fh
        POP     AX
        JNC     MultiplexDone          ; second handler reply was Fail
        INC     CS:MultiplexResult
MultiplexDone:
        POP     BP
        POP     SI
        POP     DX
        POP     CX
        POP     BX
ReturnConflict:
        MOV     AX,32
        STC
        RETF

ShareCritical:
        CALL    ObserveShareA20
        INC     CS:ShareCalls
        CMP     CS:ShareCalls,3         ; first two calls are the explicit 120Ah probes
        JNE     ShareResponseCode
        MOV     AL,CS:ShareAttempts     ; first create-time prompt answers Retry
        MOV     CS:AttemptsBeforeRetry,AL
        MOV     CS:ShareAttempts,0      ; count fresh attempts before Fail
ShareResponseCode:
        MOV     AL,1                    ; Retry then Fail for each pair
        TEST    CS:ShareCalls,1
        JNZ     ShareReply
        MOV     AL,3
ShareReply:
        IRET
ObserveShareA20:
        CMP     WORD PTR CS:XmsEntry+2,0
        JE      ShareA20Done
        CALL    ObserveA20
ShareA20Done:
        RET
ShareEntry DD   RefuseShare
OldInt24Share DD 0
ShareName DB    'A:\SHRPROBE.TMP',0
ShareCalls DB   0
DefaultShareTries EQU 3                 ; these scratch boots use the DOS default
ShareAttempts DB 0
AttemptsBeforeRetry DB 0
MultiplexResult DB 0

; Force a conflict on the open FCB. Retry must repeat the request and Fail
; must complete it without advancing the current record.
CheckLockViolation:
        MOV     AX,3524h
        INT     21h
        MOV     WORD PTR OldInt24Lock,BX
        MOV     WORD PTR OldInt24Lock+2,ES
        MOV     DX,OFFSET LockCritical
        MOV     AX,2524h
        INT     21h
        MOV     LockFault,1
        MOV     DX,OFFSET Fcb
        MOV     AH,14h
        INT     21h
        MOV     LockFault,0
        PUSH    AX
        PUSH    DS
        LDS     DX,OldInt24Lock
        MOV     AX,2524h
        INT     21h
        POP     DS
        POP     AX
        OR      AL,AL
        Check   JNZ
        CMP     CriticalCalls,2
        Check   JE
        CMP     BYTE PTR Fcb+32,0
        Check   JE
        RET
RangeHook:
        PUSHF
        CMP     CS:LockFault,0
        JNE     RangeConflict
        POPF
        JMP     CS:RangeEntry
RangeConflict:
        CALL    ObserveA20
        POPF
        STC
        RETF
LockCritical:
        INC     CS:CriticalCalls
        MOV     AL,1                    ; Retry
        CMP     CS:CriticalCalls,1
        JE      LockResponse
        MOV     CS:LockFault,0          ; bound a spurious third attempt
        MOV     AL,3                    ; Fail
LockResponse:
        IRET
OldInt24Lock DD 0
RangeEntry DD   RangeHook
LockFault DB    0
CriticalCalls DB 0

; The resident sharer must see A20 released on every callback.
UpdateHook:
        PUSHF
        OR      AX,AX                   ; close timestamps use SHARE slot 14 with AX=0
        JNZ     UpdateSize
        OR      CS:Seen,16
        JMP     SHORT UpdateState
UpdateSize:
        CMP     AX,1
        JNE     CheckShrink
        OR      CS:Seen,1
        JMP     SHORT UpdateState
CheckShrink:
        CMP     AX,2
        JNE     UpdateDone
        OR      CS:Seen,2
UpdateState:
        ; A DOS callback supplies the kernel stack required by DATE16.
        TEST    CS:Seen,32
        JNZ     DateChecked
        PUSH    AX
        PUSH    DX
        PUSH    DS
        MOV     AX,120Dh
        PUSH    AX
        INT     2Fh
        POP     DX
        CMP     AX,285Dh                ; FAT date for 2000-02-29
        POP     DS
        POP     DX
        POP     AX
        JNE     DateChecked
        OR      CS:Seen,32
DateChecked:
        CALL    ObserveA20
UpdateDone:
        POPF
        JMP     CS:UpdateEntry
SaveHook:
        PUSHF
        OR      CS:Seen,4
        CALL    ObserveA20
        POPF
        JMP     CS:SaveEntry
CheckHook:
        PUSHF
        OR      CS:Seen,8
        CALL    ObserveA20
        POPF
        JMP     CS:CheckEntry
DeleteHook:
        PUSHF
        OR      CS:Seen,64
        CALL    ObserveA20
        POPF
        JMP     CS:DeleteEntry
GetXmsEntry:
        MOV     AX,4310h
        INT     2Fh
        MOV     WORD PTR XmsEntry,BX
        MOV     WORD PTR XmsEntry+2,ES
        RET
ObserveA20:
        PUSH    AX
        PUSH    BX
        MOV     AH,7
        CALL    CS:XmsEntry
        OR      CS:CallbackA20,AL
        POP     BX
        POP     AX
        RET
UpdateEntry DD  UpdateHook
SaveEntry DD    SaveHook
CheckEntry DD   CheckHook
DeleteEntry DD  DeleteHook
XmsEntry DD     0
Hooked  DB      0
Seen    DB      0
CallbackA20 DB  0

; These INT 2Fh interfaces also run on an application's stack.
CheckMultiplex:
        CALL    CheckDeviceName
        MOV     AX,'q'                  ; INT 2Fh uppercase on the caller's stack
        PUSH    AX
        MOV     AX,1213h
        INT     2Fh
        POP     BX
        CMP     AL,'Q'
        Check   JE
        ; INT 2Fh/1205h takes the character in the stacked AX. Keep the
        ; application stack and capture its output through the redirected handle.
        PUSH    DS
        MOV     AX,1203h
        PUSH    AX
        INT     2Fh
        POP     BX
        MOV     AX,'!'
        PUSH    AX
        MOV     AX,1205h
        INT     2Fh
        POP     BX
        POP     DS
        MOV     DX,OFFSET OutputReturned
        MOV     AH,9
        INT     21h
        PUSH    DS
        POP     ES
        MOV     DI,OFFSET MockSft
        MOV     AX,1208h                ; release one SFT reference
        PUSH    AX
        INT     2Fh
        POP     BX
        CMP     AX,1
        Check   JE
        CMP     MockSft,-1
        Check   JE
        CALL    CheckNetworkClose
        MOV     SI,DI
        MOV     AX,1214h                ; compare equal pointers, then unequal
        PUSH    AX
        INT     2Fh
        POP     BX
        Check   JE
        INC     SI
        MOV     AX,1214h
        PUSH    AX
        INT     2Fh
        POP     BX
        Check   JNE
        MOV     DI,OFFSET MockBuffer
        MOV     AX,1209h                ; clean buffer: invalidate without I/O
        PUSH    AX
        INT     2Fh
        POP     BX
        Check   JNC
        CMP     BYTE PTR MockBuffer+4,0FFh
        Check   JE
        RET
 ; INT 2Fh/1223h receives DOSGROUP in DS and ES on the application's stack.
CheckDeviceName:
        PUSH    DS
        PUSH    ES
        MOV     AX,1203h
        PUSH    AX
        INT     2Fh
        POP     AX
        PUSH    DS
        POP     ES
        PUSH    WORD PTR ES:[DevicePtr]
        PUSH    WORD PTR ES:[DevicePtr+2]
        PUSH    WORD PTR ES:[DeviceAttr]
        XOR     SI,SI
SaveDeviceName:
        PUSH    WORD PTR ES:[DeviceName+SI]
        MOV     WORD PTR ES:[DeviceName+SI],2020h
        ADD     SI,2
        CMP     SI,8
        JB      SaveDeviceName
        MOV     WORD PTR ES:[DeviceName],554Eh  ; NUL, blank padded
        MOV     BYTE PTR ES:[DeviceName+2],'L'
        MOV     BYTE PTR ES:[DeviceAttr],0
        MOV     AX,1223h
        PUSH    AX
        INT     2Fh
        POP     AX
        MOV     CX,1
        JC      RestoreDeviceName
        MOV     AX,ES
        MOV     DX,DS
        CMP     AX,DX
        JNE     RestoreDeviceName
        CMP     AX,ES:[DevicePtr+2]
        JNE     RestoreDeviceName
        CMP     WORD PTR ES:[DevicePtr],NullHeader
        JNE     RestoreDeviceName
        MOV     BYTE PTR ES:[DeviceAttr],8      ; volume labels exclude devices
        MOV     AX,1223h
        PUSH    AX
        INT     2Fh
        POP     AX
        JNC     RestoreDeviceName
        MOV     DX,DS
        MOV     AX,ES
        MOV     CX,DX
        SUB     CX,AX
RestoreDeviceName:
        SUB     SI,2
        POP     WORD PTR ES:[DeviceName+SI]
        OR      SI,SI
        JNZ     RestoreDeviceName
        POP     WORD PTR ES:[DeviceAttr]
        POP     WORD PTR ES:[DevicePtr+2]
        POP     WORD PTR ES:[DevicePtr]
        POP     ES
        POP     DS
        OR      CX,CX
        Check   JZ
        RET
 ; Supply a synthetic remote SFT and intercept only the redirector close.
 ; Restore the DOS pointer before calling DOS to remove the test hook.
CheckNetworkClose:
        PUSH    ES
        PUSH    DI
        MOV     AX,352Fh
        INT     21h
        MOV     WORD PTR OldMultiplex,BX
        MOV     WORD PTR OldMultiplex+2,ES
        MOV     DX,OFFSET NetworkHook
        MOV     AX,252Fh
        INT     21h
        CALL    CheckRedirectedIoctl
        MOV     DX,OFFSET RemoteName
        MOV     AH,41h                  ; unlink must propagate the redirector error
        INT     21h
        JNC     AssignQuery
        MOV     DeleteReply,AX
AssignQuery:
        MOV     AX,5F02h                ; assignment-list query
        INT     21h
        JC      PrinterQuery
        MOV     AssignReply,AX
PrinterQuery:
        MOV     AX,5E05h                ; get printer flags
        INT     21h
        JC      QueriesDone
        MOV     PrinterReply,AX
QueriesDone:
        PUSH    DS
        MOV     AX,1203h                ; obtain DOSGROUP in DS
        PUSH    AX
        INT     2Fh
        POP     AX
        PUSH    WORD PTR DS:[CurrentSFT]
        PUSH    WORD PTR DS:[CurrentSFT+2]
        MOV     WORD PTR DS:[CurrentSFT],OFFSET RemoteSFT
        MOV     WORD PTR DS:[CurrentSFT+2],CS
        MOV     WORD PTR CS:[RemoteSFT+5],80h ; local character device for open
        MOV     WORD PTR CS:[RemoteSFT+9],CS
        MOV     CS:PacketSegment,DS
        MOV     AX,120Ch                ; set SFT mode on the application stack
        PUSH    AX
        INT     2Fh
        POP     BX
        JC      BadOpenMode
        ; Repeat on the application stack with a driver that rejects OPEN.
        ; 120Ch must finish SFT initialization and unwind to this exact stack.
        MOV     CS:OpenStack,SP
        MOV     AX,120Ch
        PUSH    AX
        INT     2Fh
        POP     BX
        JC      BadOpenMode
        CMP     SP,CS:OpenStack
        JNE     BadOpenMode
        ; A DOSGROUP-relative write through SS lands in this guard.
        PUSH    ES
        PUSH    DI
        PUSH    SS
        POP     ES
        XOR     DI,DI
        MOV     CX,GuardWords
        MOV     AX,0A5A5h
        REPE    SCASW
        POP     DI
        POP     ES
        JNE     BadOpenMode
        MOV     WORD PTR CS:[RemoteSFT+5],8000h ; remote SFT for close
        MOV     AX,1201h
        PUSH    AX
        INT     2Fh
        POP     BX
        JMP     SHORT RestoreSFT
BadOpenMode:
        XOR     AX,AX
RestoreSFT:
        PUSHF
        POP     CX
        POP     WORD PTR DS:[CurrentSFT+2]
        POP     WORD PTR DS:[CurrentSFT]
        POP     DS
        PUSH    AX
        PUSH    CX
        PUSH    DS
        LDS     DX,OldMultiplex
        MOV     AX,252Fh
        INT     21h
        POP     DS
        POP     CX
        POP     AX
        POP     DI
        POP     ES
        TEST    CX,1
        Check   JNZ
        CMP     AX,1234h
        Check   JE
        CMP     AssignReply,5F02h
        Check   JE
        CMP     PrinterReply,5E05h
        Check   JE
        CMP     DeleteSeen,1
        Check   JE
        CMP     DeleteReply,5
        Check   JE
        CMP     LockReplies,2
        Check   JE
        CMP     IoctlResult,441Ch
        Check   JE
        CMP     OpenSeen,3
        Check   JE
        RET
; Temporarily attach a local IFS header to stdin on this scratch boot.
; Save and restore the real SFT before any console output or disk access.
CheckRedirectedIoctl:
        XOR     BX,BX
        MOV     AX,1220h                ; ES:DI -> stdin's JFN
        PUSH    AX
        INT     2Fh
        POP     AX
        JC      IoctlTestDone
        MOV     BL,ES:[DI]
        MOV     AX,1216h                ; ES:DI -> SFT for that JFN
        PUSH    AX
        INT     2Fh
        POP     AX
        JC      IoctlTestDone
        PUSH    WORD PTR ES:[DI+5]      ; sf_flags
        PUSH    WORD PTR ES:[DI+55]     ; sf_IFS_HDR
        PUSH    WORD PTR ES:[DI+57]
        OR      WORD PTR ES:[DI+5],8080h
        MOV     WORD PTR ES:[DI+55],OFFSET LocalIfsHeader
        MOV     ES:[DI+57],CS
        CALL    CheckRemoteLocks
        XOR     BX,BX
        MOV     CX,004Ah
        MOV     DX,OFFSET Payload
        MOV     AX,440Ch
        INT     21h
        POP     WORD PTR ES:[DI+57]
        POP     WORD PTR ES:[DI+55]
        POP     WORD PTR ES:[DI+5]
        JC      IoctlTestDone
        MOV     IoctlResult,AX
IoctlTestDone:
        RET
; The redirector receives one resident eight-byte range and the original
; lock/unlock function in BX. Return a distinctive documented lock error.
CheckRemoteLocks:
        PUSH    DI
        MOV     AX,5C00h
        CALL    RemoteLock
        MOV     AX,5C01h
        CALL    RemoteLock
        POP     DI
        RET
RemoteLock:
        XOR     BX,BX                   ; stdin has the temporary remote flag
        MOV     CX,2
        MOV     DX,3
        MOV     SI,4
        MOV     DI,5
        INT     21h
        JNC     RemoteLockDone
        CMP     AX,33
        JNE     RemoteLockDone
        INC     LockReplies
RemoteLockDone:
        RET
LockReplies DB 0
LocalIfsHeader DB 14 DUP (0)            ; IFSREMOTE clear in attribute at +12
IoctlResult DW 0

ReturnDelete:
        POPF
        INC     CS:DeleteSeen
        CMP     CS:Hooked,0
        JE      DenyDelete
        CALL    ObserveA20
DenyDelete:
        MOV     AX,5
        STC
        RETF    2
DeleteSeen  DB 0
DeleteReply DW 0
RemoteName  DB '\\SERVER\SHARE\DELETE.TMP',0

ReturnClose:
        POPF
        MOV     AX,1234h
        STC
        RETF    2
ReturnLock:
        POPF
        CMP     CX,1
        JNE     BadLockPacket
        MOV     AX,DS
        MOV     SI,SS                   ; DOS stack on this INT 21h path
        CMP     AX,SI
        JNE     BadLockPacket
        MOV     SI,DX
        CMP     WORD PTR [SI],3
        JNE     BadLockPacket
        CMP     WORD PTR [SI+2],2
        JNE     BadLockPacket
        CMP     WORD PTR [SI+4],5
        JNE     BadLockPacket
        CMP     WORD PTR [SI+6],4
        JNE     BadLockPacket
        MOV     AL,CS:LockReplies
        MOV     AH,5Ch
        CMP     AX,BX
        JNE     BadLockPacket
        CMP     CS:Hooked,0
        JE      RejectRange
        CALL    ObserveA20
RejectRange:
        MOV     AX,33
        STC
        RETF    2
BadLockPacket:
        MOV     AX,1
        STC
        RETF    2
NetworkHook:
        PUSHF
        CMP     AX,110Ah
        JE      ReturnLock
        CMP     AX,1106h
        JE      ReturnClose
        CMP     AX,112Bh
        JE      ReturnIoctl
        CMP     AX,1113h
        JNE     CheckMacroQuery
        JMP     ReturnDelete
CheckMacroQuery:
        CMP     AX,111Eh
        JE      ReturnMacroQuery
        CMP     AX,111Fh
        JE      ReturnMacroQuery
        POPF
        JMP     CS:OldMultiplex
ReturnMacroQuery:
        POPF
        PUSH    BP
        MOV     BP,SP
        MOV     DX,[BP+8]               ; original INT 21h function
        POP     BP
        CMP     AX,111Eh
        JNE     CheckPrinterQuery
        CMP     DX,5F02h
        JMP     SHORT MacroQueryChecked
CheckPrinterQuery:
        CMP     DX,5E05h
MacroQueryChecked:
        JNE     BadIoctlPacket
        CMP     CS:Hooked,0
        JE      ReturnStackedFunction
        CALL    ObserveA20
ReturnStackedFunction:
        MOV     AX,DX
        CLC
        RETF    2
AssignReply  DW 0
PrinterReply DW 0
ReturnIoctl:
        POPF
        PUSH    BP
        MOV     BP,SP
        MOV     AX,[BP+8]               ; caller's function after IP, CS, FLAGS
        POP     BP
        CMP     AX,440Ch
        JNE     BadIoctlPacket
        CMP     CX,004Ah
        JNE     BadIoctlPacket
        MOV     AX,DS
        MOV     SI,CS
        CMP     AX,SI
        JNE     BadIoctlPacket
        CMP     DX,OFFSET Payload
        JNE     BadIoctlPacket
        CMP     CS:Hooked,0
        JE      IoctlPacketOk
        CALL    ObserveA20
IoctlPacketOk:
        MOV     AX,441Ch
        CLC
        RETF    2
BadIoctlPacket:
        XOR     AX,AX
        STC
        RETF    2
OldMultiplex DD 0
RemoteSFT DB 5 DUP (0)                 ; sf_flags at offset 5
          DW 8000h
          DW OFFSET MockDevice,0        ; sf_devptr
          DB 48 DUP (0)                 ; remaining DOS 4 SFT fields
MockDevice DD -1
          DW 8800h                      ; character driver with open/close
          DW OFFSET MockStrategy,OFFSET MockInterrupt
          DB 'TESTDEV '
OpenStack DW 0
PacketSegment DW 0
OpenSeen DB 0
MockStrategy PROC FAR
        PUSH AX
        MOV AX,ES
        CMP AX,CS:PacketSegment
        JNE EndStrategy
        CMP BYTE PTR ES:[BX],13         ; open packet length
        JNE EndStrategy
        CMP BYTE PTR ES:[BX+2],13       ; open command
        JNE EndStrategy
        INC CS:OpenSeen
EndStrategy:
        POP AX
        RET
MockStrategy ENDP
MockInterrupt PROC FAR
        CMP CS:OpenSeen,1
        JE FirstOpen
        MOV WORD PTR ES:[BX+3],810Ch    ; done, error, general failure
        RET
FirstOpen:
        INC CS:OpenSeen
        MOV WORD PTR ES:[BX+3],0100h    ; request complete
        RET
MockInterrupt ENDP
OutputReturned DB ' OUTT PASS',13,10,'$'
MockSft DW 1
MockBuffer DB 6 DUP (0)

CheckParse:
        PUSH    DS
        POP     ES
        MOV     SI,OFFSET WildArg
        MOV     DI,OFFSET Parsed
        MOV     AX,2900h
        INT     21h
        CMP     AL,1
        Check   JE
        CMP     SI,OFFSET WildEnd
        Check   JE
        MOV     SI,OFFSET WildFCB
        CALL    CompareFCB
        MOV     SI,OFFSET PlainArg
        MOV     DI,OFFSET Parsed
        MOV     AX,2900h
        INT     21h
        OR      AL,AL
        Check   JZ
        CMP     SI,OFFSET PlainEnd
        Check   JE
        MOV     SI,OFFSET PlainFCB
CompareFCB:
        MOV     DI,OFFSET Parsed
        MOV     CX,12                   ; drive, padded name and extension
        REPE    CMPSB
        Check   JE
        RET

CheckFind:
        ; Put the second match beyond 32 nonmatching directory entries.
        MOV     BP,32
FillDirectory:
        MOV     DX,OFFSET FillPath
        XOR     CX,CX
        MOV     AH,5Bh
        INT     21h
        Check   JNC
        MOV     BX,AX
        CALL    Close
        INC     FillDigit
        CMP     FillDigit,'9'
        JBE     FilledOne
        MOV     FillDigit,'0'
        INC     FillDigit-1
FilledOne:
        DEC     BP
        JNZ     FillDirectory
        MOV     DX,OFFSET OtherPath
        MOV     CX,1                    ; read-only, zero-length file
        MOV     AH,3Ch
        INT     21h
        Check   JNC
        MOV     BX,AX
        CALL    Close
        MOV     DX,OFFSET FindDTA
        MOV     AH,1Ah
        INT     21h
        MOV     DX,OFFSET FindMask
        XOR     CX,CX
        MOV     AH,4Eh
        INT     21h
        Check   JNC
        MOV     BP,0                    ; one bit per distinct result
FindResult:
        PUSH    DS
        POP     ES
        MOV     DI,OFFSET FindDTA+30
        MOV     SI,OFFSET Leaf
        MOV     CX,9
        REPE    CMPSB
        JNE     OtherResult
        TEST    BP,1
        Check   JZ
        OR      BP,1
        CMP     WORD PTR FindDTA+26,4
        Check   JE
        TEST    BYTE PTR FindDTA+21,1
        Check   JZ
        JMP     SHORT NextResult
OtherResult:
        MOV     DI,OFFSET FindDTA+30
        MOV     SI,OFFSET OtherName
        MOV     CX,10
        REPE    CMPSB
        Check   JE
        TEST    BP,2
        Check   JZ
        OR      BP,2
        TEST    BYTE PTR FindDTA+21,1
        Check   JNZ
NextResult:
        MOV     AH,4Fh
        INT     21h
        JNC     FindResult
        CMP     AX,18
        Check   JE
        CMP     BP,3
        Check   JE
        RET
CheckPath:
        MOV     DX,OFFSET PathDir
        MOV     AH,39h
        INT     21h
        Check   JNC
        MOV     AH,3Bh
        INT     21h
        Check   JNC
        MOV     DX,OFFSET Leaf
        XOR     CX,CX
        MOV     AH,3Ch
        INT     21h
        Check   JNC
        MOV     BX,AX
        MOV     CX,4
        MOV     DX,OFFSET Payload
        CALL    WriteFile
        CALL    Close
        MOV     DX,OFFSET RootDir
        MOV     AH,3Bh
        INT     21h
        Check   JNC
        MOV     DX,OFFSET FullPath
        MOV     AX,3D00h
        INT     21h
        Check   JNC
        MOV     BX,AX
        MOV     CX,4
        MOV     DX,OFFSET Cache
        MOV     AH,3Fh
        INT     21h
        Check   JNC
        CMP     AX,4
        Check   JE
        CMP     WORD PTR Cache+2,4443h
        Check   JE
        CALL    Close
        MOV     DX,OFFSET Leaf          ; absent in root
        MOV     AX,3D00h
        INT     21h
        Check   JC
        CMP     AX,2
        Check   JE
        MOV     DX,OFFSET BadPath       ; missing intermediate directory
        MOV     AX,3D00h
        INT     21h
        Check   JC
        CMP     AX,3
        Check   JE
        RET
FcbCall:
        MOV     DX,OFFSET Fcb
        INT     21h
        OR      AL,AL
        Check   JZ
        RET
; Read the test runner's 1.44 MB FAT12 B: directly while both handles
; are open. Root sectors 19..32 precede one-sector clusters at LBA 33.
CheckCommitted:
        MOV     DX,19
CheckRootSector:
        CALL    ReadSector
        MOV     SI,OFFSET Cache
        MOV     CX,16                    ; 32-byte entries per sector
CheckRootEntry:
        CMP     BYTE PTR [SI],0
        Check   JNE
        PUSH    CX
        PUSH    SI
        PUSH    DS
        POP     ES
        MOV     DI,OFFSET DiskName
        MOV     CX,11
        CLD
        REPE    CMPSB
        POP     SI
        POP     CX
        JE      CheckDiskSize
        ADD     SI,32
        LOOP    CheckRootEntry
        INC     DX
        CMP     DX,33
        JB      CheckRootSector
        JMP     Failed
CheckDiskSize:
        CMP     WORD PTR [SI+28],4
        Check   JE
        CMP     WORD PTR [SI+30],0
        Check   JE
        MOV     DX,[SI+26]
        CMP     DX,2
        Check   JAE
        CMP     DX,2848                  ; last data cluster on the fixture
        Check   JBE
        ADD     DX,33-2
        CALL    ReadSector
        MOV     SI,OFFSET Cache
        MOV     DI,OFFSET Payload
        PUSH    DS
        POP     ES
        MOV     CX,4
        CLD
        REPE    CMPSB
        Check   JE
        RET
ReadSector:
        PUSH    DX
        MOV     AL,1                     ; B:
        MOV     CX,1
        MOV     BX,OFFSET Cache
        INT     25h
        POP     CX                       ; INT 25h leaves FLAGS on the stack
        POP     DX
        Check   JNC
        RET
Seek:   XOR     CX,CX
        MOV     AX,4200h
        INT     21h
        Check   JNC
        RET
WriteFile:
        MOV     AH,40h
        INT     21h
        Check   JNC
        RET
Close:  MOV     AH,3Eh
        INT     21h
        Check   JNC
        RET
Success DB      'HMA I/O PASS',13,10,'$'
Failure DB      'HMA I/O FAIL',13,10,'$'
Filled  DD      2                       ; two bytes before the fill loop
LayoutOK DB     'LAYOUT PASS',13,10,'$'
ProbeMode DB    ?
Layout  DB      ?
WildArg DB      'a:ab*.tx?'
WildEnd DB      ' rest',0
WildFCB DB      1,'AB??????TX?'
PlainArg DB     'plain'
PlainEnd DB     0
PlainFCB DB     0,'PLAIN      '
Parsed  DB      37 DUP (0)
FillPath DB     '\HMAPATH\F0'
FillDigit DB    '0.DAT',0
FindMask DB     '\HMAPATH\*.TMP',0
OtherPath DB    '\HMAPATH\OTHER.TMP',0
OtherName DB    'OTHER.TMP',0
FindDTA DB      43 DUP (0)
RootDir DB      '\',0
PathDir DB      '\HMAPATH',0
Leaf    DB      'LEAF.TMP',0
FullPath DB     '\HMAPATH\LEAF.TMP',0
BadPath DB      '\MISSING\LEAF.TMP',0
DiskName DB     'FULL    TMP'
NameB   DB      'B:FULL.TMP',0
NullDev DB      'NUL',0
Payload DB      'ABCD'
FindFCB DB      0
        DB      'HMATEST TMP',25 DUP (0)
FcbName DB      'HMATEST TMP'
Fcb     DB      0,'HMATEST TMP',25 DUP (0)
Cache   DB      4096 DUP (0)
CODE    ENDS
STACK   SEGMENT PARA STACK 'STACK'
GuardWords EQU 1024
        DW      GuardWords DUP (0A5A5h)
        DW      128 DUP (?)
STACK   ENDS
        END     Start
