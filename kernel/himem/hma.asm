; SPDX-License-Identifier: MIT
; XMS owns the whole HMA as one block. The BIOS allocation interface can
; describe free memory only from 1 MiB, so it must report zero after our
; first grant, even between XMS owners. Version queries leave it untouched.
code segment para public 'CODE'
assume cs:code
extrn sense_gate:near, set_gate:near
public hma, claim_pool, pool_first, pool_end, hook_bios, bios_hooked
public legacy_conflict

unclaimed equ   0                       ; BIOS still owns extended memory
available equ   1                       ; reserved for XMS, no current owner
allocated equ   2                       ; granted by function 01h
small_pool equ  4                       ; less than 64 KiB, EMBs only
conflict  equ   3                       ; legacy driver occupies the HMA

unchecked equ   5                       ; pool reserved before first HMA grant

bios_hooked db  0
hma_state db    unclaimed
claim_busy db   0                       ; BIOS may temporarily enable IRQs
pool_first dw   0                       ; physical KiB, inclusive
pool_end   dw   0                       ; physical KiB, exclusive
old15      dd   0

; AH=00h returns version in AX, revision in BX and HMA presence in DX.
; AH=01h/02h request/release the entire block. There is no minimum size
; threshold. DX is advisory on request and may be FFFFh. These calls
; return AX=1 on success or AX=0 and a reason in BL on failure.
hma proc near
        pushf
        cli
        or      ah,ah
        jz      version
        cmp     ah,2
        je      release
        cmp     cs:hma_state,allocated
        je      busy
        ; A block query can reserve the pool before a later CONFIG.SYS
        ; driver announces itself. Verify ownership at the first HMA grant.
        cmp     cs:hma_state,unchecked
        jne     first_claim
        call    check_legacy
        jnc     grant
        mov     bl,al
        jmp     short fail
first_claim:
        call    claim_pool
        jc      hma_done
        cmp     cs:hma_state,small_pool
        jne     grant
        mov     bl,90h
        jmp     short fail
grant:
        mov     cs:hma_state,allocated
        jmp     short success
release:
        cmp     cs:hma_state,allocated
        jne     no_owner
        mov     cs:hma_state,available
success:
        mov     ax,1
        xor     bl,bl
        jmp     short hma_done
busy:
        mov     bl,91h
        jmp     short fail
no_owner:
        mov     bl,93h
fail:
        xor     ax,ax
        jmp     short hma_done
version:
        xor     dx,dx
        cmp     cs:hma_state,conflict
        je      revision
        cmp     cs:hma_state,small_pool
        je      revision
        cmp     cs:hma_state,unclaimed
        jne     found
        cmp     cs:claim_busy,0         ; never recursively enter the BIOS
        jne     revision
        mov     cs:claim_busy,1
        call    bios_size               ; provisional until the first grant
        mov     cs:claim_busy,0
        jc      revision
        cmp     ax,64
        jb      revision
found:
        inc     dx
revision:
        mov     ax,0200h
        mov     bx,0001h
hma_done:
        popf
        ret
hma endp

; Return contiguous extended KiB in AX. CF indicates a BIOS failure.
bios_size proc near
        push    bp
        push    ds
        push    es
        push    si
        push    di
        push    cx
        push    dx
        mov     ax,8800h
        clc                             ; older size handlers preserve CF
        int     15h
        cli                             ; firmware may have enabled IRQs
        pop     dx
        pop     cx
        pop     di
        pop     si
        pop     es
        pop     ds
        pop     bp
        ret
bios_size endp

; A20 services use the same sticky conflict decision as the allocator.
; ZF set if a legacy owner was detected. Caller has masked interrupts.
legacy_conflict proc near
        cmp     cs:hma_state,conflict
        ret
legacy_conflict endp

; Both HMA and EMB calls enter with interrupts masked. Only the first
; reservation touches the firmware. On success, pool_first..pool_end is
; the exclusive EMB range. Preserve BX/DX inputs to the allocator on
; success. Return CF set, AX=0 and the XMS error in BL on failure.
claim_pool proc near
        cmp     cs:hma_state,conflict
        je      claim_conflict
        cmp     cs:hma_state,unclaimed
        jne     claimed
        cmp     cs:claim_busy,0
        jne     claim_in_progress
        mov     cs:claim_busy,1
        push    bx
        call    reserve
        pop     ax                      ; original BX if reservation succeeded
        mov     cs:claim_busy,0
        jc      claim_failed
        mov     bx,ax
claimed:
        clc
        ret
claim_conflict:
        mov     bl,81h
        jmp     short claim_failed
claim_in_progress:
        mov     bl,82h
claim_failed:
        xor     ax,ax
        stc
        ret
claim_pool endp

; Link at the first non-version XMS call. Protect BIOS moves immediately.
; The size service still chains until the block pool actually owns the RAM.
hook_bios proc near
        pushf
        cli
        cmp     cs:bios_hooked,0
        jne     hook_done
        push    ax
        push    es
        xor     ax,ax
        mov     es,ax
        mov     ax,es:[15h*4]
        mov     word ptr cs:old15,ax
        mov     ax,es:[15h*4+2]
        mov     word ptr cs:old15+2,ax
        mov     word ptr es:[15h*4],offset memory_bios
        mov     es:[15h*4+2],cs
        mov     cs:bios_hooked,1
        pop     es
        pop     ax
hook_done:
        popf
        ret
hook_bios endp

; Publish both pool boundaries together, after the firmware size and
; signature checks have succeeded. claim_busy protects the BIOS call.
reserve proc near
        push    dx
        call    bios_size
        mov     bl,90h
        jc      reserve_done
        or      ax,ax
        jz      reserve_error
        cmp     ax,15*1024              ; 24-bit physical address limit
        jbe     size_known
        mov     ax,15*1024
size_known:
        push    ax
        call    check_legacy
        mov     bl,al
        pop     ax
        jc      reserve_done
        add     ax,1024
        mov     cs:pool_end,ax
        mov     dx,1024
        mov     cs:hma_state,small_pool
        cmp     ax,1024+64
        jb      publish_pool
        add     dx,64
        mov     cs:hma_state,unchecked
publish_pool:
        mov     cs:pool_first,dx
        clc
        jmp     short reserve_done
reserve_error:
        stc
reserve_done:
        pop     dx
        ret
reserve endp

; Check the INT 19h marker and both HMA signatures with IRQs masked.
; Restore the entry gate state. Return CF and AL=81h/82h on failure.
check_legacy proc near
        push    ds
        push    es
        push    si
        push    di
        push    cx
        push    dx
        push    bx
        push    cs
        pop     ds
assume ds:code
        xor     ax,ax
        mov     es,ax
        mov     es,es:[19h*4+2]
        mov     di,12h
        mov     si,offset vdisk_id
        mov     cx,5
        cld
        repe    cmpsb
        je      legacy_owner

        call    sense_gate
        mov     dl,al                   ; remember the physical entry state
        or      ax,ax
        jnz     inspect
        mov     dh,1
        call    set_gate
        jc      gate_error
inspect:
        call    high_signature
        or      dl,dl
        jnz     checked
        xor     dh,dh
        call    set_gate
        jc      gate_error
checked:
        or      bl,bl
        jnz     legacy_owner

        clc
        jmp     short legacy_done
gate_error:
        mov     al,82h
        jmp     short legacy_error
legacy_owner:
        mov     hma_state,conflict
        mov     al,81h
legacy_error:
        stc
legacy_done:
        pop     bx
        pop     dx
        pop     cx
        pop     di
        pop     si
        pop     es
        pop     ds
        ret
check_legacy endp

; Called with A20 on, DS=CS and DF clear. BL=81h for a legacy signature,
; zero otherwise. Clobbers AX, CX, SI, DI and ES within check_legacy's frame.
high_signature proc near
        mov     ax,0ffffh
        mov     es,ax
        mov     di,13h                  ; physical 100003h
        mov     si,offset vdisk_id
        mov     cx,5
        mov     bl,81h
        repe    cmpsb
        je      signature_done
        mov     di,10h                  ; physical 100000h
        mov     si,offset ramdrive_id
        mov     cx,ramdrive_len
        repe    cmpsb
        je      signature_done
        xor     bl,bl
signature_done:
        ret
high_signature endp

vdisk_id db 'VDISK'
ramdrive_id db 'MICROSOFT EMM CTRL'
ramdrive_len equ $-ramdrive_id
assume ds:nothing

; INT 15h/87h can leave A20 disabled. Return the underlying block move's
; status and re-establish the caller's physical gate state before IRET.
; BP points at saved BP. [BP+6] is the caller's FLAGS, and [BP-2] holds
; the entry A20 state during a block move. Only CF is returned in FLAGS.
memory_bios proc far
        pushf
        cmp     ah,88h
        je      reserved_size
        cmp     ah,87h
        je      block_move
chain_bios:
        popf
        jmp     dword ptr cs:old15
reserved_size:
        cmp     cs:pool_end,0
        je      chain_bios
        popf
        push    bp
        mov     bp,sp
        xor     ax,ax
        jmp     short bios_ok
block_move:
        popf
        push    bp
        mov     bp,sp
        push    ax
        call    sense_gate
        xchg    ax,[bp-2]               ; original AX for BIOS
        push    bp                      ; firmware may use BP as scratch
        push    word ptr [bp+6]         ; simulated INT frame for chained IRET
        call    dword ptr cs:old15
        pop     bp
        pushf
        cli
        push    ax
        push    cx
        push    dx
        mov     dh,[bp-2]
        call    sense_gate
        cmp     al,dh
        je      move_done
        call    set_gate
move_done:
        pop     dx
        pop     cx
        pop     ax
        jc      move_gate_error
        popf                            ; status returned by the previous BIOS
        mov     sp,bp                   ; discard the saved A20 state
        jnc     bios_ok
bios_error:
        or      byte ptr [bp+6],1
        jmp     short bios_done
move_gate_error:
        mov     sp,bp                   ; discard BIOS flags and gate state
        mov     ah,3                    ; BIOS block-move A20 error
        jmp     short bios_error
bios_ok:
        and     byte ptr [bp+6],0feh
bios_done:
        pop     bp
        iret
memory_bios endp
code ends
end
