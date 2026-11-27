; Reject writes to a selected sector on the scratch 1.44 MB floppy B:.
%ifndef FAIL_SECTOR
%define FAIL_SECTOR 1           ; first FAT
%endif
%ifndef ALLOW_WRITES
%define ALLOW_WRITES 0
%endif
bits 16
cpu 8086
org 100h
    jmp install
previous dd 0
%if ALLOW_WRITES
remaining db ALLOW_WRITES
%endif
hook:
    pushf
    cmp al,1
    jne chain
    cmp cx,0ffffh
    jne chain
    cmp word [bx],FAIL_SECTOR
    jne chain
    cmp word [bx+2],0
    jne chain
%if ALLOW_WRITES
    cmp byte [cs:remaining],0
    je reject
    dec byte [cs:remaining]
    jmp short chain
%endif
reject:
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
