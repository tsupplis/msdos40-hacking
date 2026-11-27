; Test character device. Control writes latch one byte for the next control read.
; Ordinary writes report out of paper to exercise DOS critical-error handling.
bits 16
org 0
dd -1
dw 0c000h
dw strategy, interrupt
db 'ERRTEST '
req dw 0,0
strategy:
 mov [cs:req],bx
 mov [cs:req+2],es
 retf
interrupt:
 push es
 push bx
 push ax
 les bx,[cs:req]
 mov al,[es:bx+2]
 mov word [es:bx+3],0100h
 test al,al
 jnz .operation
 mov word [es:bx+14],last
 mov [es:bx+16],cs
 jmp short .done
.operation:
 cmp al,3
 je .read
 cmp al,12
 je .write
 cmp al,8
 je .fault
 cmp al,9
 je .fault
 jmp short .done
.write:
 cmp word [es:bx+18],0
 je .done
 mov word [es:bx+18],1
 les bx,[es:bx+14]
 mov al,[es:bx]
 mov [cs:control],al
 jmp short .done
.read:
 cmp word [es:bx+18],0
 je .done
 mov word [es:bx+18],1
 les bx,[es:bx+14]
 mov al,[cs:control]
 mov [es:bx],al
 jmp short .done
.fault:
 mov word [es:bx+18],0
 mov word [es:bx+3],8109h
.done:
 pop ax
 pop bx
 pop es
 retf
control db 81
last:
