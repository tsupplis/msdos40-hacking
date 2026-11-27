; IBM PC asynchronous serial adapter. BASIC polls the UART at statement
; boundaries and during input. No interrupt vectors or PIC masks are changed.
        .radix 10
        include COMDCB.H

DSEG segment public 'DATASG'
; Word arrays are indexed by twice the zero-based BIOS port number.
PortBase dw 2 dup (0)
PortDCB  dw 2 dup (0)
SavedIER dw 2 dup (0)
RxSeg    dw 2 dup (0)
RxHead   dw 2 dup (0)
RxCount  dw 2 dup (0)
RxSize   dw 0
DSEG ends

CSEG segment public 'CODESG'
        assume cs:CSEG,ds:DSEG
        public SETCBF,INICOM,STACOM,RECCOM,SNDCOM,TRMCOM

; The startup mapper supplies the first free paragraph in CX and expects
; the total reservation in DX. Give each port its own /C-sized ring.
SETCBF: jnz BufferGiven
        mov dx,256
BufferGiven:
        mov RxSize,dx
        cmp dx,32752           ; Total plus the mapper's rounding must fit.
        ja BufferTooBig
        mov RxSeg,cx
        mov ax,dx
        add ax,15
        push cx
        mov cl,4
        shr ax,cl
        pop cx
        add ax,cx
        mov RxSeg+2,ax
        add dx,15
        and dx,0fff0h
        add dx,RxSize
        ret
BufferTooBig:
        stc
        ret

; AH = BASIC port number (0 or 1). BX = word index, DX = UART base.
SelectPort:
        xor bx,bx
        mov bl,ah
        shl bx,1
        mov dx,PortBase[bx]
        ret

; DI = parsed BASIC DCB. Validate framing before touching the UART.
; AH returns FFh for an invalid option, 6 for an unavailable device.
INICOM: push si
        push di
        push es
        mov al,_BYTSZ[di]
        sub al,5
        cmp al,3
        ja BadFormat
        mov ah,_PARIT[di]
        or ah,ah
        jz Framing
        cmp al,3               ; 3.23 rejects eight data bits plus parity.
        je BadFormat
        dec ah
        mov cl,4
        shl ah,cl
        or al,ah
        or al,8
Framing:
        cmp byte ptr _STOPB[di],0
        je FindRate
        or al,4
FindRate:
        mov ch,al              ; UART line control register.
        mov ax,_BAUDR[di]
        mov si,offset BaudTable
RateLoop:
        cmp ax,cs:[si]
        je RateFound
        add si,4
        cmp si,offset EndRates
        jb RateLoop
BadFormat:
        mov ah,0ffh
        jmp OpenReturn
RateFound:
        mov ah,_DEVID[di]
        call SelectPort
        mov ax,40h
        mov es,ax
        mov dx,es:[bx]         ; BIOS data area COM1/COM2 base addresses.
        or dx,dx
        jz PortMissing
        cmp RxSize,0
        je PortMissing
        mov PortBase[bx],dx
        add dx,5
        in al,dx
        cmp al,0ffh
        je PortMissing
        mov PortDCB[bx],di
        mov RxCount[bx],0
        mov RxHead[bx],0
        sub dx,2
        mov al,ch
        out dx,al              ; Clear DLAB to select the interrupt enable register.
        sub dx,2
        in al,dx
        mov byte ptr SavedIER[bx],al
        xor al,al
        out dx,al              ; Polled operation.
        add dx,2
        mov al,ch
        or al,80h
        out dx,al
        sub dx,3
        mov ax,cs:[si+2]
        out dx,al
        inc dx
        mov al,ah
        out dx,al
        add dx,2
        mov al,ch
        out dx,al
        add dx,2
        in al,dx               ; Discard a byte left pending by the previous open.
        test al,1
        jz ModemControl
        mov dx,PortBase[bx]
        in al,dx
ModemControl:
        mov dx,PortBase[bx]
        add dx,4
        mov al,0bh             ; DTR, RTS and OUT2.
        test byte ptr _CMFLG[di],_CMRTS
        jz StartPort
        and al,0fdh            ; RS suppresses RTS.
StartPort:
        out dx,al
        xor ah,ah
        jmp short OpenReturn
PortMissing:
        mov ah,6
OpenReturn:
        pop es
        pop di
        pop si
        ret
BaudTable dw 75,1536,110,1047,150,768,300,384,600,192,1200,96
          dw 1800,64,2400,48,4800,24,9600,12,19200,6
EndRates label word

; Drain received bytes into the ring. AH = GIOCOM error, or zero.
; BX = port index. Preserve SI, DI, ES and CX for the calling GIO routine.
PollRx: push si
        push di
        push es
        mov es,RxSeg[bx]
RxNext: mov dx,PortBase[bx]
        add dx,5
        in al,dx
        test al,2              ; Hardware overrun.
        jnz RxOverflow
        test al,4
        jz RxAvailable
        mov si,PortDCB[bx]
        test byte ptr _CMFLG[si],_CMPE
        jnz RxParity
RxAvailable:
        test al,1
        jz RxDone
        mov dx,PortBase[bx]
        in al,dx
        mov di,RxCount[bx]
        cmp di,RxSize
        jae RxOverflow
        add di,RxHead[bx]
        cmp di,RxSize
        jb RxStore
        sub di,RxSize
RxStore:
        mov es:[di],al
        inc RxCount[bx]
        jmp short RxNext
RxOverflow:
        mov ah,1
        jmp short RxReturn
RxParity:
        mov dx,PortBase[bx]
        in al,dx               ; Discard the byte that caused the error.
        mov ah,2
        jmp short RxReturn
RxDone: xor ah,ah
RxReturn:
        pop es
        pop di
        pop si
        ret

STACOM: push bx
        call SelectPort
        call PollRx
        mov dx,RxCount[bx]
        mov cx,RxSize
        sub cx,dx
        pop bx
        ret

; GIOCOM tests ZF for availability, including when the received byte is zero.
RECCOM: push bx
        push dx
        push di
        push es
        call SelectPort
        call PollRx
        or ah,ah
        jnz ReceiveExit
        cmp RxCount[bx],0
        je ReceiveExit
        mov es,RxSeg[bx]
        mov di,RxHead[bx]
        mov al,es:[di]
        inc di
        cmp di,RxSize
        jb ReceiveAdvance
        xor di,di
ReceiveAdvance:
        mov RxHead[bx],di
        dec RxCount[bx]
        or sp,sp               ; NZ: one byte delivered.
ReceiveExit:
        pop es
        pop di
        pop dx
        pop bx
        ret

; Wait up to CX milliseconds for one signal (mask in AH) at DX.
; A zero option disables the corresponding handshake. Use elapsed BIOS
; clock ticks so an absent peer cannot stall the interpreter indefinitely.
WaitSignal:
        jcxz SignalReady
        in al,dx
        test al,ah
        jnz SignalReady
        push bx
        push dx
        push ax
        mov ax,cx
        xor dx,dx
        mov bx,55
        div bx
        or dx,dx
        jz WholeTicks
        inc ax
WholeTicks:
        mov cx,ax
        pop ax
        pop dx
        mov bx,es:[6ch]
SignalPoll:
        in al,dx
        test al,ah
        jnz SignalUp
        push ax
        mov ax,es:[6ch]
        sub ax,bx
        cmp ax,cx
        pop ax
        jb SignalPoll
        pop bx
        stc
        ret
SignalUp:
        pop bx
SignalReady:
        clc
        ret

SNDCOM: push bx
        push cx
        push dx
        push si
        push es
        push ax
        call SelectPort
        mov si,PortDCB[bx]
        mov ax,40h
        mov es,ax
        add dx,6               ; Modem status.
        mov ah,10h
        mov cx,_CTSTO[si]
        call WaitSignal
        jc SendTimeout
        mov ah,20h
        mov cx,_DSRTO[si]
        call WaitSignal
        jc SendTimeout
        mov ah,80h
        mov cx,_RLSTO[si]
        call WaitSignal
        jc SendTimeout
        dec dx                 ; Line status: transmitter holding register empty.
        mov ah,20h
        mov cx,1000
        call WaitSignal
        jc SendTimeout
        mov dx,PortBase[bx]
        pop ax
        out dx,al
        xor ah,ah
        jmp short SendExit
SendTimeout:
        pop ax
        mov ah,3
SendExit:
        pop es
        pop si
        pop dx
        pop cx
        pop bx
        ret

TRMCOM: push bx
        push dx
        call SelectPort
        add dx,4
        xor al,al
        out dx,al              ; Drop modem control lines on CLOSE.
        sub dx,3
        mov al,byte ptr SavedIER[bx]
        out dx,al
        xor ah,ah
        pop dx
        pop bx
        ret

CSEG ends
        end
