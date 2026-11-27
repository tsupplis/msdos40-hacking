; Discovery probe: exit 0 = absent, 1 = this driver, 2 = UMBS alone,
; 3 = this driver with UMB services, 4 = unexpected, 5 = PCEHIMEM.
; Offset all exit codes by 16 so a missing probe cannot mimic success.
bits 16
cpu 8086
org 100h
        mov ax,4300h
        int 2fh
        cmp al,80h
        jne absent
        mov ax,4310h
        int 2fh
        mov [entry],bx
        mov [entry+2],es
        xor ax,ax
        call far [entry]
        cmp ax,0300h
        je pce
        cmp ax,0200h
        jne other
        cmp bx,1
        jne bad
        cmp dx,1
        jne bad
        mov dx,0ffffh
        mov ah,8
        call far [entry]
        cmp ax,dx                 ; a fresh pool is one contiguous extent
        jne bad
        test ax,ax
        jz bad
        cmp bl,0
        jne bad
        mov ah,10h
        mov dx,0ffffh             ; ask for more than the largest UMB
        call far [entry]
        test ax,ax
        jnz bad
        cmp bl,80h
        je native
        cmp bl,0b0h
        jne bad
        ; With DOS low, the fixture's entire D000-D100 range is available.
        cmp dx,100h
        jne bad
        mov ah,10h
        call far [entry]
        cmp ax,1
        jne bad
        cmp bx,0d000h
        jne bad
        cmp dx,100h
        jne bad
        mov dx,bx
        mov ah,11h                ; UMBS gives ranges away for this boot
        call far [entry]
        test ax,ax
        jnz bad
        cmp bl,80h
        jne bad
        mov dx,1
        mov ah,10h
        call far [entry]
        test ax,ax
        jnz bad
        cmp bl,0b1h
        jne bad
        test dx,dx
        jnz bad
        mov al,3
        jmp done
pce:    cmp bx,0300h
        jne bad
        cmp dx,1
        jne bad
        mov al,5
        jmp done
other:  or ax,bx                   ; UMBS returns version and revision zero
        or ax,dx
        jnz bad
        mov al,2
        jmp done
native: mov al,1
        jmp done
absent: xor al,al
        jmp done
bad:    mov al,4
done:
        add al,10h
%ifdef QEMU
        mov dx,0f4h                ; host receives (AL * 2) + 1
        out dx,al
%endif
        mov ah,4ch
        int 21h
entry dd 0
