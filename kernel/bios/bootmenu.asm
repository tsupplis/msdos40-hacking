; BOOT.SYS selection. All storage is discarded with system initialization.
SYSINITSEG segment public 'SYSTEM_INIT'
        assume cs:SYSINITSEG, ds:SYSINITSEG
        public OpenConfig, ConfigPath, MakeConfigEnv, ConfigEnv
        extrn CONFIG:byte, MenuTitle:byte, MenuKeys:byte, MenuDefault:byte
        extrn MenuRange:byte,MenuTime:byte,MenuSeconds:byte
        extrn CRLFM:byte, BADLD_PRE:byte

BootFile db '\BOOT.SYS',0
DefaultKey db 'default',0
TimeoutKey db 'timeout',0
ConfigPath dw offset CONFIG
ConfigEnv dw 0                      ; zero until the entire configuration is read
Choices dw 0
Preferred dw 1
Seconds dw 2
LastTime dw ?
Names dw 9 dup (?)
Labels dw 9 dup (?)
; One DOS pathname and one display line per choice.
LineSize equ 160
Lines db 9 * LineSize dup (?)
LineBuf db LineSize dup (?)
InputBuf db 128 dup (?)
InputPos dw 0
InputEnd dw 0

; DS=CS. Return the open configuration handle in AX, or carry if skipped.
OpenConfig proc near
        cld
        mov dx,offset BootFile
        mov ax,3d00h
        stc                            ; retain failure if INT 24h intervenes
        int 21h
        jc OpenPath
        mov bx,ax
NextLine:
        mov di,offset LineBuf
ReadLine:
        mov si,InputPos
        cmp si,InputEnd
        jb HaveByte
        mov dx,offset InputBuf
        mov cx,128
        mov ah,3fh
        int 21h
        jc ReadFailed
        or ax,ax
        jz EndFile
        mov si,dx
        add ax,si
        mov InputEnd,ax
HaveByte:
        lodsb
        mov InputPos,si
        cmp al,1ah
        je EndFile
        cmp al,10
        je LineDone
        cmp al,13
        je ReadLine
        cmp di,offset LineBuf+LineSize
        jae ReadLine
        mov [di],al
        inc di
        jmp ReadLine
LineDone:
        call ParseLine
        jmp NextLine
ReadFailed:
        mov Choices,0
        jmp short CloseMenu
EndFile:
        call ParseLine
CloseMenu:
        mov ah,3eh
        int 21h
        cmp Choices,0
        je OpenPath
        call SelectEntry
        jc OpenReturn
        mov ConfigPath,dx
OpenPath:
        mov dx,ConfigPath
        mov ax,3d00h
        stc                            ; retain failure if INT 24h intervenes
        int 21h
        jnc OpenReturn
        cmp Choices,0
        je OpenSkipped
        mov dx,offset BADLD_PRE
        call PrintMsg
        mov si,ConfigPath
        call PrintText
        call NewLine
OpenSkipped:
        stc
OpenReturn:
        ret
OpenConfig endp

; Strip spaces and tabs on both ends of a zero-terminated field.
TrimField proc near
TrimLeft:
        cmp byte ptr [si],' '
        je EatSpace
        cmp byte ptr [si],9
        jne TrimScan
EatSpace:
        inc si
        jmp TrimLeft
TrimScan:
        mov di,si
TrimNext:
        cmp byte ptr [di],0
        je TrimRight
        inc di
        jmp TrimNext
TrimRight:
        cmp di,si
        je TrimDone
        cmp byte ptr [di-1],' '
        je DropSpace
        cmp byte ptr [di-1],9
        jne TrimDone
DropSpace:
        dec di
        mov byte ptr [di],0
        jmp TrimRight
TrimDone:
        ret
TrimField endp

; SI field, DI lowercase keyword. ZF set on an exact ASCII match.
IsKeyword proc near
        push si
KeywordNext:
        lodsb
        or al,al
        jz KeywordEnd
        or al,20h
        cmp al,[di]
        jne KeywordDone
        inc di
        jmp KeywordNext
KeywordEnd:
        cmp al,[di]
KeywordDone:
        pop si
        ret
IsKeyword endp

ParseLine proc near
        cmp di,offset LineBuf+LineSize
        jae ParseDone
        mov byte ptr [di],0
        mov si,offset LineBuf
        call TrimField
        cmp byte ptr [si],'#'
        je ParseDone
        mov di,si
FindEquals:
        cmp byte ptr [di],0
        je ParseDone
        cmp byte ptr [di],'='
        je SplitFields
        inc di
        jmp FindEquals
SplitFields:
        mov byte ptr [di],0
        inc di
        push si
        mov si,di
        call TrimField
        mov dx,si
        pop si
        call TrimField
        cmp byte ptr [si],0
        je ParseDone
        mov di,offset DefaultKey
        call IsKeyword
        je ParseDefault
        mov di,offset TimeoutKey
        call IsKeyword
        je ParseTimeout
        cmp Choices,9
        jae ParseDone
        push bx
        mov ax,LineSize
        push dx
        mul Choices
        pop dx
        add ax,offset Lines
        mov di,ax
        mov bx,Choices
        shl bx,1
        mov Names[bx],di
        ; The description follows the pathname in the same input line.
        call CopyField
        mov si,dx
        mov Labels[bx],di
        call CopyField
        inc Choices
        pop bx
ParseDone:
        ret
ParseDefault:
        mov di,offset Preferred
        jmp short ParseNumber
ParseTimeout:
        mov di,offset Seconds
ParseNumber:
        mov si,dx
        xor ax,ax
        cmp byte ptr [si],0
        je ParseDone
DigitLoop:
        mov cl,[si]
        sub cl,'0'
        cmp cl,9
        ja ParseDone
        xor ch,ch
        mov dx,10
        mul dx
        or dx,dx
        jnz ParseDone
        add ax,cx
        jc ParseDone
        inc si
        cmp byte ptr [si],0
        jne DigitLoop
        mov [di],ax
        ret
ParseLine endp

CopyField proc near
        lodsb
        mov [di],al
        inc di
        or al,al
        jnz CopyField
        ret
CopyField endp

SelectEntry proc near
        mov ax,Preferred
        dec ax
        cmp ax,Choices
        jb DefaultOK
        xor ax,ax
DefaultOK:
        mov Preferred,ax                 ; zero-based from here
        cmp Choices,1
        jne CheckSeconds
        jmp UseDefault
CheckSeconds:
        cmp Seconds,0
        jne ShowMenu
        jmp UseDefault
ShowMenu:
        mov dx,offset MenuTitle
        call PrintMsg
        xor bx,bx
ShowEntry:
        mov dl,bl
        shr dl,1
        add dl,'1'
        call PrintChar
        mov dl,'.'
        call PrintChar
        mov dl,' '
        call PrintChar
        mov si,Labels[bx]
        call PrintText
        call NewLine
        add bx,2
        mov ax,bx
        shr ax,1
        cmp ax,Choices
        jb ShowEntry
        mov dx,offset MenuRange
        call PrintMsg
        mov dx,Choices
        add dl,'0'
        call PrintChar
        mov dx,offset MenuKeys
        call PrintMsg
        mov dx,offset MenuDefault
        call PrintMsg
        mov dx,Preferred
        add dl,'1'
        call PrintChar
        mov dx,offset MenuTime
        call PrintMsg
        mov ax,Seconds
        call PrintNumber
        mov dx,offset MenuSeconds
        call PrintMsg
        call ClockValue
        mov LastTime,ax
WaitKey:
        mov ah,1
        int 16h
        jz CheckClock
        xor ah,ah
        int 16h
        cmp al,27
        je SkipEntry
        cmp al,13
        je UseDefault
        sub al,'1'
        xor ah,ah
        cmp ax,Choices
        jb UseEntry
CheckClock:
        call ClockValue
        sub ax,LastTime
        jnc ClockElapsed
        add ax,6000                    ; hundredths wrap at the minute
ClockElapsed:
        cmp ax,100
        jb WaitKey
        add LastTime,100
        cmp LastTime,6000
        jb CountSecond
        sub LastTime,6000
CountSecond:
        dec Seconds
        jnz WaitKey
UseDefault:
        mov ax,Preferred
UseEntry:
        mov bx,ax
        shl bx,1
        mov dx,Names[bx]
        clc
        ret
SkipEntry:
        stc
        ret
SelectEntry endp

ClockValue proc near
        mov ah,2ch
        int 21h
        mov al,dh
        mov ah,100
        mul ah
        xor dh,dh
        add ax,dx
        ret
ClockValue endp

; Print a decimal word, most significant digit first.
PrintNumber proc near
        xor dx,dx
        mov cx,10
        div cx
        push dx
        or ax,ax
        jz PrintDigit
        call PrintNumber
PrintDigit:
        pop dx
        add dl,'0'
        call PrintChar
        ret
PrintNumber endp

PrintText proc near
        lodsb
        or al,al
        jz TextEnd
        mov dl,al
        call PrintChar
        jmp PrintText
TextEnd:
        ret
PrintText endp
PrintChar proc near
        mov ah,2
        int 21h
        ret
PrintChar endp
NewLine proc near
        mov dx,offset CRLFM
NewLine endp
PrintMsg proc near
        mov ah,9
        int 21h
        ret
PrintMsg endp

; Called only after the complete file has been read. EXEC needs a segment
; (offset zero). Reuse the line buffer after the menu file has been closed.
; DS=CS. Preserve ES, SI, DI and CX for the configuration parser.
EnvKey db 'DOSCFG='
MakeConfigEnv proc near
        push es
        push si
        push di
        push cx
        push dx
        mov ax,offset LineBuf
        add ax,15
        mov cl,4
        shr ax,cl
        mov dx,ds
        add ax,dx
        mov es,ax
        xor di,di
        mov si,offset EnvKey
        mov cx,7
        rep movsb
        mov si,ConfigPath
        mov dx,si
FindBase:
        lodsb
        cmp al,':'
        je AfterSep
        cmp al,'\'
        je AfterSep
        cmp al,'/'
        jne TestEnd
AfterSep:
        mov dx,si
TestEnd:
        or al,al
        jnz FindBase
        mov si,dx
        mov cx,8
CopyBase:
        lodsb
        or al,al
        jz EndBase
        cmp al,'.'
        je EndBase
        stosb
        loop CopyBase
EndBase:
        xor ax,ax
        stosw
        mov ConfigEnv,es
        push ds
        push es
        pop ds
        mov dx,7                        ; uppercase the name using DOS country rules
        mov ax,6522h
        int 21h
        pop ds
        pop dx
        pop cx
        pop di
        pop si
        pop es
        ret
MakeConfigEnv endp

SYSINITSEG ends
        end
