; DS:SI points to a CR-terminated command tail. DL is nonzero for
; literal-text and nested-command operands, where /? must stand alone.
; Returns carry for an unquoted /? token. Clobbers AX, CX and SI.
help_argument proc near
        xor ch,ch               ; nonzero inside a quoted argument
help_skip:
        lodsb
        cmp al,' '
        je help_skip
        cmp al,9
        je help_skip
        cmp al,13
        je help_absent
help_switch:
        cmp al,'/'
        jne help_token
        cmp byte ptr [si],'?'
        jne help_token
        mov ah,[si+1]
        cmp ah,13
        je help_found
        cmp ah,'/'
        je help_chained
        cmp ah,' '
        je help_boundary
        cmp ah,9
        je help_boundary
        jmp short help_token
help_chained:
        or dl,dl
        jnz help_absent
        jmp short help_found
help_boundary:
        or dl,dl
        jz help_found
        inc si
help_trailing:
        lodsb
        cmp al,' '
        je help_trailing
        cmp al,9
        je help_trailing
        cmp al,13
        jne help_absent
help_found:
        stc
        ret
help_token:
        or dl,dl
        jnz help_absent
help_token_loop:
        cmp al,'"'
        jne help_token_next
        xor ch,1
help_token_next:
        lodsb
        cmp al,13
        je help_absent
        or ch,ch
        jnz help_token_loop
        cmp al,' '
        je help_skip
        cmp al,'/'
        je help_switch
        cmp al,9
        jne help_token_loop
        jmp help_skip
help_absent:
        clc
        ret
help_argument endp
