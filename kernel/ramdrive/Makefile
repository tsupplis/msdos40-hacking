# MS-DOS 4.00 - RAMDRIVE.SYS Makefile

ROOT     ?= $(CURDIR)/../..
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

OBJS     = ramdrive.obj messages.obj

all: ramdrive.sys

$(OBJS): %.obj: %.asm $(wildcard *.inc)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

ramdrive.sys: $(OBJS) ramdrive.lnk
	$(LINK) @ramdrive.lnk
	$(EXE2BIN) ramdrive.exe ramdrive.sys
	rm -f ramdrive.exe

clean:
	rm -f *.obj *.sys *.exe *.map *.lst
