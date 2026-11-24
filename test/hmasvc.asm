; Exercise allocation, extended-open action codes and canonical paths on B:.
bits 16
cpu 8086
org 100h
    mov sp,stacktop
    mov bx,(stacktop-$$+100h+15)/16
    mov ah,4ah
    int 21h
    jc fail
    mov bx,8
    mov ah,48h
    int 21h
    jc fail
    mov es,ax
    mov bx,4
    mov ah,4ah
    int 21h
    jc fail
    mov ah,49h
    int 21h
    jc fail
    mov bx,0ffffh
    mov ah,48h
    int 21h
    jnc fail
    cmp ax,8
    jne fail
    mov dx,directory
    mov ah,39h
    int 21h
    jc fail
    mov dx,10h                  ; create a missing file
    call xopen
    jc fail
    cmp cx,2
    jne fail
    call close
    mov dx,1                    ; open an existing file
    call xopen
    jc fail
    cmp cx,1
    jne fail
    call close
    mov dx,2                    ; replace an existing file
    call xopen
    jc fail
    cmp cx,3
    jne fail
    call close
    mov dx,flatname
    mov ah,41h
    int 21h
    jc fail
    mov dx,1
    call xopen
    jnc fail
    cmp ax,2
    jne fail
    ; Load an MZ overlay and verify the relocated word in the owned block.
    mov bx,16
    mov ah,48h
    int 21h
    jc fail
    mov [overlay_block],ax
    mov [overlay_block+2],ax
    push ds
    pop es
    mov bx,overlay_block
    mov dx,overlay_name
    mov ax,4b03h
    int 21h
    jc fail
    mov es,[overlay_block]
    mov ax,es
    add ax,7
    cmp ax,[es:0]
    jne fail
    mov ah,49h
    int 21h
    jc fail
    mov dx,okmsg
    mov ah,9
    int 21h
    mov ax,4c00h
    int 21h
fail:
    mov ax,4c01h
    int 21h
xopen:
    mov ax,6c00h
    mov bx,2
    xor cx,cx
    mov si,pathname
    int 21h
    ret
close:
    mov bx,ax
    mov ah,3eh
    int 21h
    jc fail
    ret
overlay_name db 'A:\SVCOVL.EXE',0
overlay_block dw 0,0
directory db 'B:\SVCDIR',0
pathname db 'B:\SVCDIR\..\SVCTEST.TMP',0
flatname db 'B:\SVCTEST.TMP',0
okmsg db 'HMA SERVICES PASS',13,10,'$'
times 256 db 0
stacktop:
