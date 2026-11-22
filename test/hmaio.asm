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
        MOV     DX,OFFSET NameB
        XOR     CX,CX
        MOV     AH,3Ch
        INT     21h
        Check   JNC
        MOV     BX,AX
        MOV     DX,OFFSET Payload
        MOV     CX,4
        CALL    WriteFile
        CMP     AX,CX
        Check   JE
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
        MOV     DX,OFFSET Success
        JMP     SHORT Print
Failed: MOV     DX,OFFSET Failure
Print:  MOV     AH,9
        INT     21h
        MOV     AX,4C00h
        INT     21h
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
Layout  DB      ?
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
