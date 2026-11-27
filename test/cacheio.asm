; QEMU probe for SMARTDRV on a disposable 63-sector/track IDE disk.
; Check XMS/EMS selection, read two tracks, write the first and read it back.
bits 16
cpu 8086
org 100h
        cld
        mov si,81h
.skip:  lodsb
        cmp al,' '
        je .skip
        mov [mode],al
        cmp al,'h'
        je pool
        cmp al,'p'
        je passed
        cmp al,'f'
        je failed
        cmp al,'r'
        je ram_absent
        mov ax,3d00h
        mov dx,device
        int 21h
        jc no_cache
        cmp byte [mode],'n'
        je failed
        mov bx,ax
        mov ax,4402h
        mov cx,40
        mov dx,status
        int 21h
        jc failed
        cmp ax,40
        jne failed
        cmp word [status+2],1
        jne failed
        cmp word [status+26],4          ; four full tracks in 128 KiB
        jne failed
        cmp byte [mode],'e'
        je .ems
        cmp word [status+34],0
        jne failed
        jmp short .data
.ems:   cmp word [status+34],8          ; current 16 KiB EMS pages
        jne failed
.data:  mov bx,buffer
        mov ax,ds
        mov cl,4
        shl ax,cl
        add ax,bx
        cmp ax,0fe00h
        jbe .aligned
        add bx,512
.aligned:
        xor dh,dh
        mov ah,2
        call sector
        mov al,35h
        call verify
        mov dh,1
        mov ah,2
        call sector
        mov al,76h
        call verify
        cmp byte [mode],'t'
        jne .reread
        int 61h
        mov [reads],ax
.reread:
        xor dh,dh
        mov ah,2
        call sector
        mov al,35h
        call verify
        cmp byte [mode],'t'
        jne .write
        int 61h
        cmp ax,[reads]                   ; cache hit after reading another track
        jne failed
.write: mov di,bx
        mov al,0a7h
        mov cx,512
        rep stosb
        mov ah,3
        call sector
        mov di,bx
        xor ax,ax
        mov cx,256
        rep stosw
        mov ah,2
        call sector
        mov al,0a7h
        call verify
passed: mov al,10h
        jmp short quit
no_cache:
        cmp byte [mode],'n'
        je passed
failed: mov al,20h
quit:   out 0f4h,al
        int 20h

; cacheio h verifies the drop in free XMS, in units of 128 KiB.
pool:   inc si
        mov al,[si]
        sub al,'0'
        mov ah,128
        mul ah
        push ax
        int 60h
        push ax
        mov [entry],bx
        mov [entry+2],es
        mov ah,08h
        call far [entry]
        pop ax
        sub ax,dx
        pop cx
        cmp ax,cx
        jne failed
        mov ax,4c00h
        int 21h

ram_absent:
        mov dl,3                       ; no IDE disk in RAMDRIVE tests
        mov ah,36h
        int 21h
        cmp ax,0ffffh
        je passed
        jmp failed

sector: mov cx,2                       ; cylinder 0, sector 2, selected head
        mov dl,80h
        mov al,1
        int 13h
        jc failed
        ret
verify: mov di,bx
        mov cx,512
        repe scasb
        jne failed
        ret
device db 'SMARTAAR',0
mode db 0
reads dw 0
status times 40 db 0
entry dd 0
buffer times 1024 db 0
