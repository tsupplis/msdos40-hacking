; HELP.COM - display the DOSHELP.HLP index or one command description.
; Each unindented record starts with a topic key and its index summary.
; Empty lines and lines with one leading space form the topic body.
code segment
    assume cs:code, ds:code
    org 100h

; Read one case-insensitive topic from the counted PSP command tail.
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
; Prefer a local database, then try the directory containing HELP.COM.
lookup:
    mov dx,offset filename
    mov ax,3d00h
    int 21h
    jnc opened
    call open_companion
    jnc opened
    mov dx,offset nofile
    jmp fail
; Read into free space above the image. Reserve stack room and reject
    ; a full buffer because the file may have been truncated.
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
    jc bad_read
    cmp ax,cx
    jne read_complete
bad_read:
    jmp read_error
read_complete:
    mov bp,ax
    mov ah,3eh
    int 21h
    or byte ptr topic,0
    jnz topic_lookup
    jmp show_index
; BP bounds every scan. Match the whole key before its padding.
topic_lookup:
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
    je skip_padding
    cmp al,9
    je skip_padding
skip_char:
    cmp al,10
    je next_line
    cmp si,bp
    jae unknown
    lodsb
    jmp skip_char
skip_padding:
    cmp si,bp
    jae unknown
    lodsb
    cmp al,' '
    je skip_padding
    cmp al,9
    je skip_padding
    mov dx,si
    dec dx
    ; Print the summary from DX, followed by its display lines. Strip the
    ; single record-indent space while retaining option-column alignment.
    dec si
topic_line:
    call line_end
    call put_line
    cmp si,bp
    jae success
    mov al,[si]
    cmp al,' '
    jne topic_blank
    inc si
    jmp short topic_body
topic_blank:
    cmp al,13
    je topic_body
    cmp al,10
    jne success
topic_body:
    mov dx,si
    jmp topic_line
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
; DX follows the last drive or directory separator in the copied path.
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
; Write CX bytes at DS:DX to handle BX. Treat a short write as failure.
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

 ; Scan to the next physical line, including its LF in the output span.
line_end:
    cmp si,bp
    jae line_done
    lodsb
    cmp al,10
    jne line_end
line_done:
    ret

; Write [DX,SI) to standard output, preserving the database cursor.
put_line:
    mov cx,si
    sub cx,dx
    mov bx,1
    jmp write_count

show_index:
    ; Only pause when both standard handles are console devices. Pipes,
    ; files and NUL receive the complete index without keyboard reads.
    mov ax,4400h
    xor bx,bx
    int 21h
    jc index_start
    and dl,81h
    cmp dl,81h
    jne index_start
    inc bx
    mov ax,4400h
    int 21h
    jc index_start
    and dl,82h
    cmp dl,82h
    jne index_start
    ; BIOS returns the current text width in AH, including 40-column modes.
    mov ah,0fh
    int 10h
    xor al,al
    xchg ah,al
    mov columns,ax
index_start:
    mov dx,offset intro
    call print
    cmp columns,0
    je index_buffer
    mov ax,cx
    sub ax,2                  ; intro ends in CR/LF
    xor dx,dx
    div columns
    sub rows,ax               ; charge additional wrapped intro rows
index_buffer:
    mov si,offset buffer
    add bp,si
index_line:
    cmp si,bp
    jae index_done
    mov dx,si
    call line_end
    mov bx,dx
    cmp byte ptr [bx],' '
    jbe index_line
    ; Delay the prompt until another index entry actually exists.
    cmp columns,0
    je index_write
    ; A full-width line wraps even when CR/LF immediately follows it.
    mov ax,si
    sub ax,bx
    cmp byte ptr [si-1],10
    jne measure_row
    dec ax
    cmp byte ptr [si-2],13
    jne measure_row
    dec ax
measure_row:
    push dx
    xor dx,dx
    div columns
    pop dx
    inc ax
    cmp rows,ax
    jae count_row
    push ax
    push dx
    push si
    mov dx,offset moremsg
    call print
    mov ah,08h
    int 21h
    or al,al
    jnz key_done
    mov ah,08h
    int 21h
key_done:
    mov dx,offset newline
    call print
    pop si
    pop dx
    mov rows,23
    pop ax
count_row:
    sub rows,ax
index_write:
    call put_line
    jmp index_line
index_done:
    jmp success

columns dw 0
rows dw 22
newline db 13,10,0
pathname db 140 dup (0)
topic db 13 dup (0)
filename db 'DOSHELP.HLP',0
CR equ 13
LF equ 10
include help.cl1
buffer label byte
code ends
end start
