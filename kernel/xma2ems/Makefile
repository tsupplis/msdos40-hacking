# MS-DOS 4.00 - XMA2EMS.SYS Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
NOSRVBLD = $(EMU2) $(SDKBIN)/nosrvbld.exe

COUNTRY  = usa-ms

.PHONY: all clean

all: xma2ems.sys

xma2ems.cl1: xma2ems.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(NOSRVBLD) xma2ems.skl 'C:\messages\$(COUNTRY).msg' > /dev/null

xma2ems.obj: xma2ems.asm xma2ems.cl1 $(wildcard *.inc)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

xma2ems.sys: xma2ems.obj
	$(LINK) 'xma2ems;'
	$(EXE2BIN) xma2ems.exe xma2ems.sys
	rm -f xma2ems.exe

clean:
	rm -f *.obj *.sys *.exe *.map *.lst *.cl*
