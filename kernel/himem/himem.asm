; SPDX-License-Identifier: MIT
; DOS character device and XMS multiplex entry. Initialization follows
; the resident portion so DOS can reclaim the processor and provider checks.
code segment para public 'CODE'
assume cs:code
extrn initialize:near, a20:near, hma:near, emb:near, move_block:near
extrn hook_bios:near, bios_hooked:byte
extrn handle_info:byte, table_seg:word
public request, previous, multiplex
org 0
        dd      -1
        dw      8000h
        dw      strategy, interrupt
        db      'XMSXXXX0'
request dd      0
previous dd     0
init_pending db 1

strategy proc far
        mov     word ptr cs:request,bx
        mov     word ptr cs:request+2,es
        ret
strategy endp

interrupt proc far
        push    ax
        push    bx
        push    dx
        push    ds
        push    es
        les     bx,cs:request
        cmp     byte ptr es:[bx+2],0
        jne     unsupported_request
        cmp     cs:init_pending,0       ; DOS reclaimed initialize after load
        je      unsupported_request
        mov     cs:init_pending,0
        call    initialize
        jmp     short finish
unsupported_request:
        mov     ax,8103h                ; done, unknown device command
finish:
        mov     es:[bx+3],ax
        pop     es
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        ret
interrupt endp

multiplex proc far
        pushf                           ; pass the entry flags to the next ISR
        cmp     ax,4300h
        je      installed
        cmp     ax,4309h
        je      get_table
        cmp     ax,4310h
        je      get_entry
        popf
        jmp     dword ptr cs:previous
installed:
        popf
        mov     al,80h
        iret
get_table:
        popf
        push    cs
        pop     es
        mov     cs:table_seg,cs
        mov     bx,offset handle_info
        mov     al,43h
        iret
get_entry:
        popf
        push    cs
        pop     es
        mov     bx,offset xms
        iret
multiplex endp

xms proc far
        jmp     short dispatch          ; five-byte chainable XMS entry
        nop
        nop
        nop
dispatch:
        or      ah,ah
        jz      hma_request             ; discovery alone leaves INT 15h alone
        cmp     cs:bios_hooked,0
        jne     select_service
        call    hook_bios
select_service:
        cmp     ah,03h
        jae     extended_request
hma_request:
        call    hma                     ; version, HMA request or release
        ret
extended_request:
        cmp     ah,07h
        ja      pool_request
        call    a20
        ret
pool_request:
        cmp     ah,0fh
        ja      no_function
        cmp     ah,0bh
        jne     metadata_request
        call    move_block              ; DS:SI addresses the caller's request
        ret
metadata_request:
        call    emb
        ret
no_function:
        xor     ax,ax
        mov     bl,80h                  ; function not implemented
        ret
xms endp

code ends
end
