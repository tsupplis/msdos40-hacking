# MS-DOS 4.00 - EGA.CPI Makefile

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

OBJS     = cpi-head.obj 437-cpi.obj 850-cpi.obj 860-cpi.obj 863-cpi.obj 865-cpi.obj copyrigh.obj

all: ega.cpi

$(OBJS): %.obj: %.asm $(wildcard *.asm)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

ega.cpi: $(OBJS) ega.lnk
	$(LINK) @ega.lnk
	$(EXE2BIN) cpi-head.exe ega.cpi
	rm -f cpi-head.exe

clean:
	rm -f *.obj *.cpi *.exe *.map *.lst
