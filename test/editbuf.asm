; Direct INT 21h/0Ah regression probe. Each case queues IBM BIOS key words
; (no more than 15) and checks the caller buffer, CR and boundary sentinels.
testcode segment para public 'CODE'
        assume cs:testcode,ds:testcode
start:  push cs
        pop ds
        mov dx,offset empty
        mov ah,0ah
        int 21h
        cmp word ptr empty[1],0a55ah
        jne failed
        mov si,offset cases
again:  lodsw                           ; capacity, template length
        cmp ax,0ffffh
        je passed
        mov word ptr buf,ax
        xor bx,bx
        mov bl,al
        mov byte ptr buf[bx+2],0a5h
        mov cl,ah
        xor ch,ch
        push ds
        pop es
        mov di,offset buf+2
        rep movsb
        lodsb                           ; template terminator (may be invalid)
        stosb
        lodsb
        xor ah,ah
        mov cx,ax
        mov ax,40h
        mov es,ax
        pushf
        cli
        mov di,1eh
        mov word ptr es:[1ah],di
        rep movsw
        mov es:[1ch],di
        popf
        mov ah,0ah
        mov dx,offset buf
        int 21h
        cmp guard,05ah
        jne failed
        cmp byte ptr buf[bx+2],0a5h
        jne failed
        lodsb
        cmp al,buf[1]
        jne failed
        xor ah,ah
        mov cx,ax
        inc cx                          ; compare CR too
        push ds
        pop es
        mov di,offset buf+2
        repe cmpsb
        jne failed
        inc caseid
        jmp again
failed: mov bp,1
        mov dx,offset bad
        jmp short report
passed: xor bp,bp
        mov dx,offset good
report: mov ah,9
        int 21h
        mov dl,caseid
        mov ah,2
        int 21h
        mov ax,bp
        mov ah,4ch
        int 21h

leftkey equ 4b00h
rightkey equ 4d00h
homekey equ 4700h
endkey equ 4f00h
upkey equ 4800h
downkey equ 5000h
inskey equ 5200h
delkey equ 5300h
cases:
        ; On the second invocation this PSP and buffer can have the same address.
        db 255,0,13,2
        dw upkey,13
        db 0,13
        db 8,0,13,5
        dw 'a','b',leftkey,'x',13
        db 3,'axb',13
        db 8,0,13,9
        dw 'a','b',homekey,downkey,rightkey,delkey,endkey,'c',13
        db 2,'ac',13
        db 3,0,13,8
        dw 'a','b','z',homekey,'x',inskey,'y',13
        db 2,'yb',13
        db 8,3,'old',13,8
        dw upkey,homekey,rightkey,8,upkey,'b',endkey,13
        db 3,'bld',13
        db 8,3,'bad',0,2
        dw upkey,13
        db 0,13
        db 1,0,13,4
        dw 'a',leftkey,delkey,13
        db 0,13
        db 8,3,'old',13,5
        dw 'x',27,upkey,8,13
        db 2,'ol',13
        db 8,4,'abcd',13,4
        dw 3b00h,3c00h,'d',13         ; F1, F2 up to d
        db 3,'abc',13
        db 8,4,'abcd',13,4
        dw 3e00h,'c',3d00h,13         ; F4 to c, F3
        db 2,'cd',13
        db 8,0,13,7
        dw 'a','b',homekey,3f00h,3d00h,4000h,13 ; F5 template, F3, F6
        db 3,'ab',26,13
        db 8,0,13,2
        dw 4100h,13                    ; F7 literal escape prefix
        db 1,0,13
        db 255,254,254 dup ('x'),13,6
        dw upkey,homekey,inskey,'a',endkey,13
        db 254,'a',253 dup ('x'),13
        dw 0ffffh
guard   db 5ah
buf     db 258 dup (0)
caseid  db 'A'
empty   db 0,5ah,0a5h
good    db 13,10,'EDIT PASS $'
bad     db 13,10,'EDIT FAIL $'
testcode ends
stk segment stack
        dw 128 dup (?)
stk ends
end start
