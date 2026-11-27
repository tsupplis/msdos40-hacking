; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   GIOCAS - Cassette Machine Independent Device Driver Code

COMMENT	*

--------- --- ---- -- ---------
COPYRIGHT (C) 1981 BY MICROSOFT
--------- --- ---- -- ---------

Written by:     Len Oorthuys

        *
	INCLUDE	GIO86U
	INCLUDE	MSDOSU
	.SALL


DSEG SEGMENT PUBLIC 'DATASG'
        assume ds:DSEG
MotorOn db 0
DSEG ENDS
        extrn CassetteMotor:near
        public ToggleMotor,SetMotor
ToggleMotor:
        mov dl,MotorOn
        xor dl,1
SetMotor:                       ; DL = 0 for off, nonzero for on.
        or dl,dl
        jz MotorReady
        mov dl,1
MotorReady:
        mov MotorOn,dl
        jmp CassetteMotor

CSEG	ENDS
	END
