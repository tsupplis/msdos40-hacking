; Substitute command processor for the paired SHELL fixture. Report whether
; each vector points into the suspended BASIC process. This observes the IVT
; without changing it. PSP:16h is the parent PSP and PSP:2 the segment limit.
bits 16
org 100h
        mov bx,[16h]
        mov es,bx
        mov bp,es:[2]
        xor ax,ax
        mov es,ax
        mov si,vectors
        mov cx,vec_end-vectors
next:   lodsb
        xor ah,ah
        shl ax,1
        shl ax,1
        mov di,ax
        mov ax,es:[di+2]
        mov dl,'-'
        cmp ax,bx
        jb report
        cmp ax,bp
        jae report
        mov dl,'B'
report: mov ah,2
        int 21h
        loop next
        mov ax,4c00h
        int 21h
vectors db 08h,1ch,15h,1bh,23h,24h,05h
vec_end:
