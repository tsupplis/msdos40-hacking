; Exercise allocation, extended-open action codes and canonical paths on B:.
bits 16
cpu 8086
org 100h
    ; A child invocation exercises each legacy termination interface.
    cmp byte [80h],1
    jne parent
    mov al,[81h]
    cmp al,'0'
    jne try_int20
    xor ah,ah
    int 21h
try_int20:
    cmp al,'1'
    jne try_keep
    int 20h
try_keep:
    cmp al,'2'
    jne try_int27
    mov dx,20h
    mov ax,315ah
    int 21h
try_int27:
    mov dx,1f1h
    int 27h
parent:
    mov sp,stacktop
    mov bx,(stacktop-$$+100h+15)/16
    mov ah,4ah
    int 21h
    jc fail
    call check_drive_mapping
    ; GETSET must preserve a caller-owned DTA and return the original vector.
    mov dx,pathname
    mov ah,1ah
    int 21h
    mov ah,2fh
    int 21h
    cmp bx,pathname
    jne fail
    mov ax,es
    push ds
    pop bx
    cmp ax,bx
    jne fail
    mov dx,80h
    mov ah,1ah
    int 21h
    mov ax,3560h
    int 21h
    push es
    push bx
    mov dx,vector_handler
    mov ax,2560h
    int 21h
    mov ax,3560h
    int 21h
    cmp bx,vector_handler
    jne vector_wrong
    mov ax,es
    mov bx,cs
    cmp ax,bx
vector_wrong:
    pop dx
    pop ax
    pushf
    push ds
    mov ds,ax
    mov ax,2560h
    int 21h
    pop ds
    popf
    jne fail
    mov ah,54h
    int 21h
    push ax
    xor al,1
    xor dx,dx
    mov ah,2eh
    int 21h
    mov ah,54h
    int 21h
    pop bx
    xor al,1
    cmp al,bl
    pushf
    push bx
    mov al,bl
    mov ah,2eh
    int 21h
    mov ah,54h
    int 21h
    pop bx
    popf
    jne fail
    cmp al,bl
    jne fail
    mov bx,8
    mov ah,48h
    int 21h
    jc fail
    mov es,ax
    mov bx,4
    mov ah,4ah
    int 21h
    jc fail
    mov bx,0ffffh               ; failed growth returns the maximum in BX
    mov ah,4ah
    int 21h
    jnc fail
    cmp ax,8
    jne fail
    cmp bx,4
    jb fail
    cmp bx,0ffffh
    je fail
    mov ah,49h
    int 21h
    jc fail
    mov bx,0ffffh
    mov ah,48h
    int 21h
    jnc fail
    cmp ax,8
    jne fail
    mov dx,directory
    mov ah,39h
    int 21h
    jc fail
    mov ah,3bh                  ; change B:'s directory while A: is default
    mov dx,directory
    int 21h
    jc fail
    mov dl,2
    mov si,current_path
    mov ah,47h
    int 21h
    jc fail
    push ds
    pop es
    mov si,current_path
    mov di,directory+3          ; DOS returns SVCDIR without drive or slash
    mov cx,7                    ; include the terminating zero
    repe cmpsb
    jne fail
    mov dx,directory
    mov ah,3ah                  ; cannot remove a drive's current directory
    int 21h
    jnc fail
    cmp ax,16
    jne fail
    mov dx,broot
    mov ah,3bh
    int 21h
    jc fail
    ; Renaming a directory exercises RENAME's shared PATH length check.
    push ds
    pop es
    mov dx,directory
    mov di,renamed_dir
    mov ah,56h
    int 21h
    jc fail
    mov dx,renamed_dir
    mov di,directory
    mov ah,56h
    int 21h
    jc fail
    mov dx,10h                  ; create a missing file
    call xopen
    jc fail
    cmp cx,2
    jne fail
    mov bx,ax
    call check_handles
    mov ax,bx
    call close
    mov dx,1                    ; open an existing file
    call xopen
    jc fail
    cmp cx,1
    jne fail
    call close
    mov dx,2                    ; replace an existing file
    call xopen
    jc fail
    cmp cx,3
    jne fail
    call close
    mov dx,flatname
    mov ah,41h
    int 21h
    jc fail
    mov dx,1
    call xopen
    jnc fail
    cmp ax,2
    jne fail
    mov dl,2                    ; freshly formatted B: has 512-byte sectors
    mov ah,36h
    int 21h
    cmp cx,512
    jne fail
    or ax,ax
    jz fail
    cmp bx,dx
    ja fail
    mov dx,flatname
    xor cx,cx
    mov ah,5bh
    int 21h
    jc fail
    call close
    mov dx,flatname
    xor cx,cx
    mov ah,5bh
    int 21h
    jnc fail
    cmp ax,80
    jne fail
    mov dx,flatname
    mov cx,1                    ; set and read back the read-only attribute
    mov ax,4301h
    int 21h
    jc fail
    mov ax,4300h
    int 21h
    jc fail
    test cx,1
    jz fail
    xor cx,cx
    mov ax,4301h
    int 21h
    jc fail
    mov dx,flatname
    mov ah,41h
    int 21h
    jc fail
    ; Load an MZ overlay and verify every relocated word in the owned block.
    mov bx,16
    mov ah,48h
    int 21h
    jc fail
    mov [overlay_block],ax
    mov [overlay_block+2],ax
    push ds
    pop es
    mov bx,overlay_block
    mov dx,overlay_name
    mov ax,4b03h
    int 21h
    jc fail
    mov es,[overlay_block]
    mov ax,es
    xor di,di
    mov cx,128
check_relocation:
    cmp ax,[es:di]
    jne fail
    inc ax
    add di,2
    loop check_relocation
    mov ah,49h
    int 21h
    jc fail
    push cs
    pop es
    mov dx,child_name
    mov bx,child_block
    mov ax,4b02h
    int 21h
    jnc fail
    cmp ax,1
    jne fail
    mov dx,missing_name
    mov ax,4b00h
    int 21h
    jnc fail
    cmp ax,2
    jne fail
    mov [child_block+4],cs
    mov [child_block+8],cs
    mov [child_block+12],cs
    mov [saved_sp],sp
    mov ax,4b00h
run_child:
    mov dx,child_name
    mov bx,child_block
    int 21h
    cli
    mov bx,cs
    mov ss,bx
    mov sp,[cs:saved_sp]
    sti
    mov ds,bx
    mov es,bx
    jc fail
    cmp byte [child_stage],1
    jne child_exit
    ; Load-only returned the MZ entry and initial stack in the parameter block.
    cmp word [child_block+18],0
    jne fail
    cmp word [child_block+14],0feh
    jne fail
    mov ax,[child_block+20]
    cmp ax,[child_block+16]
    jne fail
    inc byte [child_stage]
    cli
    mov ss,ax
    mov sp,[child_block+14]
    sti
    pop ax
    jmp far [child_block+18]
child_exit:
    mov ah,4dh
    int 21h
    cmp ax,37h
    jne fail
    cmp byte [child_stage],2
    je children_done
    inc byte [child_stage]
    mov ax,4b01h
    jmp run_child
children_done:
    mov word [child_block+2],tail
legacy_child:
    mov dx,self_name
    mov bx,child_block
    mov ax,4b00h
    int 21h
    cli
    mov bx,cs
    mov ss,bx
    mov sp,[cs:saved_sp]
    sti
    mov ds,bx
    mov es,bx
    jc fail
    mov ah,4dh
    int 21h
    xor bx,bx
    mov bl,[tail+1]
    sub bl,'0'
    shl bx,1
    cmp ax,[status+bx]
    jne fail
    mov ah,4dh
    int 21h
    or ax,ax
    jnz fail
    inc byte [tail+1]
    cmp byte [tail+1],'3'
    jbe legacy_child
    mov dx,okmsg
    mov ah,9
    int 21h
    mov ax,4c00h
    int 21h
vector_handler:
    iret
fail:
    mov ax,4c01h
    int 21h
; Multiplex drive services keep the application stack. The dispatcher takes
; the caller's AX from the word pushed before INT 2Fh.
check_drive_mapping:
    push ds
    mov ax,1                    ; zero-based B: -> DS:SI CDS
    push ax
    mov ax,1217h
    int 2fh
    pop bx
    jc fail
    cmp word [si],'B:'
    jne fail
    mov bx,ds
    mov dx,si
    pop ds
    mov ax,'B'                  ; reset the selected scratch drive to its root
    push ax
    mov ax,121fh
    int 2fh
    pop ax
    jc fail
    mov ax,es
    cmp ax,bx
    jne fail
    cmp di,dx
    jne fail
    cmp word [es:di+2],5ch      ; backslash and terminator
    jne fail
    mov ax,2                    ; one-based B: -> zero-based drive number
    push ax
    mov ax,1219h
    int 2fh
    pop bx
    jc fail
    cmp al,1
    jne fail
    mov ax,26                   ; Z: is beyond LASTDRIVE
    push ax
    mov ax,1219h
    int 2fh
    pop bx
    jnc fail
    cmp al,15
    jne fail
    ; A server IOCTL drive-attribute query takes no caller buffer.
    ; Changing DS must never turn an absent physical drive into a valid one.
    mov [server_query+14],ds
    mov cx,16
server_drive_query:
    push cx
    mov dx,server_query
    mov ax,5d00h
    int 21h
    push cs                     ; server dispatch returns the DPL's DS
    pop ds
    pop cx
    jnc fail
    cmp ax,15
    jne fail
    inc word [server_query+12]
    loop server_drive_query
    ret

check_handles:
    call check_ioctl
    push bx                     ; preserve the original open handle
    mov bx,32
    mov ah,67h
    int 21h
    jc fail
    pop bx
    mov cx,25                   ; force a duplicate into the enlarged table
    mov ah,46h
    int 21h
    jc fail
    push bx
    mov bx,0ffffh               ; a bad source must leave handle 25 usable
    mov ah,46h
    int 21h
    jnc fail
    cmp ax,6
    jne fail
    mov bx,25
    mov ax,5700h
    int 21h
    jc fail
    mov cx,bx                   ; duplicating an open handle onto itself
    mov ah,46h
    int 21h
    jc fail
    mov cx,6241h
    mov dx,285dh
    mov ax,5701h                ; timestamp through the duplicate
    int 21h
    jc fail
    mov bx,20
    mov ah,67h                  ; shrinking would discard a live handle
    int 21h
    jnc fail
    cmp ax,4
    jne fail
    ; NLS multiplex callers retain the application stack. Use a duplicate
    ; so a read, a 32-bit seek and a close exercise all three entries.
    mov bx,25
    mov dx,flatname
    mov cx,1
    mov ax,1229h                ; read at EOF
    push ax
    int 2fh
    pop di
    jc fail
    or ax,ax
    jnz fail
    xor bp,bp                   ; seek from start
    mov cx,1
    mov dx,1234h
    mov ax,1228h
    push ax
    int 2fh
    pop di
    jc fail
    cmp dx,1
    jne fail
    cmp ax,1234h
    jne fail
    mov ax,1227h
    push ax
    int 2fh
    pop di
    jc fail
    mov ax,1229h                ; read from closed handle
    push ax
    int 2fh
    pop di
    jnc fail
    cmp ax,6
    jne fail
    mov bx,20
    mov ah,67h
    int 21h
    jc fail
    mov bx,25
    mov ah,68h                  ; committing the closed handle must fail
    int 21h
    jnc fail
    cmp ax,6
    jne fail
    pop bx
    mov ax,5700h
    int 21h
    jc fail
    cmp cx,6241h
    jne fail
    cmp dx,285dh
    jne fail
    ret
; BX is an open disk file. Exercise handle, drive and driver-packet IOCTLs.
check_ioctl:
    push bx
    mov ax,4400h
    int 21h
    jc fail
    test dl,80h                 ; a file, not a character device
    jnz fail
    mov bx,0ffffh
    mov ax,4400h
    int 21h
    jnc fail
    cmp ax,6
    jne fail
    mov bx,26                   ; LASTDRIVE=E on the scratch boot
    mov ax,4408h
    int 21h
    jnc fail
    cmp ax,15
    jne fail
    mov bx,2                    ; B: is a 1.44 MB floppy
    mov ax,4409h
    int 21h
    jc fail
    test dx,1000h
    jnz fail
    mov cx,0860h                ; get default device parameters
    mov dx,ioctl_packet
    mov ax,440dh
    int 21h
    jc fail
    cmp word [ioctl_packet+7],512
    jne fail
    mov word [ioctl_packet+7],0
    push ds
    mov bp,0dh                  ; multiplex IOCTL uses BP for the subfunction
    mov ax,122bh
    push ax
    int 2fh
    pop di
    pop ds
    jc fail
    cmp word [ioctl_packet+7],512
    jne fail
    pop bx
    ret
xopen:
    mov ax,6c00h
    mov bx,2
    xor cx,cx
    mov si,pathname
    int 21h
    ret
close:
    mov bx,ax
    mov ah,3eh
    int 21h
    jc fail
    ret
child_block dw 0,80h,0,5ch,0,6ch,0,0,0,0,0
child_stage db 0
saved_sp dw 0
self_name db 'A:\HMASVC.COM',0
status dw 0,0,035ah,0300h
tail db 1,'0',13
     times 125 db 0
child_name db 'A:\SVCCHILD.EXE',0
missing_name db 'A:\NOSUCH.EXE',0
overlay_name db 'A:\SVCOVL.EXE',0
overlay_block dw 0,0
directory db 'B:\SVCDIR',0
broot db 'B:\',0
renamed_dir db 'B:\SVCDIR2',0
current_path times 64 db 0ffh
server_query dw 4409h,26,0,0,0,0,0,0,0,0,0
ioctl_packet times 256 db 0
pathname db 'B:\SVCDIR\..\SVCTEST.TMP',0
flatname db 'B:\SVCTEST.TMP',0
okmsg db 'HMA SERVICES PASS',13,10,'$'
times 256 db 0
stacktop:
