; SHELL waits for the command processor named by COMSPEC. DOS inherits the
; current environment and standard handles. The parameter block and tail
; live on BASIC's stack for the duration of EXEC.
        .radix 10
DSEG    segment public 'DATASG'
DSEG    ends
CSEG    segment public 'CODESG'
        assume cs:CSEG,ds:DSEG
        public ExecShell
; ES:DI is the command processor path. DS:SI and CX give the command text
; (0..123 bytes). SS=DS. Return carry and AX directly from DOS EXEC.
ExecShell:
        push bp
        mov bp,sp
        push es
        push di
        sub sp,144
        mov bx,sp
        push ds
        pop es
        lea di,[bx+14]
        push di
        push cx
        xor ax,ax               ; DOS copies all 128 tail bytes to the child PSP.
        mov cx,64
        rep stosw
        pop cx
        pop di
        mov [bx+2],di
        mov [bx+4],ds
        xor ax,ax
        mov [bx],ax             ; Inherit parent's environment.
        mov al,cl
        jcxz EmptyTail
        add al,3
        stosb
        mov al,'/'
        stosb
        mov al,'C'
        stosb
        mov al,' '
        stosb
        rep movsb
        jmp short EndTail
EmptyTail:
        stosb
EndTail:
        mov al,13
        stosb
        push bx
        mov ah,62h
        int 21h
        mov dx,bx
        pop bx
        mov word ptr [bx+6],5ch ; PSP default FCB addresses.
        mov [bx+8],dx
        mov word ptr [bx+10],6ch
        mov [bx+12],dx
        mov dx,[bp-4]           ; Saved ASCIIZ path offset and segment.
        mov ax,[bp-2]
        push ds
        push ds
        pop es                  ; ES:BX parameter block
        mov ds,ax               ; DS:DX executable
        mov ax,4b00h
        int 21h
        pop ds
        mov sp,bp
        pop bp
        ret
CSEG    ends
        end
