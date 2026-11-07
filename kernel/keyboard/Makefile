# MS-DOS 4.00 - KEYBOARD.SYS Makefile

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

OBJS     = kdfnow.obj kdfsp.obj kdfpo.obj kdffr120.obj kdffr189.obj kdfdk.obj \
           kdfsg.obj kdfge.obj kdfit141.obj kdfit142.obj kdfuk166.obj kdfuk168.obj \
           kdfsf.obj kdfbe.obj kdfnl.obj kdfno.obj kdfcf.obj kdfsv.obj kdfla.obj \
           kdfeof.obj

all: keyboard.sys

$(OBJS): %.obj: %.asm $(wildcard *.inc)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

keyboard.sys: $(OBJS) keyboard.lnk
	$(LINK) @keyboard.lnk
	$(EXE2BIN) keyboard.exe keyboard.sys
	rm -f keyboard.exe

clean:
	rm -f *.obj *.sys *.exe *.map *.lst
