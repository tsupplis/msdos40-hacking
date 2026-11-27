; SPDX-License-Identifier: MIT
; Linked last. DOS releases this segment tail after device initialization.
code segment para public 'CODE'
assume cs:code
extrn request:dword, previous:dword, multiplex:far
public initialize

initialize proc near
        ; Bits 12..15 of FLAGS read as ones on an 8086/8088/186.
        ; Restore the original flags before inspecting the captured word.
        pushf
        pop     dx
        mov     ax,dx
        and     ax,0fffh
        push    ax
        popf
        pushf
        pop     ax
        push    dx
        popf
        test    ax,0f000h
        jnz     need_at
        mov     ax,4300h
        int     2fh
        cmp     al,80h
        je      duplicate
        mov     ax,352fh
        int     21h
        mov     word ptr cs:previous,bx
        mov     word ptr cs:previous+2,es
        push    cs
        pop     ds
        mov     dx,offset multiplex
        mov     ax,252fh
        int     21h
        les     bx,cs:request
        mov     word ptr es:[bx+14],offset initialize
        mov     es:[bx+16],cs
        mov     ax,0100h
        ret
need_at:
        mov     dx,offset cpu_message
        jmp     short decline
duplicate:
        mov     dx,offset provider_message
decline:
        push    cs
        pop     ds
        mov     ah,9
        int     21h
        les     bx,cs:request
        mov     byte ptr es:[bx+13],0
        mov     word ptr es:[bx+14],0
        mov     es:[bx+16],cs
        mov     ax,810ch
        ret
initialize endp
include himem.cl1
code ends
end
