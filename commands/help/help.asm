code segment
    assume cs:code, ds:code
    org 100h

start:
    cld
    xor cx,cx
    mov cl,ds:[80h]
    mov si,81h
    mov di,offset topic
    call skip_space
    or cx,cx
    jz lookup
read_name:
    lodsb
    cmp al,' '
    je name_done
    cmp al,9
    je name_done
    cmp di,offset topic+12
    jb name_fits
    jmp invalid
name_fits:
    cmp al,'a'
    jb store
    cmp al,'z'
    ja store
    sub al,32
store:
    stosb
    loop read_name
    jmp short lookup
name_done:
    dec cx
    call skip_space
    jz lookup
    jmp invalid
lookup:
    mov dx,offset filename
    mov ax,3d00h
    int 21h
    jnc opened
    call open_companion
    jnc opened
    mov dx,offset nofile
    jmp fail
opened:
    mov bx,ax
    mov dx,offset buffer
    mov cx,sp
    sub cx,dx
    jc no_room
    cmp cx,512
    ja room_available
no_room:
    jmp read_error
room_available:
    sub cx,512
    cmp cx,32767
    jbe read_file
    mov cx,32767
read_file:
    mov ah,3fh
    int 21h
    jc read_error
    cmp ax,cx
    je read_error
    mov bp,ax
    mov ah,3eh
    int 21h
    or byte ptr topic,0
    jz show_index
    mov si,offset buffer
    add bp,si
next_line:
    cmp si,bp
    jae unknown
    mov dx,si
    mov di,offset topic
compare:
    cmp si,bp
    jae unknown
    lodsb
    cmp byte ptr [di],0
    je end_name
    cmp al,[di]
    jne skip_char
    inc di
    jmp compare
end_name:
    cmp al,' '
    je find_end
    cmp al,9
    je find_end
skip_char:
    cmp al,10
    je next_line
    cmp si,bp
    jae unknown
    lodsb
    jmp skip_char
find_end:
    cmp al,10
    je write_line
    cmp si,bp
    jae write_line
    lodsb
    jmp find_end
write_line:
    ; Indented lines continue the preceding topic.
    cmp si,bp
    jae topic_end
    cmp byte ptr [si],' '
    je continue_line
    cmp byte ptr [si],9
    jne topic_end
continue_line:
    lodsb
    jmp find_end
topic_end:
    mov cx,si
    sub cx,dx
    jmp short output
show_index:
    mov cx,bp
    mov dx,offset buffer
output:
    mov bx,1
    call write_count
success:
    mov ax,4c00h
    int 21h
invalid:
    mov dx,offset usage
    jmp short fail
read_error:
    mov dx,offset unreadable
    jmp short fail
unknown:
    mov dx,offset missing
fail:
    mov bx,2
    call write_text
    mov ax,4c01h
    int 21h

open_companion:
    ; DOS 3+ records the executable pathname after the environment.
    mov ax,ds:[2ch]
    or ax,ax
    jz no_companion
    push es
    mov es,ax
    xor si,si
    cmp word ptr es:[si],0
    je environment_end
find_environment_end:
    inc si
    cmp si,32764
    jae bad_environment
    cmp word ptr es:[si],0
    jne find_environment_end
environment_end:
    cmp word ptr es:[si+2],0
    je bad_environment
    add si,4
    mov di,offset pathname
    mov dx,di
    mov cx,127
copy_path:
    mov al,es:[si]
    inc si
    or al,al
    jz append_filename
    mov [di],al
    inc di
    cmp al,':'
    je save_directory
    cmp al,5ch
    jne path_next
save_directory:
    mov dx,di
path_next:
    loop copy_path
bad_environment:
    pop es
no_companion:
    stc
    ret
append_filename:
    pop es
    mov di,dx
    mov si,offset filename
    mov cx,12
    rep movsb
    mov dx,offset pathname
    mov ax,3d00h
    int 21h
    ret

skip_space:
    jcxz skipped
    cmp byte ptr [si],' '
    je advance
    cmp byte ptr [si],9
    jne skipped
advance:
    inc si
    loop skip_space
skipped:
    or cx,cx
    ret

print:
    mov bx,1
write_text:
    mov si,dx
scan:
    lodsb
    or al,al
    jnz scan
    mov cx,si
    sub cx,dx
    dec cx
write_count:
    mov ah,40h
    int 21h
    jc output_error
    cmp ax,cx
    jne output_error
    ret
output_error:
    mov ax,4c01h
    int 21h

pathname db 140 dup (0)
topic db 13 dup (0)
filename db 'DOSHELP.HLP',0
CR equ 13
LF equ 10
include help.cl1
buffer label byte
code ends
end start
