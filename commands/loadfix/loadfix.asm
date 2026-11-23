; LOADFIX runs a DOS executable with its PSP at segment 1000h or above.
; First-fit allocation lets us reserve every free conventional block below
; that boundary, including holes left by resident programs. The reservations
; belong to our PSP and DOS releases them when we exit, on success or error.
; Direct EXEC preserves the child's command tail and termination code.
code segment para public 'CODE'
assume cs:code,ds:code
org 100h
start:
        mov sp,offset stack_top
        cld
        xor cx,cx
        mov cl,ds:[80h]
        mov si,81h
skip_space:
        jcxz usage
        lodsb
        dec cx
        cmp al,' '
        je skip_space
        cmp al,9
        je skip_space
        dec si
        inc cx
        cmp word ptr [si],3f2fh
        jne prepare
        cmp cx,2
        jne prepare
        mov dx,offset syntax
        mov ah,9
        int 21h
        mov ax,4c00h
        int 21h
usage:
        mov dx,offset syntax
        jmp error
prepare:
        ; Isolate the executable name. Preserve the rest of the PSP command
        ; tail verbatim, including its leading delimiter and terminating CR.
        mov di,offset program
name_char:
        lodsb
        cmp al,' '
        je name_done
        cmp al,9
        je name_done
        cmp al,13
        je name_done
        cmp al,'/'
        je name_done
        cmp al,':'
        je qualified
        cmp al,5ch
        jne check_dot
qualified:
        mov explicit_path,1
        mov extension,0
check_dot:
        cmp al,'.'
        jne store_char
        mov extension,1
store_char:
        stosb
        loop name_char
        inc si                  ; step over the terminating CR
name_done:
        mov byte ptr [di],0
        cmp di,offset program
        je usage
        dec si
        ; Reuse the original argument bytes. The last character of the
        ; copied program name is now free to hold the child's length byte.
        mov [si-1],cl
        lea ax,[si-1]
        mov tail_off,ax
        mov tail_seg,ds
        mov fcb1_seg,ds
        mov fcb2_seg,ds
        ; Conventional DOS children may consume either of the two default
        ; FCBs instead of parsing their command tail (INT 21h function 29h).
        mov di,offset fcb1
        mov ax,2901h
        int 21h
        mov di,offset fcb2
        mov ax,2901h
        int 21h
        push ds
        pop es
        mov bx,(stack_top-start+100h+15)/16
        mov ah,4ah
        int 21h
        jc memory_error
        mov ax,5800h
        int 21h
        jc memory_error
        mov strategy,ax
        xor bx,bx               ; conventional memory, first fit
        mov ax,5801h
        int 21h
        jc memory_error
reserve:
        mov bx,1
        mov ah,48h
        int 21h
        jc reserve_error
        mov es,ax
        mov bx,1000h
        sub bx,ax
        jbe reached_boundary
        ; Grow to the boundary, or consume this low fragment and try again.
        mov ah,4ah
        int 21h
        jnc reserve
        cmp ax,8
        jne reserve_error
        mov ah,4ah              ; BX is the maximum size of this block
        int 21h
        jnc reserve
reserve_error:
        call restore_strategy
memory_error:
        mov dx,offset mem_err
        jmp error
reached_boundary:
        mov ah,49h              ; leave the first eligible block for EXEC
        int 21h
        jc reserve_error
        call restore_strategy
        jc memory_error
        ; Search the current directory first. A drive or directory in the
        ; operand suppresses PATH searching. COM precedes EXE for bare names.
        mov di,offset candidate
        call try_directory
        cmp explicit_path,0
        je search_path
        jmp not_found
search_path:
        mov es,ds:[2ch]
        xor di,di
next_var:
        cmp byte ptr es:[di],0
        je not_found
        mov si,offset path_key
        mov cx,5
        push di
        repe cmpsb
        pop di
        je have_path
        xor al,al
        mov cx,0ffffh
        repne scasb
        jmp next_var
have_path:
        add di,5
        mov path_cursor,di
        mov path_segment,es
next_directory:
        mov si,path_cursor
        mov es,path_segment
        mov di,offset candidate
copy_directory:
        mov al,es:[si]
        inc si
        cmp al,';'
        je end_directory
        or al,al
        jz end_directory
        ; Saturate at the limit and consume the rest of an overlong entry.
        cmp di,offset candidate+127
        jae copy_directory
        mov [di],al
        inc di
        jmp copy_directory
end_directory:
        mov path_cursor,si
        mov path_delimiter,al
        cmp di,offset candidate
        je after_directory
        cmp byte ptr [di-1],5ch
        je try_path
        cmp byte ptr [di-1],':'
        je try_path
        mov byte ptr [di],5ch
        inc di
try_path:
        call try_directory
after_directory:
        cmp path_delimiter,0
        jne next_directory
not_found:
        mov dx,offset missing_msg
        jmp error
exec_error:
        mov dx,offset exec_msg
error:
        mov ah,9
        int 21h
        mov ax,4c01h
        int 21h
restore_strategy proc near
        mov bx,strategy
        mov ax,5801h
        int 21h
        ret
restore_strategy endp

; Input DI points just beyond the directory prefix in candidate.
; Only a missing file/path permits trying another candidate. An existing
; program that fails to load must report failure without executing a namesake.
try_directory proc near
        push ds
        pop es
        mov si,offset program
append_name:
        cmp di,offset candidate+128
        jae try_done
        lodsb
        stosb
        or al,al
        jnz append_name
        cmp extension,0
        jne check_suffix
        cmp di,offset candidate+124
        ja try_done
        dec di
        push di
        mov si,offset com_ext
        mov cx,5
        rep movsb
        call try_exec
        pop di
        mov si,offset exe_ext
        mov cx,5
        rep movsb
exact_name:
        call try_exec
try_done:
        ret
check_suffix:
        ; DOS EXEC also treats arbitrary text as a COM image. Accept only
        ; executable extensions, even when the user names an existing file.
        cmp di,offset candidate+5
        jb try_done
        mov ax,[di-5]
        mov bx,[di-3]
        or ax,2020h
        or bx,2020h
        cmp ax,632eh            ; ".c"
        jne check_exe
        cmp bx,6d6fh            ; "om"
        je exact_name
        ret
check_exe:
        cmp ax,652eh            ; ".e"
        jne try_done
        cmp bx,6578h            ; "xe"
        je exact_name
        ret
try_directory endp

try_exec proc near
        mov dx,offset candidate
        mov bx,offset params
        mov ax,4b00h
        int 21h
        push cs
        pop ds
        push cs
        pop es
        jc load_error
        mov ah,4dh
        int 21h
        mov ah,4ch
        int 21h
load_error:
        cmp ax,2
        je missing
        cmp ax,3
        je missing
        jmp exec_error
missing:
        ret
try_exec endp

path_key db 'PATH='
com_ext db '.COM',0
exe_ext db '.EXE',0
CR equ 13
LF equ 10
include loadfix.cl1
strategy dw ?
explicit_path db 0
extension db 0
path_cursor dw ?
path_segment dw ?
path_delimiter db ?
params dw 0
tail_off dw ?
tail_seg dw ?
        dw offset fcb1
fcb1_seg dw ?
        dw offset fcb2
fcb2_seg dw ?
; DOS gives a COM program the free block at startup. Reserve scratch space
; by address only: the linked file ends here, and AH=4Ah retains the space.
workspace label byte
fcb1      equ workspace
fcb2      equ workspace+37
program   equ workspace+74
candidate equ program+128
stack_top equ candidate+128+256
code ends
end start
