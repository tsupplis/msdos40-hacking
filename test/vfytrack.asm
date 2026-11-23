; Test-only TSR for a fresh DOS boot. Observe the DISKCOPY target (B:)
; without altering registers, flags, or the result of the driver's IOCTL.
bits 16
cpu 8086
org 100h
    jmp start
previous dd 0
requests dw 0
hook:
    pushf
    cmp ax,440dh
    jne chain
    cmp cx,0862h
    jne chain
    cmp bl,2
    jne chain
    inc word [cs:requests]
chain:
    popf
    jmp far [cs:previous]
resident_end:

start:
    mov ax,3521h
    int 21h
    cmp byte [80h],0
    jne check
    mov [previous],bx
    mov [previous+2],es
    mov dx,hook
    mov ax,2521h
    int 21h
    mov dx,(resident_end-$$+100h+15)/16
    mov ax,3100h
    int 21h
check:
    ; Boot fixture installs this hook immediately before DISKCOPY.
    cmp bx,hook
    jne failed
    mov ax,[es:requests]
    cmp byte [82h],'0'
    je expect_zero
    cmp ax,160                 ; 80 cylinders, two heads
    jne failed
    jmp short passed
expect_zero:
    or ax,ax
    jnz failed
passed:
    mov ax,4c00h
    int 21h
failed:
    mov ax,4c01h
    int 21h
