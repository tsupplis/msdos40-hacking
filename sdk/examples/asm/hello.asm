code segment
    assume cs:code, ds:code
    org 100h
start:
    mov dx, offset greeting
    mov ah, 9
    int 21h
    mov ax, 4c00h
    int 21h
greeting db 'Hello from MASM',13,10,'$'
code ends
end start
