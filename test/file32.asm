; Scratch FAT16 volume from check_dir32. Only PAD.BIN is modified.
%macro phase 1
    push ax
    push dx
    mov dx,%%msg
    mov ah,9
    int 21h
    pop dx
    pop ax
    jmp short %%end
%%msg db %1,13,10,'$'
%%end:
%endmacro

cpu 8086
bits 16
org 100h
%define boundary 0x02000000

    mov ax,3d02h
    mov dx,path
    int 21h
    jc fail
    mov bx,ax
    mov al,[82h]
    cmp al,'b'
    je extend
    cmp al,'w'
    je aligned
    cmp al,'a'
    je append
    cmp al,'r'
    je readback
    cmp al,'t'
    je truncate
    cmp al,'d'
    jne fail
    call close
    mov ah,41h
    mov dx,path
    int 21h
    jc fail
    jmp pass

extend:
    phase "Seeking to seeded EOF"
    ; Seek to the seeded EOF, then fill to 1,025 bytes short of the boundary.
    xor cx,cx
    xor dx,dx
    mov ax,4202h
    int 21h
    jc fail
    mov si,(boundary-1025) >> 16
    mov di,(boundary-1025) & 0ffffh
    sub di,ax
    sbb si,dx
    jc fail
.fill:
    mov cx,32768
    test si,si
    jnz .write
    cmp di,cx
    jae .write
    mov cx,di
    or cx,cx
    jz finish
.write:
    mov dx,fill
    call write
    sub di,cx
    sbb si,0
    jmp .fill
aligned:
    xor cx,cx
    xor dx,dx
    mov ax,4202h
    int 21h
    jc fail
    phase "Writing to exactly 32 MiB"
    mov cx,1025
    mov dx,aligned_tail
    call write                  ; requires a new cluster and ends at exactly 32 MiB
    jmp finish
append:
    mov cx,(boundary-17) >> 16
    mov dx,(boundary-17) & 0ffffh
    call seek
    xor cx,cx
    call write                  ; EOF now lies in the partially filled 65536th sector
    phase "Appending beyond 32 MiB"
    mov cx,17+after_len
    mov dx,ending
    call write                  ; round up the partial old size and extend across 32 MiB
    mov cx,(boundary-2) >> 16
    mov dx,(boundary-2) & 0ffffh
    call seek
    mov cx,4
    mov dx,patch
    call write                  ; overwrite across the boundary
    jmp finish
readback:
    mov cx,(boundary-17) >> 16
    mov dx,(boundary-17) & 0ffffh
    call seek
    mov cx,17+after_len+1
    mov ah,3fh
    mov dx,buffer
    int 21h
    jc fail
    cmp ax,17+after_len
    jne fail
    mov cx,ax
    mov si,buffer
    mov di,expected
    cld
    repe cmpsb
    jne fail
    jmp finish
truncate:
    mov cx,(boundary-1025) >> 16
    mov dx,(boundary-1025) & 0ffffh
    call seek
    xor cx,cx
    mov dx,fill
    call write
finish:
    call close
pass:
    mov dx,ok
    jmp print
fail:
    mov dx,bad
print:
    mov ah,9
    int 21h
    int 20h
seek:
    mov ax,4200h
    int 21h
    jc fail
    ret
write:
    mov ah,40h
    int 21h
    jc fail
    cmp ax,cx
    jne fail
    ret
close:
    mov ah,3eh
    int 21h
    jc fail
    ret
path db 'C:\PAD.BIN',0
aligned_tail times 1008 db 0x5a
ending db '0123456789abcdefg'
after db 'after-boundary'
after_len equ $-after
patch db 'WXYZ'
expected db '0123456789abcdeWXYZter-boundary'
ok db 'FILE32 PASS',13,10,'$'
bad db 'FILE32 FAIL',13,10,'$'
fill times 32768 db 0x5a
buffer times 17+after_len+1 db 0
