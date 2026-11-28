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
    ; Closing a missing name fails.
    mov [dpl+12],ds
    mov dx,dpl
    mov ax,5d02h
    int 21h
    jnc fail
    cmp ax,3
    jne fail
    call check_server_closes
    ; SHARE must report the locked file and propagate end-of-list errors.
    mov dx,dpl
    mov ax,5d05h
    int 21h
    jnc fail
    cmp ax,18
    jne fail
    inc word [dpl+2]                ; start at zero after the invalid index
find_locked:
    mov dx,dpl
    mov ax,5d05h
    int 21h
    jc fail
    mov si,filename
    push cx
    mov cx,filename_end-filename
    repe cmpsb
    pop cx
    je found_locked
    inc word [dpl+2]
    jnz find_locked
    jmp fail
found_locked:
    cmp cx,1
    jne fail
    or bx,bx                        ; local machine ID
    jnz fail
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

; Two remote PIDs open the same file under one UID. The local handle and
; lock stay live throughout and are checked by the parent and child above.
check_server_closes:
    mov [dpl+14],ds
    mov word [dpl+6],filename
    mov word [dpl],3dc2h            ; open read/write, deny none
    call server_dos
    jc fail
    mov [first_handle],ax
    inc word [dpl+20]               ; second PID, same UID
    call server_dos
    jc fail
    mov [second_handle],ax
    dec word [dpl+20]
    mov dx,dpl
    mov ax,5d04h                    ; close only the first PID
    int 21h
    jc fail
    mov word [dpl],5700h            ; query file time as the remote owner
    mov ax,[first_handle]
    mov [dpl+2],ax
    call expect_closed
    inc word [dpl+20]
    mov ax,[second_handle]
    mov [dpl+2],ax
    call server_dos
    jc fail
    dec word [dpl+20]               ; user-wide close must ignore this PID
    mov dx,dpl
    mov ax,5d03h
    int 21h
    jc fail
    inc word [dpl+20]
    call expect_closed
    mov word [dpl+2],0ffffh         ; invalid index for the enumeration test
    ret
expect_closed:
    call server_dos
    jnc fail
    cmp ax,6                        ; invalid handle
    jne fail
    ret
server_dos:
    mov dx,dpl
    mov ax,5d00h
    int 21h
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
first_handle dw 0
second_handle dw 0
params dw 0,tail,0,5ch,0,6ch,0
program db 'A:\LOCKIO.COM',0
filename db 'A:\LOCKIO.TMP',0
filename_end:
absent db 'A:\ABSENT.TMP',0
dpl dw 0,0ffffh,0,absent,0,0,0,0,0,1234h,5678h
passed db 'LOCK PASS',13,10,'$'
tail db 1,'L',13
     times 125 db 0
     times 256 db 0
stacktop:
