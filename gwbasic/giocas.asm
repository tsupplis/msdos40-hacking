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
        extrn GETBYT:near,CassetteMotor:near
PUBLIC MOTOR
MOTOR:  jnz MotorArgument
        mov dl,MotorOn
        xor dl,1
        jmp short SetMotor
MotorArgument:
        call GETBYT
        or dl,dl
        jz SetMotor
        mov dl,1
SetMotor:
        mov MotorOn,dl
        jmp CassetteMotor

CSEG	ENDS
	END
