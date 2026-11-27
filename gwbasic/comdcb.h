; RS232 Device Control Block Definition:
;
;   mneumonic offset    use
;   --------- ------    ---------------------------------------
	_DEVID=0D		;RS232 Channel ID (0..n)
	_BAUDR=1D		;baud rate (least significant byte 1st)
				;(0=disable device, 9600=9600 baud etc.)
	_BYTSZ=3D		;bits per byte (4..8)
	_PARIT=4D		;parity (0..4)=...(NONE, ODD, EVEN, MARK, SPACE)
	_STOPB=5D		;(0..2)= (1, 1.5, 2) stop bits
	_RLSTO=6D		;RLSD (rec. line signal detect) timeout
	_CTSTO=8D		;CTS (clear to send) timeout
	_DSRTO=10D		;DSR (data set ready) timeout
				;All timeout values are in milliseconds.
				;0=infinite, LSB is always 1st.
				;Support of Timeout Flags by BIOS is
				;optional.
	_CMFLG=12D		;Boolean attributes mask for this device
	_CMBIN=1O		;(0/1)=ASCII/BINARY (ASC option not in filename)
	_CMPE=4O		;report receive parity errors
	_CMRTS=2O		;non-zero=Suppress Request-To-Send (RS option)
	_CMCOD=20O		;non-zero=user specified ASC or BIN in filename
	_CMCTS=40O		;non-zero=CTS parm not defaulted
	_CMCLF=100O		;non-zero=Send line feed after CR
	_CMCRF=200O		;non-zero=last char sent was Carriage Return

;If COM filename contains "ASC", .CMBIN=0, .CMCOD=1
;If COM filename contains "BIN", .CMBIN=1, .CMCOD=1
;If COM filename contains neither "ASC" nor "BIN", .CMBIN=1, .CMCOD=0
;If COM filename contains both "ASC" and "BIN", Illegal Filename occurs

;COM DCB Entries which are only of interest to BASIC (Not OEM routines)
;
				;*********************************************
				;*** .CMPOS must immediately follow .CMWID ***
				;*********************************************
	_CMWID=13D		;device width (columns per line)
	_CMPOS=14D		;current column device is in **must follow .CMWID**
	_CMFDB=15D		;points to FDB for file (0=not opened)

	CDCBSZ=24D		;bytes per COM Device Control Block (room for growth)
