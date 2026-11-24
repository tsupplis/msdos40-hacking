; Terminal help request, callable as void show_help(const char *topic)
; with the small-model C convention. The topic is a fixed command name.
; All launcher data is CS-relative so COM and small-model EXE callers
; can use the same code regardless of their data segment.
public _show_help
_show_help proc near
        mov bp,sp
        mov si,[bp+2]
        push cs
        pop es
        cld
        mov di,offset help_tail+2
        mov cx,12
help_copy_topic:
        lodsb
        or al,al
        jz help_topic_done
        stosb
        loop help_copy_topic
        cmp byte ptr [si],0
        je help_topic_done
        jmp help_failed
help_topic_done:
        mov al,13
        stosb
        mov ax,di
        sub ax,offset help_tail+2
        mov cs:help_tail,al
        mov ah,62h
        int 21h
        mov es,bx
        mov ax,es:[2ch]
        mov cs:help_env,ax
        ; Retain the caller's entire near data/stack segment for an EXE.
        ; The COM caller has already resized around its actual stack.
        mov ax,ss
        cmp ax,bx
        je help_search
        add ax,1000h
        jc help_search
        cmp ax,es:[2]
        jae help_search
        sub ax,bx
        mov bx,ax
        mov ah,4ah
        int 21h
help_search:
        push cs
        pop ds
        push cs
        pop es
        mov help_tail_seg,ds
        ; Supply the standard PSP default FCB pointers.
        mov ah,62h
        int 21h
        mov help_fcb1_seg,bx
        mov help_fcb2_seg,bx
        mov dx,offset help_file
        call help_exec
        mov ax,help_env
        or ax,ax
        jz help_failed
        mov ds,ax
        xor si,si
help_env_next:
        cmp byte ptr [si],0
        je help_failed
        mov di,offset help_key
        mov cx,5
        push si
        repe cmpsb
        pop si
        je help_path
help_env_skip:
        lodsb
        or al,al
        jnz help_env_skip
        jmp help_env_next
help_path:
        add si,5
help_next_dir:
        mov di,offset help_candidate
help_dir_char:
        lodsb
        or al,al
        jz help_dir_end
        cmp al,';'
        je help_dir_end
        cmp di,offset help_candidate+118
        jae help_skip_long
        stosb
        jmp help_dir_char
help_skip_long:
        lodsb
        cmp al,';'
        je help_next_dir
        or al,al
        jnz help_skip_long
        jmp short help_failed
help_dir_end:
        push ax
        cmp di,offset help_candidate
        je help_continue
        cmp byte ptr es:[di-1],5ch
        je help_append
        cmp byte ptr es:[di-1],':'
        je help_append
        mov al,5ch
        stosb
help_append:
        push ds
        push si
        push cs
        pop ds
        mov si,offset help_file
        mov cx,9
        rep movsb
        mov dx,offset help_candidate
        call help_exec
        pop si
        pop ds
help_continue:
        pop ax
        or al,al
        jnz help_next_dir
help_failed:
        push cs
        pop ds
        mov bx,2
        mov dx,offset help_unavailable
        mov cx,help_msg_end-help_unavailable-1
        mov ah,40h
        int 21h
        mov ax,4c01h
        int 21h
_show_help endp

; Return only when the candidate was absent. A child that ran owns its
; diagnostics, including the missing-database case.
help_exec proc near
        mov bx,offset help_params
        mov ax,4b00h
        int 21h
        jnc help_child_done
        cmp ax,2
        je help_exec_return
        cmp ax,3
        jne help_failed
help_exec_return:
        ret
help_child_done:
        mov ah,4dh
        int 21h
        mov ah,4ch
        int 21h
help_exec endp

help_file db 'HELP.COM',0
help_key db 'PATH='
include showhelp.cl1
help_msg_end label byte
help_env dw ?
help_params dw 0,offset help_tail
help_tail_seg dw ?
        dw 5ch
help_fcb1_seg dw ?
        dw 6ch
help_fcb2_seg dw ?
help_tail db 0,' ',13 dup (?)
help_candidate db 128 dup (?)
