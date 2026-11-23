; Test-only TSR. Fail the first FAT write on scratch floppy B:.
bits 16
cpu 8086
org 100h
    jmp install
previous dd 0
hook:
    pushf
    cmp al,1
    jne chain
    cmp cx,0ffffh
    jne chain
    cmp word [bx],1             ; first FAT starts at logical sector 1
    jne chain
    cmp word [bx+2],0
    jne chain
    popf
    mov ax,000ah
    stc
    retf                        ; INT 26h leaves the original flags on stack
chain:
    popf
    jmp far [cs:previous]
install:
    mov ax,3526h
    int 21h
    mov [previous],bx
    mov [previous+2],es
    mov dx,hook
    mov ax,2526h
    int 21h
    mov dx,(install-$$+100h+15)/16
    mov ax,3100h
    int 21h
