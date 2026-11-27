; Integer viewport geometry shared by the graphics statements and PC display.
        .radix 10
DSEG    segment public 'DATASG'
        public ViewActive,ViewX,ViewY,ClipLeft,ClipTop,ClipRight,ClipBottom
        public Extent,WindowActive
ViewActive db 0
WindowActive db 0
ViewX   dw 0                    ; Translation from viewport to hardware pixels.
ViewY   dw 0
ClipLeft dw 0                   ; Clip limits in viewport pixel coordinates.
ClipTop dw 0
ClipRight dw 0
ClipBottom dw 0
Extent  dw 0,0,0,0              ; X and Y at offsets 0 and 4, as in MBF pairs.
        extrn GXPOS:word,GYPOS:word
DSEG    ends
CSEG    segment public 'CODESG'
        assume cs:CSEG,ds:DSEG

; CX = screen width and DX = height, both consumed. In text mode the
; zero width gives Extent = -1, used by CheckGraphics. VIEW alone keeps WINDOW.
public ResetCoords,ClearView
ResetCoords:
        mov WindowActive,0
ClearView:
        mov ViewActive,0
        mov ViewX,0
        mov ViewY,0
        dec cx
        dec dx
        mov Extent,cx
        mov Extent+4,dx
        ret

; Cohen-Sutherland clipping in viewport pixels. A shared outcode also
; rejects filled rectangles wholly outside one edge. AX = mask for CX,DX.
Outcode:
        xor ax,ax
        cmp cx,ClipLeft
        jge CodeRight
        or al,1
CodeRight: cmp cx,ClipRight
        jle CodeTop
        or al,2
CodeTop: cmp dx,ClipTop
        jge CodeBottom
        or al,4
CodeBottom: cmp dx,ClipBottom
        jle CodeDone
        or al,8
CodeDone: ret

public BoxOutside,ClipSegment
BoxOutside:
        call Outcode
        xchg cx,GXPOS
        xchg dx,GYPOS
        push ax
        call Outcode
        pop bx
        xchg cx,GXPOS
        xchg dx,GYPOS
        test al,bl
        ret

ClipSegment:
        call BoxOutside
        jnz SegmentRejected
        or bl,al
        jz SegmentReady
        call Outcode
        test al,al
        jnz ClipEndpoint
        xchg cx,GXPOS
        xchg dx,GYPOS
        call Outcode
ClipEndpoint:
        test al,3
        jnz ClipHorizontal
        mov si,ClipTop
        test al,4
        jnz ClipAtY
        mov si,ClipBottom
ClipAtY:
        xchg cx,dx
        mov bx,GXPOS
        xchg bx,GYPOS
        mov GXPOS,bx
        call Intersect
        xchg cx,dx
        mov bx,GXPOS
        xchg bx,GYPOS
        mov GXPOS,bx
        jmp short ClipSegment
ClipHorizontal:
        mov si,ClipLeft
        test al,1
        jnz ClipAtX
        mov si,ClipRight
ClipAtX: call Intersect
        jmp short ClipSegment
SegmentRejected: stc
        ret
SegmentReady: clc
        ret

; CX = first X, DX = first Y, SI = crossed X edge. Unsigned magnitudes
; handle deltas between any two signed 16-bit endpoints (up to 65535).
Intersect:
        push dx
        mov ax,GYPOS
        cmp ax,dx
        pushf
        jge Rising
        xchg ax,dx
Rising: sub ax,dx
        mov bx,si
        mov di,GXPOS
        cmp di,cx
        jge IncreasingX
        sub bx,cx
        neg bx
        sub di,cx
        neg di
        jmp short Fraction
IncreasingX:
        sub bx,cx
        sub di,cx
Fraction:
        mul bx
        div di
        popf
        jge AddDelta
        neg ax
AddDelta:
        pop dx
        add dx,ax
        mov cx,si
        ret

CSEG ends
        end
