; QEMU-specific AT fixture. Seed the gate through the BIOS before using XMS.
; An independent alias check at 1 MiB + 504h verifies the physical result.
bits 16
cpu 286
org 100h
%ifdef POST_BUSY
%define TRACE_KBC
%elifdef LATE_KBC
%define TRACE_KBC
%endif
        mov ax,4310h
        int 2fh
        mov [entry],bx
        mov [entry+2],es
        mov byte [step],1
%ifdef BUSY_KBC
        ; Force an edge on the independent fast-A20 latch.
        in al,92h
        and al,0feh
        or al,2
        out 92h,al
        and al,0fdh
        out 92h,al
%else
        mov ax,2400h
        int 15h
        jc failed
%endif

%macro state 1
        inc byte [step]
        call physical
        cmp ax,%1
        jne failed
        inc byte [step]
        mov ah,07h
        mov bl,0ffh
        call far [entry]
        cmp ax,%1
        jne failed
        test bl,bl
        jnz failed
%endmacro
%macro request 1
        inc byte [step]
        mov ah,%1
        call far [entry]
        cmp ax,1
        jne failed
%endmacro
%macro error 2
        inc byte [step]
        mov ah,%1
        call far [entry]
        test ax,ax
        jnz failed
        cmp bl,%2
        jne failed
%endmacro
        state 0
%ifdef TRACE_KBC
        ; Trace the native I/O instructions. LATE_KBC expires the first
        ; wait after D1h. POST_BUSY forces busy reads after the data write.
        mov ax,3501h
        int 21h
        mov [old_trace],bx
        mov [old_trace+2],es
        mov dx,trace_io
        mov ax,2501h
        int 21h
        pushf
        cli
        pushf
        pop ax
        or ah,1
        push ax
        popf
        mov ah,05h
        call far [entry]
        popf                      ; restore FLAGS and stop tracing
        push ax
        push ds
        lds dx,[old_trace]
        mov ax,2501h
        int 21h
        pop ds
        pop ax
        cmp ax,1
        jne failed
        cmp byte [data_sent],1
        jne failed
        state 1
        request 06h               ; ownership was recorded and is releasable
        state 0
%elifdef BUSY_KBC
        error 05h,82h
        state 0
        error 06h,82h             ; failed acquisition took no reference
%else
        error 06h,82h             ; unmatched release
        request 03h
        request 03h
        state 1
        error 06h,82h             ; local release cannot consume global hold
        request 04h
        state 0
        request 04h
        request 05h
        request 05h
        request 03h
        request 06h
        state 1
        error 04h,94h             ; remaining local owner still needs A20
        state 1
        request 06h
        state 0
        mov ax,2401h              ; simulate a prior owner
        int 15h
        jc failed
        state 1
        request 05h
        request 06h
        state 1
%endif
        mov al,16
        jmp short done
failed: mov al,[step]
        add al,20h
done:   out 0f4h,al
        int 20h

%ifdef TRACE_KBC
trace_io:
        push bp
        mov bp,sp
        push ds
        push bx
        mov ds,[bp+4]
        mov bx,ds
        cmp bx,[cs:entry+2]
        jne .done
        mov bx,[bp+2]             ; CS:IP of the next instruction
%ifdef LATE_KBC
        cmp word [bx],064e6h      ; OUT 64h,AL
        jne .wait
        mov byte [cs:expire_wait],1
.wait:  cmp byte [cs:expire_wait],1
        jne .data
        cmp word [bx],064e4h      ; IN AL,64h
        jne .done
        mov byte [cs:expire_wait],0
        mov cx,1                  ; final busy sample of this wait
        mov al,2
        add word [bp+2],2
        jmp short .done
.data:
%endif
        cmp word [bx],060e6h      ; OUT 60h,AL
        jne .status
        mov byte [cs:data_sent],1
.status:
%ifdef POST_BUSY
        cmp byte [cs:data_sent],0
        je .done
        cmp word [bx],064e4h      ; IN AL,64h
        jne .done
        mov al,2
        add word [bp+2],2
%endif
.done:  pop bx
        pop ds
        pop bp
        iret
old_trace dd 0
data_sent db 0
%ifdef LATE_KBC
expire_wait db 0
%endif
%endif

physical:
        pushf
        cli
        push ds
        push es
        xor ax,ax
        mov ds,ax
        dec ax
        mov es,ax
        mov dl,[504h]
        mov byte [504h],0
        mov al,[es:514h]
        mov byte [504h],1
        cmp al,[es:514h]
        mov [504h],dl
        mov ax,0
        jne .done
        inc ax
.done:  pop es
        pop ds
        popf
        ret
step db 0
entry dd 0
