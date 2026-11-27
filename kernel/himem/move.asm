; SPDX-License-Identifier: MIT
; XMS 0Bh. Resolve both ranges before the first write. Per-call BIOS
; descriptors and private handle pins allow re-entry between transfers.
code segment para public 'CODE'
assume cs:code
extrn claim_pool:near, hold_block:near
public move_block

; BP-relative call frame. Each endpoint contains a physical byte address
; followed by its pin counter offset (zero for a real-mode pointer).
source      equ -6
target      equ -12
remaining   equ -16                     ; DWORD bytes left
chunk_limit equ -18
chunk_size  equ -20
descending  equ -21
use_buffer  equ -22
buffer_addr equ -26                     ; physical address of scratch
scratch_len equ 32
scratch     equ buffer_addr-scratch_len
table_base  equ scratch-48              ; six BIOS segment descriptors
block_limit equ 4096                    ; interrupt window every 4 KiB
kib         dw  1024

move_block proc near
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        pushf
        cli
        push    bp
        mov     bp,sp
        sub     sp,-table_base
        xor     ax,ax
        mov     [bp+source+4],ax
        mov     [bp+target+4],ax
        call    claim_pool
        jnc     read_packet
        cmp     bl,90h                  ; conventional moves need no EMB pool
        je      read_packet
        jmp     move_failed
read_packet:
        mov     ax,[si]
        mov     [bp+remaining],ax
        test    al,1
        jz      even_length
        mov     bl,0a7h
        jmp     move_failed
even_length:
        mov     ax,[si+2]
        mov     [bp+remaining+2],ax
        add     si,4
        lea     di,[bp+source]
        mov     bl,0a3h
        call    resolve_range
        jnc     source_ok
        jmp     move_failed
source_ok:
        add     si,6
        lea     di,[bp+target]
        mov     bl,0a5h
        call    resolve_range
        jnc     ranges_ok
        jmp     move_failed
ranges_ok:
        mov     ax,[bp+remaining]
        or      ax,[bp+remaining+2]
        jz      nothing_to_move
        mov     ax,[bp+target]
        mov     dx,[bp+target+2]
        sub     ax,[bp+source]
        sbb     dx,[bp+source+2]
        mov     byte ptr [bp+descending],0
        jc      lower_target
        mov     cx,ax
        or      cx,dx
        jz      nothing_to_move         ; includes differently spelled aliases
        inc     byte ptr [bp+descending]
        jmp     short check_distance
nothing_to_move:
        jmp     move_ok
lower_target:
        neg     dx                      ; DX:AX = absolute distance
        neg     ax
        sbb     dx,0
check_distance:
        mov     word ptr [bp+chunk_limit],block_limit
        mov     byte ptr [bp+use_buffer],0
        cmp     dx,[bp+remaining+2]
        jb      overlap
        ja      disjoint
        cmp     ax,[bp+remaining]
        jb      overlap
disjoint:
        mov     byte ptr [bp+descending],0
        jmp     short ready
overlap:
        ; Keep each individual BIOS copy disjoint, irrespective of the
        ; firmware's copy direction. Very close ranges go via scratch so
        ; a one-byte displacement can still use word-sized BIOS transfers.
        or      dx,dx
        jnz     direction
        cmp     ax,block_limit
        jae     direction
        and     ax,0fffeh
        cmp     ax,scratch_len
        jae     set_limit
        inc     byte ptr [bp+use_buffer]
        mov     ax,ss
        lea     dx,[bp+scratch]
        call    far_address
        mov     [bp+buffer_addr],ax
        mov     [bp+buffer_addr+2],dx
        mov     ax,scratch_len
set_limit:
        mov     [bp+chunk_limit],ax
direction:
        cmp     byte ptr [bp+descending],0
        je      ready
        mov     ax,[bp+remaining]
        mov     dx,[bp+remaining+2]
        add     [bp+source],ax
        adc     [bp+source+2],dx
        add     [bp+target],ax
        adc     [bp+target+2],dx
ready:
        push    word ptr [bp+2]         ; respect caller's interrupt state
        popf
next_chunk:
        mov     ax,[bp+chunk_limit]
        cmp     word ptr [bp+remaining+2],0
        jne     have_size
        cmp     ax,[bp+remaining]
        jbe     have_size
        mov     ax,[bp+remaining]
have_size:
        mov     [bp+chunk_size],ax
        cmp     byte ptr [bp+descending],0
        je      copy_chunk
        sub     [bp+source],ax
        sbb     word ptr [bp+source+2],0
        sub     [bp+target],ax
        sbb     word ptr [bp+target+2],0
copy_chunk:
        lea     si,[bp+source]
        lea     di,[bp+target]
        cmp     byte ptr [bp+use_buffer],0
        je      write_chunk
        lea     di,[bp+buffer_addr]
        call    bios_copy
        jc      move_failed
        lea     si,[bp+buffer_addr]
        lea     di,[bp+target]
write_chunk:
        call    bios_copy
        jc      move_failed
        mov     ax,[bp+chunk_size]
        cmp     byte ptr [bp+descending],0
        jne     count_chunk
        add     [bp+source],ax
        adc     word ptr [bp+source+2],0
        add     [bp+target],ax
        adc     word ptr [bp+target+2],0
count_chunk:
        sub     [bp+remaining],ax
        sbb     word ptr [bp+remaining+2],0
        mov     ax,[bp+remaining]
        or      ax,[bp+remaining+2]
        jnz     next_chunk
move_ok:
        mov     ax,1
        xor     bl,bl
        jmp     short cleanup
move_failed:
        xor     ax,ax
cleanup:
        cli
        mov     si,[bp+source+4]
        or      si,si
        jz      release_target
        dec     word ptr cs:[si]
release_target:
        mov     si,[bp+target+4]
        or      si,si
        jz      restore
        dec     word ptr cs:[si]
restore:
        mov     [bp+16],bl              ; preserve caller's BH
        mov     sp,bp
        pop     bp
        popf
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        ret
move_block endp

; DS:SI -> handle/offset, SS:DI -> resolved endpoint, BL=handle error.
; Subtract the offset first so a large unsigned length cannot wrap into
; an apparently valid range. An empty move may start at the exclusive end.
resolve_range proc near
        mov     dx,[si]
        or      dx,dx
        jz      real_pointer
        call    hold_block
        jc      range_error
        mov     ss:[di+4],dx
        mul     cs:kib
        mov     ss:[di],ax
        mov     ss:[di+2],dx
        mov     ax,cx
        mul     cs:kib
        sub     ax,[si+2]
        sbb     dx,[si+4]
        jc      bad_offset
        mov     cx,[si+2]
        add     ss:[di],cx
        mov     cx,[si+4]
        adc     ss:[di+2],cx
        jmp     short check_length
real_pointer:
        mov     ax,[si+4]
        mov     dx,[si+2]
        call    far_address
        mov     ss:[di],ax
        mov     ss:[di+2],dx
        mov     ax,0fff0h               ; FFFF:FFFF + 1 = 0010FFF0h
        mov     dx,10h
        sub     ax,ss:[di]
        sbb     dx,ss:[di+2]
check_length:
        cmp     dx,[bp+remaining+2]
        jb      bad_length
        ja      range_ok
        cmp     ax,[bp+remaining]
        jb      bad_length
range_ok:
        clc
        ret
bad_length:
        mov     bl,0a7h
        jmp     short range_error
bad_offset:
        inc     bl                      ; A4h for source, A6h for target
range_error:
        stc
        ret
resolve_range endp

; AX:DX = segment:offset on entry, DX:AX = linear address on return.
far_address proc near
        mov     cx,dx
        mov     dx,16
        mul     dx
        add     ax,cx
        adc     dx,0
        ret
far_address endp

; SS:SI, SS:DI address the two physical pointers. Firmware may overwrite
; its six-entry table, so initialize it for each call. The resident INT 15h
; hook restores A20 around the real BIOS transfer, including failures.
bios_copy proc near
        push    ss
        pop     es
        push    di
        lea     di,[bp+table_base]
        mov     cx,24
        xor     ax,ax
        cld
        rep     stosw
        pop     di
        mov     word ptr [bp+table_base+10h],0ffffh
        mov     ax,ss:[si]
        mov     [bp+table_base+12h],ax
        mov     ax,ss:[si+2]
        mov     ah,93h
        mov     [bp+table_base+14h],ax
        mov     word ptr [bp+table_base+18h],0ffffh
        mov     ax,ss:[di]
        mov     [bp+table_base+1ah],ax
        mov     ax,ss:[di+2]
        mov     ah,93h
        mov     [bp+table_base+1ch],ax
        lea     si,[bp+table_base]
        mov     cx,[bp+chunk_size]
        shr     cx,1
        mov     ah,87h
        push    bp
        int     15h
        pop     bp
        jnc     bios_done
        mov     bl,82h
        cmp     ah,3
        je      bios_error
        mov     bl,0a9h
        cmp     ah,1
        je      bios_error
        mov     bl,8eh                  ; other firmware failure
bios_error:
        stc
bios_done:
        ret
bios_copy endp
code ends
end
