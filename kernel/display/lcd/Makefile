# MS-DOS 4.00 - LCD.CPI Makefile

ROOT     ?= $(CURDIR)/../../..
SDKBIN   ?= $(ROOT)/sdk/bin
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

.PHONY: all clean

OBJS     = font-r3.obj 437-cpi.obj 850-cpi.obj 860-cpi.obj 863-cpi.obj 865-cpi.obj copyrigh.obj

all: lcd.cpi

$(OBJS): %.obj: %.asm
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

lcd.cpi: $(OBJS) lcd.lnk
	$(LINK) @lcd.lnk
	$(EXE2BIN) font-r3.exe lcd.cpi
	rm -f font-r3.exe

clean:
	rm -f *.obj *.cpi *.exe *.map *.lst
