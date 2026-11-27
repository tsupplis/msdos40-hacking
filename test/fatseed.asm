; Seed known FAT12 bad clusters on the runner's 1.44 MB scratch floppy B:.
bits 16
cpu 8086
org 100h
    mov dx,1
    call read_fat
    jc failed
    cmp word [buf],0fff0h
    jne failed
    cmp byte [buf+2],0ffh
    jne failed
    ; Cluster 340 starts at offset 510. Cluster 341 crosses sectors.
%ifdef ORPHANS
    mov word [buf+510],0ffffh   ; two one-cluster chains without directory entries
%else
    mov word [buf+510],07ff7h
%endif
    mov byte [buf+512],0ffh
    call write_fat
    jc failed
    mov dx,10
    call write_fat
    jc failed
    mov ax,4c00h
    int 21h
failed:
    mov ax,4c01h
    int 21h
read_fat:
    mov bx,buf
    mov cx,2
    mov al,1
    int 25h
    pop bx
    ret
write_fat:
    mov bx,buf
    mov cx,2
    mov al,1
    int 26h
    pop bx
    ret
buf:
