; Native AT CMOS/BIOS and DOS date observations. The host seeds the RTC.
; Let the BIOS advance time through each midnight before reading the date.
code segment
assume cs:code,ds:code
start:
 push cs
 pop ds
 call show_date
 mov si,offset cases
 mov di,3
next_case:
 mov cx,[si]
 mov dx,[si+2]
 mov ah,2bh
 int 21h
 or al,al
 jnz failed
 mov cx,173bh                    ; 23:59:58.00
 mov dx,3a00h
 mov ah,2dh
 int 21h
 or al,al
 jnz failed
wait_midnight:
 mov ah,2ch
 int 21h
 or ch,ch
 jnz wait_midnight              ; bounded by host timeout
 add si,4
 call show_date
 ; Close a newly created file to capture DOS's FAT timestamp.
 mov dx,[si]
 xor cx,cx
 mov ah,3ch
 int 21h
 jc failed
 mov bx,ax
 mov dx,offset newline
 mov cx,2
 mov ah,40h
 int 21h
 jc failed
 mov ah,3eh
 int 21h
 jc failed
 add si,2
 dec di
 jnz next_case
 mov ah,0dh
 int 21h
 mov dx,offset passed
 jmp short report
failed:
 mov dx,offset bad
report:
 mov ah,9
 int 21h
 mov ax,4c00h
 int 21h
; Emit actual CX:DX so a DOS error can be distinguished from RTC data.
hexword proc near
 mov bx,ax
 mov cx,4
digit:
 rol bx,1
 rol bx,1
 rol bx,1
 rol bx,1
 mov dl,bl
 and dl,0fh
 add dl,'0'
 cmp dl,'9'
 jbe emit
 add dl,7
emit:
 mov ah,2
 int 21h
 loop digit
 ret
hexword endp
show_date proc near
 mov ah,2ah
 int 21h
 mov al,'D'
 call show_regs
 mov ah,4                      ; BIOS BCD century/year and month/day
 int 1ah
 jc failed
 mov al,'B'
 call show_regs
 ret
show_date endp
show_regs proc near
 push dx
 push cx
 mov dl,al
 mov ah,2
 int 21h
 pop ax
 call hexword
 pop ax
 call hexword
 mov dx,offset newline
 mov ah,9
 int 21h
 ret
show_regs endp
newline db 13,10,'$'
cases dw 1999,0c1fh,offset jan
      dw 2000,021ch,offset feb
      dw 2000,021dh,offset mar
jan db 'JAN.RTC',0
feb db 'FEB.RTC',0
mar db 'MAR.RTC',0
passed db 'RTC DONE',13,10,'$'
bad db 'RTC FAIL',13,10,'$'
code ends
stacksg segment stack
 dw 128 dup (?)
stacksg ends
end start
