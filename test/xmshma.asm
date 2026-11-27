; Native HIMEM boot probe. The mode is the first command-line argument.
; QEMU's exit device reports the numbered assertion that failed.
bits 16
cpu 286
org 100h

%macro expect 2
        inc byte [step]
        cmp %1,%2
        jne failed
%endmacro

%macro xms 1
        mov ah,%1
        call far [entry]
%endmacro

        mov ax,4310h
        int 2fh
        mov [entry],bx
        mov [entry+2],es
        mov al,[82h]
        cmp al,'h'
        je high
        cmp al,'l'
        je low
        cmp al,'v'
        je vdisk
        cmp al,'p'
        je pool_before_vdisk
        cmp al,'i'
        je vector_signature
        cmp al,'r'
        je ramdrive
        cmp al,'m'
        je no_memory
        jmp failed

; COMMAND gives a COM program the largest conventional block. Report the
; PSP block size in paragraphs for identical low/high boots.
report_size:
        mov ax,[2]
        mov dx,cs
        sub ax,dx
        out 0e9h,al
        mov al,ah
        out 0e9h,al
        ret

high:
        call report_size
        mov ax,58feh              ; kernel's FCB body residency query
        int 21h
        jc failed
        expect ax,1
        mov dx,0ffffh
        xms 1                     ; DOS must still own its HMA
        expect ax,0
        expect bl,91h
        jmp passed

low:
        call report_size
        mov ax,58feh
        int 21h
        jc failed
        expect ax,0
        mov ax,3515h
        int 21h
        mov [previous],bx
        mov [previous+2],es
        mov dx,bios_hook
        mov ax,2515h
        int 21h
        xms 0
        expect dx,1
        mov ah,88h                ; version alone must leave BIOS RAM visible
        int 15h
        jc failed
        cmp ax,64
        jb failed
        ; Local A20 must survive a BIOS move before the pool is reserved.
        mov ax,2400h
        int 15h
        xms 5
        expect ax,1
        mov word [switch_gate],2400h
        mov ah,87h
        int 15h
        jnc failed
        expect ax,4567h
        xms 7
        expect ax,1
        xms 6
        expect ax,1
        mov word [switch_gate],2401h
        xms 2
        expect ax,0
        expect bl,93h
        xor dx,dx                 ; zero minimum, HMA is one indivisible block
        xms 1
        expect ax,1
        mov ah,88h
        stc
        int 15h
        jc failed
        expect ax,0
        mov dx,0ffffh
        xms 1
        expect ax,0
        expect bl,91h
        xms 2
        expect ax,1
        xms 1
        expect ax,1
        xms 2
        expect ax,1

; The chained move deliberately changes A20 and returns distinct register
; and carry results. HIMEM must restore the gate on success and failure.
        mov ax,2400h
        int 15h
        xms 7
        expect ax,0
        mov ah,87h
        int 15h
        jc failed
        expect ax,1234h
        xms 7
        expect ax,0
        xms 5
        expect ax,1
        mov word [switch_gate],2400h
        mov ah,87h
        int 15h
        jnc failed
        expect ax,4567h
        xms 7
        expect ax,1
        xms 6
        expect ax,1
        ; An interrupt client pairs its local enable/disable before returning
        ; to the BIOS. Exercise both an idle gate and an existing XMS hold.
        mov word [switch_gate],0
        mov ah,87h
        int 15h
        jc failed
        xms 7
        expect ax,0
        xms 6
        expect ax,0
        expect bl,82h
        xms 5
        expect ax,1
        mov ah,87h
        int 15h
        jc failed
        xms 7
        expect ax,1
        xms 6
        expect ax,1
        xms 7
        expect ax,0
        jmp passed

bios_hook:
        cmp ah,87h
        jne .chain
        cmp word [cs:switch_gate],0
        je .balanced
        cmp word [cs:switch_gate],2400h
        je .move_error
        mov ax,2401h
        int 15h
        xor bp,bp                 ; chained firmware can use BP as scratch
        mov ax,1234h
        clc
        retf 2
.move_error:
        ; Force an edge on the QEMU fast gate even if the KBC enabled A20.
        in al,92h
        and al,0feh
        or al,2
        out 92h,al
        and al,0fdh
        out 92h,al
        mov ax,4567h
        stc
        retf 2
.chain: jmp far [cs:previous]
.balanced:
        xms 5
        expect ax,1
        xms 7
        expect ax,1
        xms 6
        expect ax,1
        clc
        retf 2

; Simulate a legacy user appearing between discovery and the first grant.
; These writes are confined to disposable guest RAM.
pool_before_vdisk:
        xms 8
        test ax,ax
        jz failed
        mov dx,1
        xms 9
        expect ax,1
        mov [block],dx
        xms 0ch
        expect ax,1
vector_signature:
        ; Point INT 19h at a scratch segment with the legacy marker at 12h.
        ; The test exits through QEMU without bootstrapping through INT 19h.
        xms 0
        expect dx,1
        mov sp,1000h
        mov ah,4ah
        push cs
        pop es
        mov bx,100h
        int 21h
        jc failed
        mov bx,4
        mov ah,48h
        int 21h
        jc failed
        mov es,ax
        mov di,12h
        mov si,vdisk_name
        mov cx,5
        cld
        rep movsb
        push ds
        mov ds,ax
        xor dx,dx
        mov ax,2519h
        int 21h
        pop ds
        jmp check_conflict
vdisk:
        mov si,vdisk_name
        mov di,13h
        mov cx,5
        jmp short legacy
ramdrive:
        mov si,ramdrive_name
        mov di,10h
        mov cx,ramdrive_end-ramdrive_name
legacy:
        xms 0
        expect dx,1
        xms 5
        expect ax,1
        mov ax,0ffffh
        mov es,ax
        cld
        rep movsb
        xms 6
        expect ax,1
check_conflict:
        mov ax,2400h
        int 15h
        jc failed
        xms 3
        expect ax,1
        xms 5
        expect ax,1
        xms 1
        expect ax,0
        expect bl,81h
        xms 3
        expect ax,0
        expect bl,81h
        xms 5
        expect ax,0
        expect bl,81h
        xms 7
        expect ax,0
        expect bl,81h
        xms 6
        expect ax,1
        xms 4
        expect ax,1
        xms 6
        expect ax,0
        expect bl,81h
        xms 8
        expect ax,0
        expect dx,0
        expect bl,81h
        mov dx,1
        xms 9
        expect ax,0
        expect dx,0
        expect bl,81h
        xms 0
        expect dx,0
        mov dx,[block]
        or dx,dx
        jz bios_unclaimed
        xms 0eh                   ; prior handles can still be cleaned up
        expect ax,1
        expect bh,1
        mov dx,[block]
        xms 0dh
        expect ax,1
        xms 0ah
        expect ax,1
        mov ah,88h                ; the reserved pool stays hidden from BIOS
        int 15h
        jc failed
        expect ax,0
        jmp passed
bios_unclaimed:
        mov ah,88h
        int 15h
        jc failed
        cmp ax,64
        jb failed
        jmp passed

no_memory:
        xms 0
        expect dx,0
        xms 1
        expect ax,0
        expect bl,90h
        mov ax,58feh
        int 21h
        jc failed
        expect ax,0
passed:
        mov al,10h
        jmp short done
failed:
        mov al,[step]
        add al,20h
done:
        out 0f4h,al
        int 20h
step db 0
entry dd 0
block dw 0
previous dd 0
switch_gate dw 2401h
vdisk_name db 'VDISK'
ramdrive_name db 'MICROSOFT EMM CTRL VERSION 1.00 CONTROL BLOCK     '
ramdrive_end:
