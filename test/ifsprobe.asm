; With a command tail, install a predecessor for SHARE's INT 2Fh handler.
; Without arguments, verify the retired interfaces and preserved swap area.
bits 16
org 100h
    cmp byte [80h],0
    je check
    mov ax,352fh
    int 21h
    mov [previous],bx
    mov [previous+2],es
    mov dx,multiplex
    mov ax,252fh
    int 21h
    mov dx,(check-$$+100h+15)/16
    mov ax,3100h
    int 21h

multiplex:
    cmp ax,1040h
    jne .chain
    mov ax,0caf0h
    iret
.chain:
    jmp far [cs:previous]
previous dd 0

check:
    mov ah,52h
    int 21h
    mov ax,[es:bx+37h]          ; Reserved far pointer in the DOS sysvars ABI
    or ax,[es:bx+39h]
    jnz fail
    mov [kernel_seg],es
    mov ax,5d06h
    mov dx,dpl
    int 21h
    jc fail
    mov ax,ds
    push cs
    pop ds
    cmp ax,[kernel_seg]
    jne fail
    cmp si,SWAP_START
    jne fail
    cmp cx,(SWAP_END-SWAP_START+1) & 0fffeh
    jne fail
    cmp dx,SWAP_ALWAYS-SWAP_START
    jne fail
    mov ax,5d0bh
    int 21h
    jnc fail
    cmp ax,1
    jne fail
    mov ax,1000h               ; Check SHARE actually loaded before testing chaining.
    int 2fh
    cmp al,0ffh
    jne fail
    mov ax,1040h
    int 2fh
    cmp ax,0caf0h
    jne fail
    mov dx,success
    jmp print
fail:
    push cs
    pop ds
    mov dx,failure
print:
    mov ah,9
    int 21h
    int 20h

kernel_seg dw 0
dpl times 22 db 0
success db 'IFS PASS',13,10,'$'
failure db 'IFS FAIL',13,10,'$'
