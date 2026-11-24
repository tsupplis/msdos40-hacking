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
RunIO:  CALL    CheckParse
        CALL    CheckPath
        CALL    CheckFind
        MOV     DX,OFFSET NameB
        XOR     CX,CX
        MOV     AH,5Bh                  ; create-new succeeds exactly once
        INT     21h
        Check   JNC
        MOV     BX,AX
        MOV     CX,4
        MOV     DX,OFFSET Payload
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
        CMP     Seen,15                 ; growth, truncation, FCB save and check
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
