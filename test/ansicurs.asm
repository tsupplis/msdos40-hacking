; Verify ANSI cursor movement against BIOS and the reply on standard input (CON).
bits 16
org 100h

        mov ax,3
        int 10h
        xor bx,bx
        mov dx,1800h            ; last row of the 25-line screen
        mov ah,2
        int 10h
        mov si,down
        call emit
        xor bx,bx
        mov ah,3
        int 10h
        cmp dx,1800h
        jne failed

        mov ax,0501h            ; activate page 1
        int 10h
        mov si,position
        call emit
        mov bh,1
        mov ah,3
        int 10h
        cmp dx,0913h
        jne failed
        xor bx,bx
        mov ah,3
        int 10h
        cmp dx,1800h            ; page 0 must still be on the last line
        jne failed

        mov si,query
        call emit
        mov si,reply
.read:  mov ah,06h              ; poll console without echo or blocking
        mov dl,0ffh
        int 21h
        jz failed
        cmp al,[si]
        jne failed
        inc si
        cmp si,reply_end
        jne .read
        xor al,al
        jmp short finish
failed: mov al,1
finish: push ax
        mov ax,0500h
        int 10h
        pop ax
        mov ah,4ch
        int 21h

emit:   lodsb
        test al,al
        jz .done
        int 29h
        jmp emit
.done:  ret

down     db 27,'[1B',0
position db 27,'[10;20H',0
query    db 27,'[6n',0
reply    db 27,'[10;20R',13
reply_end:
