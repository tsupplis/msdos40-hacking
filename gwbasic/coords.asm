; GW-BASIC viewport and window coordinates. The rasterizer uses viewport
; pixels. WINDOW maps BASIC single-precision values to those integer pixels.
        .radix 10
DSEG    segment public 'DATASG'
        public ViewActive,ViewX,ViewY,ClipLeft,ClipTop,ClipRight,ClipBottom
        public Extent,WindowActive,WorldPos
ViewActive db 0
WindowActive db 0
ViewX   dw 0                    ; Translation from viewport to hardware pixels.
ViewY   dw 0
ClipLeft dw 0                   ; Clip limits in viewport pixel coordinates.
ClipTop dw 0
ClipRight dw 0
ClipBottom dw 0
Extent  dw 0,0,0,0              ; X and Y at offsets 0 and 4, as in MBF pairs.
WorldPos dd 2 dup (0)
Origin  dd 2 dup (0)            ; World coordinate at pixel zero on each axis.
Span    dd 2 dup (0)            ; Signed world span, negative for Cartesian Y.
UnitsPerPixel dd 2 dup (0)
ScaleBy dd 2 dup (0)            ; Pixels per world unit.
        extrn GRPACX:word,GRPACY:word,GXPOS:word,GYPOS:word
DSEG    ends
CSEG    segment public 'CODESG'
        assume cs:CSEG,ds:DSEG
        extrn FRCINT:near,CONSIH:near,MAKINT:near
        extrn MOVMF:near,MOVFM:near,MOVRF:near,MOVFR:near
        extrn FSUB:near,FADD:near,FDIV:near,FMULT:near,FCOMP:near,VALSNG:near

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

public RefreshScale

; Keep the axis index and the other MBF operand across the string move.
LoadSingle:
        push di
        push cx
        call MOVFM
        pop cx
        pop di
        ret
StoreSingle:
        push di
        call MOVMF
        pop di
        ret

; DI points to four writable MBF singles (x1,y1,x2,y2). AX is
; 1 for WINDOW SCREEN, 0 for Cartesian Y. Preserve BX. Carry means an empty axis.
public SetWindow
SetWindow:
        push bx
        push ax
        xor ax,ax               ; X always increases to the right.
        call OrderWorld
        pop ax
        jc WindowDone
        xor ax,1                ; Cartesian Y decreases down the screen.
        add di,4
        call OrderWorld
        jc WindowDone
        mov bx,di               ; Y endpoints, then X four bytes earlier.
        push bx
        sub bx,4
        xor di,di
        call InstallAxis
        pop bx
        mov di,4
        call InstallAxis
        mov WindowActive,1
        call RefreshScale
        call SyncWorld
        clc
WindowDone:
        pop bx
        ret

; Put the endpoint corresponding to pixel zero first.
OrderWorld:
        push ax
        push di
        mov bx,di
        call LoadSingle
        mov cx,word ptr [di+10]
        mov dx,word ptr [di+8]
        call FCOMP
        pop di
        mov cl,al
        pop ax
        je InvalidWorld
        test cl,cl
        js Ascending
        xor al,1
Ascending:
        test al,al
        jz WorldOrdered
        mov ax,word ptr [di]
        xchg ax,word ptr [di+8]
        mov word ptr [di],ax
        mov ax,word ptr [di+2]
        xchg ax,word ptr [di+10]
        mov word ptr [di+2],ax
WorldOrdered: ret               ; TEST above cleared carry.
InvalidWorld: stc               ; Equal endpoints.
        ret

; BX points to the first endpoint of the axis, DI selects X (0) or Y (4).
InstallAxis:
        push bx
        call LoadSingle
        lea bx,Origin[di]
        call StoreSingle
        pop bx
        mov dx,[bx+8]
        mov cx,[bx+10]
        push di
        call FSUB               ; Last endpoint minus first.
        pop di
        lea bx,Span[di]
        jmp MOVMF

RefreshScale:
        cmp WindowActive,0
        je ScaleDone
        xor di,di
        call ScaleAxis
        mov di,4
ScaleAxis:
        push di
        mov bx,Extent[di]
        call CONSIH
        call MOVRF
        pop di
        lea bx,Span[di]
        call LoadSingle
        push di
        call FDIV
        pop di
        lea bx,ScaleBy[di]
        call StoreSingle
        push di
        mov bx,Extent[di]
        call CONSIH
        pop di
        mov cx,word ptr Span[di+2]
        mov dx,word ptr Span[di]
        push di
        call FDIV
        pop di
        lea bx,UnitsPerPixel[di]
        jmp MOVMF
ScaleDone: ret

; FAC -> pixel BX, or pixel BX -> world FAC. DI selects X (0) or Y (4).
public WorldPixel,PixelWorld
WorldPixel:
        push di
        call MOVRF
        lea bx,Origin[di]
        call LoadSingle
        call FSUB
        pop di
        mov cx,word ptr ScaleBy[di+2]
        mov dx,word ptr ScaleBy[di]
        call FMULT
        jmp FRCINT
PixelWorld:
        push di
        call CONSIH
        pop di
        mov cx,word ptr UnitsPerPixel[di+2]
        mov dx,word ptr UnitsPerPixel[di]
        push di
        call FMULT
        pop di
        mov cx,word ptr Origin[di+2]
        mov dx,word ptr Origin[di]
        call FADD
        jmp VALSNG

public SyncWorld,HomeCoords
SyncWorld:
        cmp WindowActive,0
        je ScaleDone
        xor di,di
        mov bx,GRPACX
        call PixelWorld
        mov bx,offset WorldPos
        call StoreSingle
        mov di,4
        mov bx,GRPACY
        call PixelWorld
        mov bx,offset WorldPos+4
        jmp MOVMF
HomeCoords:
        mov bx,Extent
        inc bx
        shr bx,1
        mov GRPACX,bx
        mov bx,Extent+4
        inc bx
        shr bx,1
        mov GRPACY,bx
        jmp SyncWorld

; Map the MBF single in CX:DX using PMAP selector AL (0..3).
; Return the BASIC numeric result with BX preserved.
public MapCoordinate
MapCoordinate:
        push bx
        push ax
        call MOVFR
        call VALSNG
        pop ax
        xor di,di
        test al,1
        jz MapAxis
        mov di,4
MapAxis:
        cmp Extent,-1
        je MapText
        cmp WindowActive,0
        je MapInteger
        test al,2
        jnz MapInverse
        call WorldPixel
        jmp short MapResult
MapInverse:
        call FRCINT
        call PixelWorld
        pop bx
        ret
MapText: xor bx,bx
        jmp short MapResult
MapInteger: call FRCINT
MapResult: call MAKINT
        pop bx
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
