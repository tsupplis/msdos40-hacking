; Shared startup check for commands with a DOS PSP. The build places this
; module in the caller's code segment (also usable by single-segment COMs).
; No arguments. A normal invocation resumes with its registers intact.
ifdef shareclass
helpseg segment byte public 'SHARE'
else
ifdef namedclass
helpseg segment byte public 'CODE'
else
helpseg segment byte public
endif
endif
        assume cs:helpseg, ds:helpseg
        public _check_help
_check_help proc near
        pushf
        push ax
        push bx
        push cx
        push dx
        push si
        push ds
        mov ah,62h
        int 21h
        mov ds,bx
        mov si,81h
        cld
ifdef helpalone
        mov dl,1                ; remaining operands belong to the child
else
        xor dl,dl
endif
        call help_argument
        jc launch_help
        pop ds
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        popf
        ret
launch_help:
        ; This path terminates. Move the stack beside the launcher before
        ; shrinking the PSP block, even for programs built with EXE2BIN.
        call help_position
help_position:
        pop ax
        sub ax,offset help_position
        mov cl,4
        shr ax,cl
        mov dx,cs
        add ax,dx
        push ax
        mov dx,offset help_stack_setup
        push dx
        retf                    ; normalize group-relative CS to this segment
help_stack_setup:
        mov ax,cs
        mov ss,ax
        mov sp,offset help_stack_end
        mov es,bx
        sub ax,bx
        mov bx,offset help_stack_end
        add bx,15
        mov cl,4
        shr bx,cl
        add bx,ax
        mov ah,4ah
        int 21h
        push cs
        pop ds
        mov ax,offset help_topic
        push ax
        call _show_help
_check_help endp

topic_string macro name
help_topic db '&name',0
endm
topic_string %helpcmd
include helparg.inc
CR equ 13
LF equ 10
include showhelp.inc
        dw 128 dup (?)
help_stack_end label byte
helpseg ends
end
