; On an unformatted scratch B:, verify DOS returns a critical-error abort
; to the parent through INT 21h/4Dh, including the termination type in AH.
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
    mov [params+4],cs
    mov [params+8],cs
    mov [params+12],cs
    mov bx,params
    mov dx,program
    mov ax,4b00h
    int 21h
    cli
    mov bx,cs
    mov ss,bx
    mov sp,stacktop
    sti
    mov ds,bx
    jc fail
    mov ah,4dh
    int 21h
    cmp ax,0200h
    jne fail
    mov dx,passed
    mov ah,9
    int 21h
    mov ax,4c00h
    int 21h
child:
    mov dx,abort_io
    mov ax,2524h
    int 21h
    mov dx,filename
    mov ax,3d00h
    int 21h
fail:
    mov ax,4c01h
    int 21h
abort_io:
    mov al,2
    iret
params dw 0,tail,0,5ch,0,6ch,0
program db 'A:\PROCABRT.COM',0
filename db 'B:\PROBE',0
passed db 'PROC ABORT PASS',13,10,'$'
tail db 1,'C',13
     times 125 db 0
     times 256 db 0
stacktop:
