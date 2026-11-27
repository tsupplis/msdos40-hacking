; Test-only INIT driver. Claim an XMS block before the disk drivers load.
; INT 60h returns the baseline free KiB and the XMS service entry in ES:BX.
bits 16
org 0
        dd -1
        dw 8000h,strategy,entry
        db 'XMSHOLD '
request dd 0
xms     dd 0
free_kb dw 0
old13 dd 0
reads dw 0
disk:   pushf
        test dl,80h
        jz .chain
        cmp ah,2
        jne .chain
        inc word [cs:reads]
.chain: popf
        jmp far [cs:old13]
counter: mov ax,[cs:reads]
        iret
query:  les bx,[cs:xms]
        mov ax,[cs:free_kb]
        iret
strategy:
        mov [cs:request],bx
        mov [cs:request+2],es
        retf
entry:  push ax
        push bx
        push dx
        push ds
        push es
        push cs
        pop ds
        les bx,[request]
        mov word [es:bx+3],0100h
        cmp byte [es:bx+2],0
        jne .done
        mov word [es:bx+14],resident_end
        mov [es:bx+16],cs
        mov ax,4300h
        int 2fh
        cmp al,80h
        jne .bad
        mov ax,4310h
        int 2fh
        mov [xms],bx
        mov [xms+2],es
        mov ah,09h
        mov dx,8
        call far [xms]
        cmp ax,1
        jne .bad
        mov ah,08h
        call far [xms]
        mov [free_kb],dx
        mov ax,3513h
        int 21h
        mov [old13],bx
        mov [old13+2],es
        mov dx,disk
        mov ax,2513h
        int 21h
        mov dx,counter
        mov ax,2561h
        int 21h
        mov ax,2560h
        mov dx,query
        int 21h
        jmp short .done
.bad:   mov al,22h
        out 0f4h,al
.done:  pop es
        pop ds
        pop dx
        pop bx
        pop ax
        retf
resident_end:
