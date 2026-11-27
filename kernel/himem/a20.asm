; SPDX-License-Identifier: MIT
; XMS A20 services for the IBM AT keyboard-controller interface.
code segment para public 'CODE'
assume cs:code
extrn legacy_conflict:near
public a20, sense_gate, set_gate

locals_held dw 0
global_held dw 0
owns_gate   db 0                        ; first acquisition found A20 off

; Serialize the proposed ownership change with the hardware operation. Publish
; the new counts only after the physical state is correct. A failed final
; release thus keeps the reference and the caller can retry.
a20 proc near
        pushf
        cli
        push    ds
        push    cx
        push    dx
        push    si
        push    di
        push    cs
        pop     ds
assume ds:code
        mov     dl,ah
        call    legacy_conflict
        jne     sample_gate
        ; A late conflict still permits callers to release earlier holds.
        cmp     dl,4
        jne     check_local_release
        cmp     global_held,0
        jne     sample_gate
check_local_release:
        cmp     dl,6
        jne     legacy_error
        cmp     locals_held,0
        jne     sample_gate
legacy_error:
        mov     bl,81h
        jmp     failure
sample_gate:
        call    sense_gate
        xor     bl,bl
        cmp     dl,7
        je      a20_done
        mov     si,locals_held
        mov     di,global_held
        cmp     dl,5
        jb      global_request
        je      add_local
        or      si,si
        jz      a20_error
        dec     si
        jmp     short apply_request
add_local:
        inc     si
        jz      a20_error               ; refuse counter overflow
        jmp     short apply_request
global_request:
        xor     di,di
        cmp     dl,4
        je      apply_request
        inc     di                      ; global enable is idempotent
apply_request:
        mov     cx,si
        or      cx,di
        jz      last_release
        or      ax,ax
        jnz     commit
        mov     dh,1
        call    set_gate
        jc      a20_error
        mov     cx,locals_held
        or      cx,global_held
        jnz     commit
        mov     owns_gate,1
        jmp     short commit
last_release:
        cmp     owns_gate,0
        je      commit                  ; leave a pre-existing enable alone
        or      ax,ax
        jz      released
        xor     dh,dh
        call    set_gate
        jc      a20_error
released:
        mov     owns_gate,0
commit:
        mov     locals_held,si
        mov     global_held,di
        cmp     dl,4
        jne     success
        or      ax,ax                   ; global hold released, gate still on
        jz      success
        mov     bl,94h
        jmp     short failure
a20_error:
        mov     bl,82h
failure:
        xor     ax,ax
        jmp     short a20_done
success:
        mov     ax,1
a20_done:
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     ds
        popf
        ret
a20 endp
assume ds:nothing

; AX = physical state. Only the low BIOS scratch byte is ever changed.
; When both bytes match, change the low copy temporarily and see whether
; the high address follows it. Caller has already masked interrupts.
sense_gate proc near
        push    ds
        push    es
        xor     ax,ax
        mov     ds,ax
        dec     ax
        mov     es,ax
        mov     ah,ds:[0500h]
        cmp     ah,es:[0510h]
        jne     gate_on
        not     byte ptr ds:[0500h]
        cmp     ah,es:[0510h]
        mov     ds:[0500h],ah
        jne     gate_off
gate_on:
        mov     ax,1
        jmp     short sensed
gate_off:
        xor     ax,ax
sensed:
        pop     es
        pop     ds
        ret
sense_gate endp

; DH = requested state. Use the AT D1h output-port protocol and the
; conventional DDh/DFh controller values (reset stays deasserted).
; Poll for the physical transition as the controller processes it
; asynchronously. Bound every wait, including an absent controller.
set_gate proc near
        call    wait_input
        jnz     gate_failed
        mov     al,0d1h
        out     64h,al
        call    wait_input
        jz      send_state
        ; D1h was issued. Give a slow controller one recovery interval
        ; to accept its data byte before returning control to the caller.
        ; A controller that still reports IBF full cannot be written safely.
        call    wait_input
        jnz     gate_failed
send_state:
        mov     al,dh
        shl     al,1
        or      al,0ddh
        out     60h,al
        ; Once the data byte is submitted, the physical gate decides
        ; success. IBF can remain busy after the requested transition.
        xor     cx,cx
settling:
        call    sense_gate
        cmp     al,dh
        je      gate_ready              ; equal comparison clears carry
        loop    settling
gate_failed:
        stc
gate_ready:
        ret
set_gate endp

wait_input proc near
        xor     cx,cx
wait_busy:
        in      al,64h
        test    al,2
        loopnz  wait_busy
        ret
wait_input endp
code ends
end
