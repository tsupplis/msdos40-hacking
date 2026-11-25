; Report SFT, FCB, IRQ0 handler and first disk-buffer bucket placement.
; L = conventional, U = upper. Read the live DOS 4 tables after boot.
bits 16
cpu 8086
org 100h
    mov ah,52h
    int 21h
    push es
    push bx
    les bx,[es:bx+4]       ; first SFT block contains five resident entries
    mov ax,[es:bx+2]      ; segment of the extension allocated by FILES
    call placement
    pop bx
    pop es
    mov ax,[es:bx+1ch]    ; segment of the FCB table
    call placement
    les bx,[es:bx+12h]    ; buffer info -> hash table -> first bucket
    les bx,[es:bx]
    mov si,[es:bx+4]
    mov ax,3508h          ; IRQ0 is hooked by STACKS
    int 21h
    mov ax,es
    call placement
    mov ax,si
    call placement
    mov dx,newline
    mov ah,9
    int 21h
    int 20h

placement:
    push bx
    push es
    mov dl,'L'
    cmp ax,0a000h
    jb .print
    mov dl,'U'
.print:
    mov ah,2
    int 21h
    pop es
    pop bx
    ret
newline db 13,10,'$'
