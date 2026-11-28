; DOS process environment. Keep the space limit seen at entry even when
; replacing an entry with a shorter value. DOS 3+ stores the executable
; name after the variables, so it must move together with the final NUL.
        .radix 10
DSEG    segment public 'DATASG'
EnvLimit dw 0
EnvBlock dw 0                   ; Known usable bytes, rounded to paragraphs.
DSEG    ends
CSEG    segment public 'CODESG'
        assume cs:CSEG,ds:DSEG
        public SetEnv
; DS:SI and CX identify the BASIC assignment string. Return AL=0, 5 or 7.
SetEnv:
        mov bx,si
        xor dx,dx               ; Name length, including the equals sign.
CheckInput:
        jcxz InputEnd
        mov al,[bx]
        or al,al
        jz Invalid
        inc bx
        or dx,dx
        jnz NextByte
        cmp al,'='
        jne NextByte
        mov dx,bx
        sub dx,si
NextByte:
        loop CheckInput
InputEnd:
        cmp dx,1
        ja ValidName
Invalid:
        mov al,5
        ret
ValidName:
        sub bx,si
        cmp bx,dx
        jne HaveValue
        xor bx,bx               ; Empty value deletes the entry.
HaveValue:
        push bp
        mov bp,sp
        sub sp,16
        ; SS=DS in the interpreter. Stack locals remain valid while ES
        ; points to the DOS environment and during the segment copies.
argptr  equ word ptr [bp-2]
arglen  equ word ptr [bp-4]
oldpos  equ word ptr [bp-6]
oldlen  equ word ptr [bp-8]
varend  equ word ptr [bp-10]    ; Offset of final NUL after last entry.
tail    equ word ptr [bp-12]    ; Offset of DOS trailing string count.
tailsz  equ word ptr [bp-14]
newend  equ word ptr [bp-16]
        mov argptr,si
        mov arglen,bx
        mov oldlen,0
        push es
        mov ah,62h
        int 21h
        mov es,bx
        mov ax,es:[2ch]
        or ax,ax
        jnz HaveEnv
        jmp NoEnvironment
HaveEnv:
        mov es,ax
        xor di,di
        mov cx,7fffh            ; Same maximum environment length as EXEC.
        cld
NextEntry:
        cmp byte ptr es:[di],0
        je EndEntries
        mov bx,di
        xor al,al
        repne scasb
        jne EnvFull
        jcxz EnvFull
        cmp oldlen,0
        jne NextEntry
        mov ax,di
        sub ax,bx
        cmp ax,dx
        jbe NextEntry
        push di
        push cx
        mov di,bx
        mov si,argptr
        mov cx,dx
        repe cmpsb
        pop cx
        pop di
        jne NextEntry
        mov oldpos,bx
        mov oldlen,ax
        jmp short NextEntry
EnvFull:
        pop es
        mov sp,bp
        pop bp
        mov al,7
        ret
EndEntries:
        mov varend,di
        or di,di
        jnz EndNonempty
        inc di                  ; An empty list consists of two NULs.
EndNonempty:
        inc di
        mov tail,di
        cmp EnvLimit,0
        jne LimitKnown
        mov ax,di
        and ax,0fff0h
        add ax,16
        mov EnvLimit,ax
LimitKnown:
        mov ax,varend
        sub ax,oldlen
        mov bx,arglen
        or bx,bx
        jz CheckSize
        add ax,bx
        inc ax
CheckSize:
        mov newend,ax
        or ax,ax
        jnz CountNul
        inc ax
CountNul:
        inc ax
        cmp ax,EnvLimit
        ja EnvFull
        mov dx,es:[di]          ; Preserve every counted trailer string.
        inc di
        inc di
        xor al,al
        or dx,dx
        jz TailDone
ScanTail:
        mov cx,8000h
        sub cx,di
        jbe EnvFull
        repne scasb
        jne EnvFull
        dec dx
        jnz ScanTail
TailDone:
        mov cx,di
        sub cx,tail
        mov tailsz,cx
        cmp EnvBlock,0
        jne HaveBlock
        add di,15
        and di,0fff0h
        mov EnvBlock,di
HaveBlock:
        mov bx,newend
        or bx,bx
        jnz NeedNul
        inc bx
NeedNul:
        inc bx
        add bx,cx
        cmp bx,EnvBlock
        jbe Edit
        ; Ask DOS before using space beyond the known end of the block.
        ; Never infer writable capacity from a memory-control block.
        add bx,15
        and bx,0fff0h
        push bx
        mov cl,4
        shr bx,cl
        mov ah,4ah
        int 21h
        pop bx
        jnc BlockResized
        jmp EnvFull
BlockResized:
        mov EnvBlock,bx
Edit:
        ; Remove the old entry first, then position the DOS trailer. At
        ; that point the remaining entries end below both trailer positions.
        mov di,varend
        mov cx,oldlen
        jcxz PositionTail
        mov di,oldpos
        mov si,di
        add si,cx
        mov cx,varend
        sub cx,si
        push ds
        push es
        pop ds
        rep movsb
        pop ds
PositionTail:
        push di                 ; Append position in the compacted list.
        mov di,newend
        or di,di
        jnz TrailerDest
        inc di
TrailerDest:
        inc di
        mov si,tail
        mov cx,tailsz
        cmp di,si
        je TailMoved
        jb CopyTail
        add si,cx
        add di,cx
        dec si
        dec di
        std
CopyTail:
        push ds
        push es
        pop ds
        rep movsb
        cld
        pop ds
TailMoved:
        pop di
Append:
        mov cx,arglen
        jcxz Terminate
        mov si,argptr
        rep movsb
        xor al,al
        stosb
Terminate:
        xor al,al
        or di,di
        jnz FinalNul
        stosb
FinalNul:
        stosb
Finished:
        pop es
        mov sp,bp
        pop bp
        xor al,al
        ret

NoEnvironment:
        ; DOS permits a PSP with no environment segment. Deleting an
        ; absent entry is already complete. Creating one needs storage.
        cmp arglen,0
        je Finished
        jmp EnvFull
; CX=name length and DS:SI=name, or CX=0 and DL=one-based index.
; Return ES:DI at the value (name) or whole entry (index), CF if absent.
        public FindEnv
FindEnv:
        push dx
        mov ah,62h              ; DOS 3+ Get PSP Address.
        int 21h
        mov es,bx
        mov ax,es:[2ch]
        pop dx
        xor di,di
        or ax,ax
        jz EnvEmpty
        mov es,ax
        cld
EnvEntry:
        cmp byte ptr es:[di],0
        je EnvEmpty
        jcxz EnvIndex
        push si
        push cx
        push di
        repe cmpsb
        pop bx
        pop cx
        pop si
        jne EnvSkipName
        cmp byte ptr es:[di],'='
        jne EnvSkipName
        inc di
        jmp short EnvFound
EnvSkipName: mov di,bx
        jmp short EnvNext
EnvIndex:
        dec dl
        jz EnvFound
EnvNext:
        inc di
        cmp byte ptr es:[di-1],0
        jne EnvNext
        jmp short EnvEntry
EnvEmpty:
        stc
        ret
EnvFound:
        clc
        ret
CSEG    ends
        end
