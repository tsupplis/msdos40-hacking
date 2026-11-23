; Test-only BIOS hook: fail the first partition record write on disk 80h.
; Count subsequent writes so a caller cannot pass by merely returning an error.
bits 16
cpu 8086
org 100h
    jmp start
previous dd 0
failed db 0
later db 0
cylinder db 0
hook:
    pushf
    cmp dl,80h
    jne chain
    cmp ah,3
    jne chain
    cmp byte [cs:failed],0
    jne unexpected
    cmp al,1
    jne chain
    cmp ch,[cs:cylinder]
    jne chain
    or dh,dh                    ; partition records use head 0, sector 1
    jnz chain
    cmp cl,1                    ; fixture cylinders are below 256
    jne chain
    inc byte [cs:failed]
    popf
    mov ah,3
    stc
    retf 2
unexpected:
    mov byte [cs:later],1
chain:
    popf
    jmp far [cs:previous]
start:
    mov ax,3513h
    int 21h
    cmp byte [82h],'c'
    je check
    cmp byte [80h],0
    je install
    mov byte [cylinder],150      ; existing fixture chain head
install:
    mov [previous],bx
    mov [previous+2],es
    mov dx,hook
    mov ax,2513h
    int 21h
    mov dx,(start-$$+100h+15)/16
    mov ax,3100h
    int 21h
check:
    cmp bx,hook
    jne bad
    cmp word [es:failed],1       ; failed = 1, later = 0
    jne bad
    mov ax,4c00h
    int 21h
bad:
    mov ax,4c01h
    int 21h
