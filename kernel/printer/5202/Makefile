# MS-DOS 4.00 - 5202.CPI Makefile

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

all: 5202.cpi

5202.obj: 5202.asm
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

5202.cpi: 5202.obj
	$(LINK) '5202;'
	$(EXE2BIN) 5202.exe 5202.cpi
	rm -f 5202.exe

clean:
	rm -f *.obj *.cpi *.exe *.map *.lst
