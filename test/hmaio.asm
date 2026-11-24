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
        CMP     WORD PTR ES:[OpenSlot],EntryIP
        JNE     Placed
        MOV     ES,ES:[GateSeg]
        MOV     AL,'h'
        CMP     WORD PTR ES:[BodyOff],0FFFFh
        JE      Placed
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
        MOV     AX,4310h
        INT     2Fh
        MOV     WORD PTR XmsEntry,BX
        MOV     WORD PTR XmsEntry+2,ES
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
        MOV     BYTE PTR Fcb+32,0       ; current record
        MOV     WORD PTR Cache,0
        MOV     AH,14h
        CALL    FcbCall
        CMP     WORD PTR Cache,1234h
        Check   JE
        MOV     AH,10h
        CALL    FcbCall
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
Passed: MOV     DX,OFFSET Success
        JMP     SHORT Print
Failed: MOV     DX,OFFSET Failure
Print:  CMP     Hooked,0
        JE      PrintResult
        PUSH    DX
        CALL    SwapHooks
        POP     DX
        CMP     Seen,31                 ; growth, truncation, FCB save and check
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
        SwapVector 14,UpdateEntry
        SwapVector 10,SaveEntry
        SwapVector 11,CheckEntry
        POPF
        RET

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
XmsEntry DD     0
Hooked  DB      0
Seen    DB      0
CallbackA20 DB  0

; These INT 2Fh interfaces also run on an application's stack.
CheckMultiplex:
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
        PUSH    DS
        MOV     AX,1203h                ; obtain DOSGROUP in DS
        PUSH    AX
        INT     2Fh
        POP     AX
        PUSH    WORD PTR DS:[CurrentSFT]
        PUSH    WORD PTR DS:[CurrentSFT+2]
        MOV     WORD PTR DS:[CurrentSFT],OFFSET RemoteSFT
        MOV     WORD PTR DS:[CurrentSFT+2],CS
        MOV     AX,1201h
        PUSH    AX
        INT     2Fh
        POP     BX
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
        RET
NetworkHook:
        PUSHF
        CMP     AX,1106h
        JE      ReturnClose
        POPF
        JMP     CS:OldMultiplex
ReturnClose:
        POPF
        MOV     AX,1234h
        STC
        RETF    2
OldMultiplex DD 0
RemoteSFT DB 5 DUP (0)                 ; sf_flags at offset 5
          DW 8000h
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
Fcb     DB      0,'HMATEST TMP',25 DUP (0)
Cache   DB      4096 DUP (0)
CODE    ENDS
STACK   SEGMENT PARA STACK 'STACK'
        DW      128 DUP (?)
STACK   ENDS
        END     Start
