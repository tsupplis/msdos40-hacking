; Report physical placement and raw DOS arguments, then return ERRORLEVEL 37.
bits 16
cpu 8086
org 100h
    mov ax,cs
    cmp ax,1000h
    mov dx,lowmsg
    jb show
    mov dx,highmsg
show:
    mov ah,9
    int 21h
    xor cx,cx
    mov cl,[80h]
    mov bx,1
    mov dx,81h
    mov ah,40h
    int 21h
    mov ax,4c25h
    int 21h
lowmsg db 'PSP LOW$'
highmsg db 'PSP HIGH$'
