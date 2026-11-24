; Verify an EMS-backed directory read can fail and then be retried.
bits 16
cpu 8086
org 100h
    mov ax,1203h
    push ax
    int 2fh
    pop ax
    cmp byte [BufEmsMode],0
    push cs
    pop ds
    jne bad
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
    call findfile
    pushf
    lds dx,[old13]
    mov ax,2513h
    int 21h
    push cs
    pop ds
    popf
    jnc bad
    cmp byte [hit],1
    jne bad
    call findfile
    jc bad
    mov ax,4c00h
    int 21h
bad:
    mov ax,4c01h
    int 21h
findfile:
    mov dx,path
    xor cx,cx
    mov ah,4eh
    int 21h
    ret
critical:
    mov al,3                    ; fail the request
    iret
bios:
    pushf
    cmp dl,1
    jne chain
    cmp ah,2
    jne chain
    cmp ch,0
    jne chain
    cmp dh,1                    ; 1.44M root starts at CHS 0/1/2
    jne chain
    cmp cl,2
    jb chain
    mov byte [cs:hit],1
    popf
    mov ah,4
    stc
    retf 2
chain:
    popf
    jmp far [cs:old13]
old13 dd 0
hit db 0
path db 'B:\PAYLOAD.BIN',0
