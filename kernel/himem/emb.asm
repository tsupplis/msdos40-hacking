; SPDX-License-Identifier: MIT
; Extended memory blocks. A handle is the offset of a stable descriptor.
; The separate address-ordered index contains only nonempty blocks. Gaps
; represent free memory, so freeing adjacent blocks coalesces immediately.
code segment para public 'CODE'
assume cs:code, ds:code
extrn claim_pool:near, pool_first:word, pool_end:word
public emb, handle_info, table_seg, hold_block

handle_count equ 16
unused_slot  equ 4
used_slot    equ 2

; INT 2Fh/4309h layout consumed by MEM. Physical bases and sizes are in
; KiB. The high words stay zero throughout the 286 address space.
descriptor struc
slot_state db   unused_slot
lock_count db   0
base_k     dw   0,0
length_k   dw   0,0
descriptor ends

handle_info label byte
        db      1,size descriptor
        dw      handle_count,offset slots
table_seg dw    0                       ; filled by the multiplex handler
        dw      offset slots_end
slots   descriptor handle_count dup (<>)
slots_end label byte
move_pins dw    handle_count dup (0)    ; independent of public lock counts
free_slots db   handle_count
ordered dw      handle_count+1 dup (0)  ; zero terminates even a full index

; Called with AH=08h..0Fh, excluding move (0Bh). Each metadata update is
; atomic. All calls preserve DS, SI, DI, CX and BP. The individual services
; below change only their specified output registers and BL on error.
emb proc near
        pushf
        cli
        push    ds
        push    si
        push    di
        push    cx
        push    bp
        push    cs
        pop     ds
        ; Finish the BIOS reservation before selecting a descriptor. The
        ; BIOS may enable interrupts. A nested call must never acquire the
        ; same slot as the interrupted caller. Zero-length handles can
        ; still be used when the BIOS reports no extended RAM.
        push    ax
        push    bx
        call    claim_pool
        jnc     pool_ready
        cmp     bl,90h
        je      pool_ready
        ; A late VDISK conflict closes the pool to new accesses. Existing
        ; clients can still inspect, unlock and free their descriptors.
        mov     cl,bl
        pop     bx
        pop     ax
        mov     bl,cl
        cmp     bl,81h
        jne     reject_request
        cmp     ah,0ah
        je      emb_lookup
        cmp     ah,0dh
        je      emb_lookup
        cmp     ah,0eh
        je      emb_lookup
reject_request:
        cmp     ah,09h
        ja      claim_error
        xor     dx,dx                   ; empty query or null output handle
claim_error:
        xor     ax,ax
        jmp     emb_done
pool_ready:
        pop     bx
        pop     ax
        cmp     ah,08h
        jne     emb_alloc
        call    query_space
        jmp     short emb_done
emb_alloc:
        cmp     ah,09h
        jne     emb_lookup
        call    allocate_block
        jmp     short emb_done
emb_lookup:
        call    find_handle
        jnc     live_handle
        mov     bl,0a2h
        xor     ax,ax
        jmp     short emb_done
live_handle:
        cmp     ah,0ah
        jne     emb_lock
        call    free_block
        jmp     short emb_done
emb_lock:
        cmp     ah,0ch
        jne     emb_unlock
        call    lock_block
        jmp     short emb_done
emb_unlock:
        cmp     ah,0dh
        jne     emb_info
        call    unlock_block
        jmp     short emb_done
emb_info:
        cmp     ah,0eh
        jne     emb_resize
        mov     bh,[si].lock_count
        mov     bl,free_slots
        mov     dx,[si].length_k
        mov     ax,1
        jmp     short emb_done
emb_resize:
        call    resize_block
emb_done:
        pop     bp
        pop     cx
        pop     di
        pop     si
        pop     ds
        popf
        ret
emb endp

; Match the exact offset of a live descriptor. DX=handle, SI=descriptor,
; DI=its private pin counter. CF set on failure. Called with IRQs masked.
find_handle proc near
        mov     si,offset slots
        mov     di,offset move_pins
        mov     cx,handle_count
lookup_slot:
        cmp     dx,si
        je      check_slot
        add     si,size descriptor
        add     di,2
        loop    lookup_slot
bad_slot:
        stc
        ret
check_slot:
        cmp     cs:[si].slot_state,used_slot
        jne     bad_slot
        ret                             ; equal comparison clears CF
find_handle endp

; Pin a move operand before any interrupt window. Return base and length
; in KiB (AX, CX), and the counter offset in DX for release by the mover.
; Ordinary XMS unlocks cannot consume these internal references.
hold_block proc near
        push    si
        push    di
        call    find_handle
        jc      hold_done
        inc     word ptr cs:[di]
        jnz     pinned
        dec     word ptr cs:[di]
        stc
        jmp     short hold_done
pinned:
        mov     ax,cs:[si].base_k
        mov     cx,cs:[si].length_k
        mov     dx,di
hold_done:
        pop     di
        pop     si
        ret
hold_block endp

; DX=0 queries all gaps, returning AX=largest and DX=total KiB. When
; DX>0, stop at the first fit: AX=base, DI=index insertion point, CF clear.
; CF set means the walk reached the end. BX and BP are preserved.
scan_gaps proc near
        push    bx
        push    bp
        xor     bx,bx                   ; total free KiB
        xor     bp,bp                   ; largest gap
        mov     ax,pool_first
        mov     di,offset ordered
next_gap:
        mov     si,[di]
        mov     cx,pool_end
        or      si,si
        jz      measure_gap
        mov     cx,[si].base_k
measure_gap:
        sub     cx,ax
        or      dx,dx
        jz      count_gap
        cmp     cx,dx
        jae     gap_found               ; CF clear
count_gap:
        add     bx,cx
        cmp     bp,cx
        jae     advance
        mov     bp,cx
advance:
        or      si,si
        jz      scanned
        mov     ax,[si].base_k
        add     ax,[si].length_k
        add     di,2
        jmp     short next_gap
scanned:
        mov     dx,bx
        mov     ax,bp
        stc
gap_found:
        pop     bp
        pop     bx
        ret
scan_gaps endp

query_space proc near
        xor     dx,dx
        call    scan_gaps
        xor     bl,bl
        or      ax,ax
        jz      empty_pool
        cmp     free_slots,0
        jne     query_done
        xor     ax,ax                   ; only existing handles can use DX KiB
        ret
empty_pool:
        mov     bl,0a0h
query_done:
        ret
query_space endp

allocate_block proc near
        cmp     free_slots,0
        jne     find_slot
        mov     bl,0a1h
        jmp     short alloc_failed
find_slot:
        mov     bp,offset slots
next_slot:
        cmp     ds:[bp].slot_state,unused_slot
        je      slot_found
        add     bp,size descriptor
        jmp     short next_slot
slot_found:
        call    place_block
        jc      alloc_failed
        mov     ds:[bp].slot_state,used_slot
        dec     free_slots
        mov     dx,bp
        mov     ax,1
        ret
alloc_failed:
        xor     dx,dx                   ; required null handle on failure
        xor     ax,ax
        ret
allocate_block endp

; BP identifies an empty descriptor; DX is the requested length. A
; zero-length handle uses no memory and stays out of the address index.
; Leave the descriptor untouched if the request cannot be satisfied.
place_block proc near
        or      dx,dx
        jz      placed
        call    scan_gaps
        jc      no_gap
        mov     ds:[bp].base_k,ax
        mov     ds:[bp].length_k,dx
        mov     ax,bp
insert_slot:
        xchg    ax,[di]
        add     di,2
        or      ax,ax
        jnz     insert_slot
placed:
        xor     bl,bl                   ; CF clear
        ret
no_gap:
        mov     bl,0a0h
        stc
        ret
place_block endp

; Remove a nonempty block from the physical order. Shift the terminating
; zero with the remaining entries. SI retains the descriptor address.
unlink_block proc near
        mov     di,offset ordered
find_link:
        cmp     [di],si
        je      shift_links
        add     di,2
        jmp     short find_link
shift_links:
        mov     ax,[di+2]
        mov     [di],ax
        add     di,2
        or      ax,ax
        jnz     shift_links
        mov     [si].base_k,ax
        mov     [si].length_k,ax
        ret
unlink_block endp

free_block proc near
        cmp     word ptr [di],0
        jne     block_locked
        cmp     [si].lock_count,0
        jne     block_locked
        cmp     [si].length_k,0
        je      release_slot
        call    unlink_block
release_slot:
        mov     [si].slot_state,unused_slot
        inc     free_slots
block_ok:
        mov     ax,1
        xor     bl,bl
        ret
block_locked:
        mov     bl,0abh
block_error:
        xor     ax,ax
        ret
free_block endp

lock_block proc near
        cmp     [si].lock_count,0ffh
        jne     lock_ok
        mov     bl,0ach
        jmp     short block_error
lock_ok:
        inc     [si].lock_count
        mov     ax,[si].base_k
        mov     bx,1024
        mul     bx                      ; KiB to physical byte address
        mov     bx,ax
        mov     ax,1
        ret
lock_block endp

unlock_block proc near
        cmp     [si].lock_count,0
        jne     unlock_ok
        mov     bl,0aah
        jmp     short block_error
unlock_ok:
        dec     [si].lock_count
        jmp     short block_ok
unlock_block endp

; BX=new KiB. Shrink, or grow into the adjacent gap. A zero-length
; block can be placed anywhere. Growth of a live block is in-place only.
resize_block proc near
        cmp     word ptr [di],0
        jne     block_locked
        cmp     [si].lock_count,0
        jne     block_locked
        or      bx,bx
        jnz     resize_nonzero
        cmp     [si].length_k,0
        je      block_ok
        call    unlink_block
        jmp     short block_ok
resize_nonzero:
        cmp     [si].length_k,0
        jne     resize_live
        push    dx                      ; retain the handle across placement
        mov     dx,bx
        mov     bp,si
        call    place_block
        pop     dx
        jc      block_error
        jmp     short block_ok
resize_live:
        cmp     bx,[si].length_k
        jbe     resize_commit
        mov     di,offset ordered
resize_find:
        cmp     [di],si
        je      resize_limit
        add     di,2
        jmp     short resize_find
resize_limit:
        mov     di,[di+2]
        mov     ax,pool_end
        or      di,di
        jz      resize_check
        mov     ax,[di].base_k
resize_check:
        sub     ax,[si].base_k           ; subtraction avoids a length wrap
        cmp     ax,bx
        jae     resize_commit
        mov     bl,0a0h
        jmp     block_error
resize_commit:
        mov     [si].length_k,bx
        jmp     block_ok
resize_block endp
code ends
end
