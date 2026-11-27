; Two independent PSPs contend for the same byte range on a shared handle-open file.
bits 16
cpu 8086
org 100h
    cmp byte [80h],0
    jne child
    mov sp,stacktop
    mov bx,(stacktop-$$+100h+15)/16
    mov ah,4ah
    int 21h
    jc fail
    mov dx,filename
    xor cx,cx
    mov ah,3ch
    int 21h
    jc fail
    mov bx,ax
    mov ah,3eh
    int 21h
    jc fail
    call open_shared
    mov [handle],bx
    mov al,2                        ; unsupported operation on a valid handle
    call range
    jnc fail
    cmp ax,1
    jne fail
    mov bx,0ffffh
    xor al,al
    call range
    jnc fail
    cmp ax,6
    jne fail
    mov bx,[handle]
    xor al,al
    call range
    jc fail
    mov [params+4],cs
    mov [params+8],cs
    mov [params+12],cs
    call run_child
    mov bx,[handle]
    mov al,1
    call range
    jc fail
    mov byte [tail+1],'U'
    call run_child
    mov dx,passed
    mov ah,9
    int 21h
success:
    mov ax,4c00h
    int 21h

child:
    call open_shared
    xor al,al
    call range
    jnc acquired
    cmp ax,33                       ; lock violation while parent owns range
    jne fail
    cmp byte [81h],'L'
    jne fail
    jmp success
acquired:
    cmp byte [81h],'U'              ; parent has released the same range
    jne fail
    mov al,1
    call range
    jc fail
    jmp success
fail:
    mov ax,4c01h
    int 21h

open_shared:
    mov dx,filename
    mov ax,3dc2h                    ; read/write, deny none, private handle
    int 21h
    jc fail
    mov bx,ax
    ret
range:
    xor cx,cx
    mov dx,1
    xor si,si
    mov di,2
    mov ah,5ch
    int 21h
    ret
run_child:
    push cs
    pop es
    mov [saved_sp],sp
    mov bx,params
    mov dx,program
    mov ax,4b00h
    int 21h
    cli
    mov bx,cs
    mov ss,bx
    mov sp,[cs:saved_sp]
    sti
    mov ds,bx
    jc fail
    mov ah,4dh
    int 21h
    or ax,ax
    jnz fail
    ret

saved_sp dw 0
handle dw 0
params dw 0,tail,0,5ch,0,6ch,0
program db 'A:\LOCKIO.COM',0
filename db 'A:\LOCKIO.TMP',0
passed db 'LOCK PASS',13,10,'$'
tail db 1,'L',13
     times 125 db 0
     times 256 db 0
stacktop:
