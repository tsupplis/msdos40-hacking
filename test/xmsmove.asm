; XMS 0Bh integration probe. All transfers use private DOS or XMS buffers.
bits 16
cpu 286
org 100h

%macro xms 1
        mov ah,%1
        call far [cs:entry]
%endmacro
%macro eq 2
        cmp %1,%2
        jne failed
%endmacro
%macro transfer 1
        mov si,packet
        xms 0bh
%if %1
        eq ax,0
        eq bl,%1
%else
        eq ax,1
%endif
%endmacro
%macro length 1
        mov word [count],(%1) & 0ffffh
        mov word [count+2],(%1) >> 16
%endmacro
; Each endpoint is a handle plus byte offset, or a conventional far pointer.
%macro endpoint 3
        mov ax,%2
        mov [%1],ax
        mov word [%1+2],(%3)
        mov word [%1+4],0
%endmacro
%macro localbuf 2
        endpoint %1,0,%2
        mov [%1+4],cs
%endmacro
        mov ax,4310h
        int 2fh
        mov [entry],bx
        mov [entry+2],es
        mov ax,3515h
        int 21h
        mov [previous],bx
        mov [previous+2],es
        mov dx,firmware
        mov ax,2515h
        int 21h

        ; Use a nonperiodic pattern across chunk and segment boundaries.
        push cs
        pop es
        cld
        mov di,pattern
        mov cx,4099
        mov ax,0137h
.fill:  stosw
        rol ax,1
        add ax,cx
        loop .fill
        mov dx,80
        xms 9
        eq ax,1
        mov [first],dx
        mov dx,80
        xms 9
        eq ax,1
        mov [second],dx

        mov byte [step],1
        localbuf src,pattern
        endpoint dst,[first],0fffdh
        length 8196
        std                        ; callers need not enter with DF clear
        mov bx,5a00h
        mov cx,1234h
        mov dx,5678h
        mov di,789ah
        mov bp,2345h
        transfer 0
        eq bh,5ah
        eq cx,1234h
        eq dx,5678h
        eq si,packet
        eq di,789ah
        eq bp,2345h
        pushf
        pop ax
        cld
        test ax,400h
        jz failed
        ; Re-enter a successful transfer with a distinct descriptor table.
        mov byte [nested],1
        mov [inner_src_seg],cs
        mov [inner_dst_seg],cs
        endpoint src,[first],0fffdh
        endpoint dst,[second],7
        transfer 0
        eq byte [nested],0
        eq word [inner_result],0a55ah
        endpoint src,[second],7
        localbuf dst,readback
        transfer 0
        mov si,pattern
        mov di,readback
        mov cx,8196
        repe cmpsb
        jne failed

        ; An actual 32-bit length. Check distinct sentinels at both ends.
        mov byte [step],2
        localbuf src,pattern
        endpoint dst,[first],0
        length 2
        transfer 0
        localbuf src,pattern+6
        endpoint dst,[first],0
        mov word [dst+4],1
        transfer 0
        endpoint src,[first],0
        endpoint dst,[second],0
        length 10002h
        transfer 0
        endpoint src,[second],0
        localbuf dst,readback
        length 2
        transfer 0
        mov ax,[pattern]
        eq [readback],ax
        mov word [src+4],1
        transfer 0
        mov ax,[pattern+6]
        eq [readback],ax

        ; Compare against the original bytes, including one-byte overlap.
        mov byte [step],3
        localbuf src,pattern
        localbuf dst,readback
        length 8196
        transfer 0
        localbuf src,readback
        localbuf dst,readback+1
        transfer 0
        mov si,pattern
        mov di,readback+1
        mov cx,8196
        repe cmpsb
        jne failed
        localbuf src,readback+1
        localbuf dst,readback
        transfer 0
        mov si,pattern
        mov di,readback
        mov cx,8196
        repe cmpsb
        jne failed
        ; The same bytes through a different segment:offset pair.
        mov ax,cs
        dec ax
        mov [src+4],ax
        mov word [src+2],readback+16
        transfer 0

        ; A larger odd displacement uses direct, disjoint BIOS chunks.
        localbuf src,readback
        localbuf dst,readback+65
        length 8000
        transfer 0
        mov si,pattern
        mov di,readback+65
        mov cx,8000
        repe cmpsb
        jne failed

        mov byte [step],4
        endpoint src,0ffffh,0
        transfer 0a3h
        endpoint src,[first],0
        endpoint dst,0ffffh,0
        transfer 0a5h
        endpoint dst,[second],0
        mov word [src+4],0ffffh
        transfer 0a4h
        mov word [src+4],0
        mov word [dst+4],0ffffh
        transfer 0a6h
        mov word [dst+4],0
        length 1
        transfer 0a7h
        length 0fffffffeh
        transfer 0a7h
        length 4
        mov word [dst+4],1
        mov word [dst+2],16382
        transfer 0a7h
        length 0
        mov word [dst+2],16384    ; one past the last byte, zero-length move
        transfer 0
        localbuf dst,readback
        endpoint src,0,0ffffh
        mov word [src+4],0ffffh
        length 2
        transfer 0a7h

        ; During the BIOS call neither operand can be freed or resized.
        ; A failed firmware call must drop the private pins and preserve A20.
        mov byte [step],5
        endpoint src,[first],0
        endpoint dst,[second],0
        mov dx,[first]
        xms 0ch
        eq ax,1
        mov byte [inject],1
        xms 05h
        eq ax,1
        transfer 0a9h
        eq byte [inject],0
        xms 07h
        eq ax,1
        xms 06h
        eq ax,1
        mov dx,[first]
        xms 0eh
        eq bh,1
        mov dx,[first]
        xms 0dh
        eq ax,1
        mov byte [inject],3
        transfer 82h

        ; Fail the second BIOS operation. Completed bytes stay copied and
        ; the untouched tail plus both sentinels retain their original data.
        mov byte [step],6
        localbuf src,pattern
        localbuf dst,readback+1
        length 8196
        mov di,readback
        mov cx,8198
        mov al,0cch
        rep stosb
        mov byte [countdown],2
        transfer 8eh
        eq byte [readback],0cch
        mov si,pattern
        mov di,readback+1
        mov cx,4096
        repe cmpsb
        jne failed
        mov cx,4101
        mov al,0cch
        repe scasb
        jne failed
        mov dx,[first]
        xms 0ah
        eq ax,1
        mov dx,[second]
        xms 0ah
        eq ax,1
        mov al,10h
        jmp short done
failed: mov al,[cs:step]
        add al,20h
done:   out 0f4h,al
        int 20h

firmware:
        cmp ah,87h
        jne .chain
        cmp byte [cs:nested],0
        je .fault_test
        mov byte [cs:nested],0
        push bp
        mov bp,sp
        test word [bp+6],200h      ; outer caller allowed interrupts
        jz failed
        pop bp
        push ax
        push bx
        push si
        push ds
        push cs
        pop ds
        mov si,inner_packet
        xms 0bh
        eq ax,1
        pop ds
        pop si
        pop bx
        pop ax
        jmp short .chain
.fault_test:
        cmp byte [cs:countdown],0
        je .pin_test
        dec byte [cs:countdown]
        jnz .chain
        mov ah,2
        stc
        retf 2
.pin_test:
        cmp byte [cs:inject],0
        je .chain
        ; Enter through the public XMS API just as a TSR would.
        mov dx,[cs:second]
        xms 0ah
        eq ax,0
        eq bl,0abh
        mov dx,[cs:second]
        mov bx,1
        xms 0fh
        eq ax,0
        eq bl,0abh
        xor ah,ah
        xchg ah,[cs:inject]
        stc
        retf 2
.chain: jmp far [cs:previous]

entry dd 0
previous dd 0
packet:
count dd 0
src times 6 db 0
dst times 6 db 0
first dw 0
second dw 0
step db 0
inject db 0
countdown db 0
nested db 0
inner_packet: dd 2
        dw 0,inner_data
inner_src_seg dw 0
        dw 0,inner_result
inner_dst_seg dw 0
inner_data dw 0a55ah
inner_result dw 0
pattern times 8198 db 0
readback times 8198 db 0
