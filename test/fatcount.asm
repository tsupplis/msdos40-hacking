; check_fat16 boots with C: on BIOS disk 80h, 4 heads, 17 sectors/track.
; Allow several reads, then reject retries (including reads of the second FAT).
bits 16
cpu 8086
org 100h
    mov ax,1203h
    push ax
    int 2fh                     ; DS = DOS data segment
    pop ax
    mov al,[FastFree]
    push cs
    pop ds
    add al,'0'
    cmp al,[82h]                ; expected SWITCHES setting from the batch
    jne failed
    mov ax,3513h
    int 21h
    mov [old13],bx
    mov [old13+2],es
    mov dx,bios
    mov ax,2513h
    int 21h
    mov dx,critical
    mov ax,2524h
    int 21h
    call space
    push ax
    lds dx,[old13]
    mov ax,2513h
    int 21h
    push cs
    pop ds
    pop ax
    cmp ax,-1
    jne failed
    cmp byte [hit],1
    jne failed
    call space
    cmp ax,2
    jne failed
    cmp bx,EXPECTED
    jne failed
    mov ax,4c00h
    int 21h
failed:
    mov ax,4c01h
    int 21h
space:
    mov dl,3
    mov ah,36h
    int 21h
    ret
critical:
    mov al,3
    iret
bios:
    pushf
    cmp dl,80h
    jne chain
    cmp ah,2
    jne chain
    cmp byte [cs:remaining],0
    je reject
    dec byte [cs:remaining]
    jmp short chain
reject:
    mov byte [cs:hit],1
    popf
    mov ah,4
    stc
    retf 2
chain:
    popf
    jmp far [cs:old13]
old13 dd 0
remaining db 8
hit db 0
