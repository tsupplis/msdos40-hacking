; IBM SBCS extension to function 0Ah. DI is the insertion point in INBUF,
; DH is the complete line length. DS:SI and BX still describe the caller's
; template. No history or additional line buffer is retained.
EditActive db 0
        i_need  BCON,DWORD
        i_need  ConSwap,BYTE

EditConsole:
        push    ds
        push    si
        push    bx
        push    dx
        mov     cs:EditActive,0
        mov     bx,1
EditHandle:
        invoke  GET_IO_SFT
        jc      EditChecked
        mov     ax,[si.sf_flags]
        and     ax,sf_isnet OR devid_device OR devid_device_raw
        cmp     ax,devid_device
        jne     EditChecked
        mov     ax,word ptr [si.sf_devptr]
        cmp     ax,word ptr [BCON]
        jne     EditChecked
        mov     ax,word ptr [si.sf_devptr+2]
        cmp     ax,word ptr [BCON+2]
        jne     EditChecked
        dec     bx
        jns     EditHandle
        mov     cs:EditActive,0ffh
EditChecked:
        pop     dx
        pop     bx
        pop     si
        pop     ds
        ret

EditKey:
        invoke  $STD_CON_INPUT_NO_ECHO
        cmp     al,4bh
        je      EditLeft
        cmp     al,4dh
        je      EditRight
        cmp     al,47h
        je      EditHome
        cmp     al,4fh
        je      EditEnd
        cmp     al,53h
        je      EditDelKey
        cmp     al,48h
        je      EditUp
        transfer OEMKeyCode             ; includes Ins, F1-F7 and ignored Down

EditLeft:
        cmp     di,offset DOSGROUP:INBUF
        je      EditNext
        mov     bp,di
        dec     bp
        jmp     short EditSeek
EditHome:
        mov     bp,offset DOSGROUP:INBUF
EditSeek:
        call    EditRetreat
EditNext:
        jmp     GETCH

EditRight:
        call    EditLimit
        cmp     di,bp
        je      EditNext
        call    EditStep
        jmp     short EditNext
EditEnd:
        call    EditFinish
        jmp     short EditNext
EditDelKey:
        jmp     EditDelete
EditUp:
        or      dh,dh
        jnz     EditNext
        cmp     byte ptr [ConSwap],0    ; cooked handle reads use shared CONBUF
        jne     EditNext
        xor     ax,ax
        mov     al,bh
        sub     si,ax                   ; rewind even after F4 or Delete
        xor     bh,bh
        mov     cl,bl
        jcxz    EditNext
EditRecall:
        lodsb
        stosb
        invoke  BUFOUT
        inc     dh
        inc     bh
        loop    EditRecall
        jmp     short EditNext

EditLimit:
        xor     ax,ax
        mov     al,dh
        add     ax,offset DOSGROUP:INBUF
        mov     bp,ax
        ret
EditStep:
        mov     al,es:[di]
        inc     di
        invoke  BUFOUT
        ret
EditFinish:
        cmp     cs:EditActive,0
        je      EditAtEnd
        call    EditLimit
EditToEnd:
        cmp     di,bp
        jae     EditAtEnd
        call    EditStep
        jmp     short EditToEnd
EditAtEnd:
        ret

; Measure the prefix ending at DI. AX counts physical cells, CL follows
; DOS CARPOS (Ctrl-T, Ctrl-U and DEL are displayed without advancing it).
EditWidth:
        push    si
        mov     si,offset DOSGROUP:INBUF
        mov     cl,[STARTPOS]
        xor     ax,ax
WidthLoop:
        cmp     si,di
        jae     WidthDone
        mov     ch,es:[si]
        inc     si
        cmp     ch,c_HT
        jne     WidthChar
        mov     ch,cl
        and     ch,7
        sub     cl,ch
        add     cl,8
        add     ax,8
        sub     al,ch
        sbb     ah,0
        jmp     short WidthLoop
WidthChar:
        inc     ax
        cmp     ch,7fh
        je      WidthLoop
        cmp     ch,14h
        je      WidthLoop
        cmp     ch,15h
        je      WidthLoop
        inc     cl
        cmp     ch,' '
        jae     WidthLoop
        inc     ax
        inc     cl
        jmp     short WidthLoop
WidthDone:
        xor     ch,ch
        pop     si
        ret

; Seek backwards from DI to BP, keeping the prompt and logical tab stops.
EditRetreat:
        push    cx
        call    EditWidth
        push    ax
        mov     di,bp
        call    EditWidth
        mov     [CARPOS],cl
        pop     cx
        sub     cx,ax
        jcxz    RetreatDone
        invoke  OEMBackCells
RetreatDone:
        pop     cx
        ret

EditBack:
        cmp     di,offset DOSGROUP:INBUF
        je      EditDone
        mov     bp,di
        dec     bp
        call    EditRetreat
EditDelete:
        call    EditLimit
        cmp     di,bp
        je      EditDone
        call    EditOldWidth
        push    ax                      ; old screen extent
        push    di                      ; cursor after deletion
DeleteShift:
        inc     di
        cmp     di,bp
        jae     DeletePaint
        mov     al,es:[di]
        mov     es:[di-1],al
        jmp     short DeleteShift
DeletePaint:
        dec     dh
        pop     di
        mov     bp,di
        pop     ax
        call    EditPaint
EditDone:
        jmp     GETCH

; Store AL. Carry means capacity exhausted. Fast path echoes an append once.
EditPut:
        push    ax
        call    EditLimit
        cmp     di,bp
        pop     ax
        jb      EditMiddle
        cmp     dh,dl
        jae     EditFull
        stosb
        inc     dh
        invoke  BUFOUT
        clc
        ret
EditFull:
        stc
        ret
EditMiddle:
        push    ax
        call    EditOldWidth
        xchg    bp,ax                   ; BP = old extent, AX = end pointer
        cmp     byte ptr [INSMODE],0
        je      EditReplace
        cmp     dh,dl
        jb      EditRoom
        pop     ax
        jmp     short EditFull
EditRoom:
        inc     dh
        push    bx
        mov     bx,ax
InsertShift:
        mov     al,es:[bx-1]
        mov     es:[bx],al
        dec     bx
        cmp     bx,di
        ja      InsertShift
        pop     bx
EditReplace:
        pop     ax
        mov     es:[di],al
        mov     ax,bp
        mov     bp,di
        inc     bp                      ; cursor after inserted/replaced byte
        call    EditPaint
        clc
        ret

; BP = old end pointer. Preserve the editor and template-copy loop registers.
EditOldWidth:
        push    di
        push    cx
        mov     di,bp
        call    EditWidth
        pop     cx
        pop     di
        ret

; Physical cursor is at DI, before the changed suffix. Prefix is unchanged.
; AX = old extent, BP = desired cursor. Repaint suffix and erase stale cells.
EditPaint:
        push    cx
        push    bp
        push    ax
        call    EditFinish
        call    EditWidth
        pop     cx
        sub     cx,ax
        jbe     PaintSeek
        push    cx
        push    word ptr [CARPOS]
PaintErase:
        mov     al,' '
        invoke  OUTT
        loop    PaintErase
        pop     ax
        mov     [CARPOS],al
        pop     cx
        invoke  OEMBackCells
PaintSeek:
        pop     bp
        call    EditRetreat
        pop     cx
        ret
