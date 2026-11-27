; Exercise the XMS block API through the installed far entry. The small
; pool case supplies a 32 KiB BIOS range before the driver's first claim.
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
%macro ok 1
        xms %1
        eq ax,1
%endmacro
%macro err 2
        xms %1
        eq ax,0
        eq bl,%2
%endmacro
%macro allocate 2
        mov dx,%1
        ok 9
        mov [%2],dx
%endmacro

        mov ax,4310h
        int 2fh
        mov [entry],bx
        mov [entry+2],es
        cmp byte [82h],'s'
        je small_pool
        cmp byte [82h],'c'
        je address_ceiling
        cmp byte [82h],'z'
        je no_pool

        ; An installed character driver must reject repeated INIT. Its
        ; initialization tail was returned to DOS at CONFIG.SYS time.
        mov ax,[es:6]
        mov [strategy],ax
        mov ax,[es:8]
        mov [device],ax
        mov [strategy+2],es
        mov [device+2],es
        push cs
        pop es
        mov bx,packet
        call far [strategy]
        call far [device]
        eq word [packet+3],8103h

        xms 8
        cmp dx,128
        jb failed
        eq ax,dx
        eq bl,0
        mov [total],dx
        ; A block-first claim leaves the HMA free. DOS=HIGH already owns it.
        mov dx,0ffffh
        cmp byte [82h],'h'
        je .owned
        ok 1
        ok 2
        jmp short .fragment
.owned: err 1,91h
.fragment:
        mov byte [step],2
        allocate 16,first
        allocate 24,middle
        allocate 8,last
        xms 8
        mov cx,[total]
        sub cx,48
        eq dx,cx
        eq ax,cx
        mov dx,[middle]
        ok 0ah
        xms 8
        eq ax,cx                 ; largest tail, plus a 24 KiB hole
        add cx,24
        eq dx,cx
        allocate 20,middle
        ; Read the ten-byte handle records that MEM uses for its totals.
        mov ax,4309h
        int 2fh
        eq al,43h
        eq word [es:bx],0a01h
        eq word [es:bx+2],16
        mov si,[es:bx+4]
        mov es,[es:bx+6]
        mov cx,16
        xor dx,dx
.records:
        cmp byte [es:si],2
        jne .next
        eq word [es:si+8],0
        add dx,[es:si+6]
.next:  add si,10
        loop .records
        eq dx,44
        mov byte [step],3
        mov dx,[first]
        ok 0ch
        eq dx,11h                ; starts immediately above the reserved HMA
        eq bx,0
        mov dx,[middle]
        ok 0ch
        eq dx,11h
        eq bx,4000h              ; reused the hole at 16 KiB
        mov dx,[middle]
        err 0ah,0abh
        mov bx,1
        err 0fh,0abh
        ok 0dh
        err 0dh,0aah
        mov bx,25
        err 0fh,0a0h             ; the following block prevents growth
        ok 0eh
        eq dx,20
        eq bh,0
        eq bl,13
        mov dx,[middle]
        mov bx,24
        ok 0fh
        mov bx,12
        ok 0fh
        mov bx,0ffffh
        err 0fh,0a0h
        ok 0eh
        eq dx,12

        ; Exercise the real BIOS transfer interface against a locked block.
        ; Keep distinct source and destination buffers in conventional RAM.
        mov byte [step],4
        mov dx,[first]
        ok 0dh
        ok 0ch
        push cs
        pop es
        mov [dest_desc+2],bx
        mov [dest_desc+4],dl
        mov si,src_desc
        mov bx,pattern
        call conventional
        call bios_copy
        mov si,dest_desc
        mov bx,readback
        call conventional
        mov word [src_desc+2],0
        mov byte [src_desc+4],11h
        call bios_copy
        mov ax,[pattern]
        eq word [readback],ax
        mov dx,[first]
        ok 0dh

        mov byte [step],5
        mov dx,[last]
        ok 0ah
        err 0ah,0a2h
        mov dx,[middle]
        inc dx                   ; reject interior and out-of-range handles
        err 0ch,0a2h
        xor dx,dx
        err 0eh,0a2h
        mov dx,[middle]
        mov bx,0
        ok 0fh
        mov bx,32
        ok 0fh
        ok 0ah
        mov dx,[first]
        ok 0ah
        xms 8
        eq ax,[total]
        eq dx,ax

        ; All 16 zero-length handles are independent of address space.
        mov byte [step],6
        mov di,handles
        mov cx,16
.fill:  xor dx,dx
        ok 9
        mov [di],dx
        add di,2
        loop .fill
        xms 8                     ; no fresh handle, all physical KiB free
        eq ax,0
        eq dx,[total]
        eq bl,0
        mov dx,1
        err 9,0a1h
        eq dx,0
        mov dx,[handles]
        ok 0eh
        eq bx,0
        eq dx,0
        mov dx,[handles]
        mov bx,[total]
        ok 0fh
        xms 8
        eq ax,0
        eq dx,0
        eq bl,0a0h
        mov di,handles
        mov cx,16
.empty: mov dx,[di]
        ok 0ah
        add di,2
        loop .empty

        mov byte [step],7
        allocate 1,first
        mov cx,255
.lock:  mov dx,[first]
        ok 0ch
        loop .lock
        mov dx,[first]
        err 0ch,0ach
        ok 0eh
        eq bh,255
        mov dx,[first]
        mov cx,255
.unlock:
        ok 0dh
        loop .unlock
        ok 0ah
        mov dx,0ffffh
        err 9,0a0h
        eq dx,0
        xms 8
        eq ax,[total]
        eq dx,ax
        jmp passed

; Set a 24-bit physical base for a conventional CS:BX buffer descriptor.
conventional:
        mov ax,cs
        mov dx,16
        mul dx
        add ax,bx
        adc dl,0
        mov [si+2],ax
        mov [si+4],dl
        ret
bios_copy:
        mov si,gdt
        mov cx,1
        mov ah,87h
        int 15h
        jc failed
        ret

address_ceiling:
        mov byte [step],10
        xms 8
        eq ax,16384-1088          ; 32 MiB machine, 24-bit driver limit
        eq dx,ax
        allocate 16384-1088-1,first
        allocate 1,last
        ok 0ch
        eq dx,00ffh               ; final KiB ends at physical 00FFFFFFh
        eq bx,0fc00h
        mov dx,[last]
        ok 0dh
        ; Round-trip the last aligned word below the 24-bit ceiling.
        mov [top_write+10],dx
        mov [top_read+4],dx
        mov [top_write+8],cs
        mov [top_read+14],cs
        mov si,top_write
        ok 0bh
        mov si,top_read
        ok 0bh
        mov ax,[pattern]
        eq [readback],ax
        ok 0ah
        mov dx,[first]
        ok 0ah
        jmp passed

no_pool:
        mov byte [step],9
        xms 8
        eq ax,0
        eq dx,0
        eq bl,0a0h
        allocate 0,first
        mov bx,1
        err 0fh,0a0h
        ok 0eh
        eq dx,0
        mov dx,[first]
        ok 0ah
        mov dx,1
        err 9,0a0h
        eq dx,0
        jmp passed

small_pool:
        mov byte [step],8
        mov ax,3515h
        int 21h
        mov [previous],bx
        mov [previous+2],es
        mov dx,small_bios
        mov ax,2515h
        int 21h
        xms 0
        eq dx,0
        xms 8
        eq ax,32
        eq dx,32
        err 1,90h
        allocate 32,first
        ok 0ch
        eq dx,10h
        eq bx,0
passed: mov al,10h
        jmp short done
failed: mov al,[cs:step]
        add al,20h
done:   out 0f4h,al
        int 20h
small_bios:
        cmp ah,88h
        jne .chain
        ; Firmware re-enters before our outer memory query has completed.
        push bx
        push dx
        xor dx,dx
        err 9,82h
        eq dx,0
        pop dx
        pop bx
        mov ax,32
        clc
        retf 2
.chain: jmp far [cs:previous]

top_write: dd 2
        dw 0,pattern,0,0,1022,0
top_read: dd 2
        dw 0,1022,0,0,readback,0
step db 1
entry dd 0
device dd 0
strategy dd 0
previous dd 0
packet db 22,0,0
       times 19 db 0
total dw 0
first dw 0
middle dw 0
last dw 0
handles times 16 dw 0
pattern dw 0a53ch
readback dw 0
align 2
gdt times 16 db 0
src_desc  dw 0ffffh,0,9300h,0
dest_desc dw 0ffffh,0,9300h,0
          times 16 db 0
