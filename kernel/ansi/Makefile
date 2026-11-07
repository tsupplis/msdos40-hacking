# MS-DOS 4.00 - ANSI.SYS Makefile

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

OBJS     = ansi.obj ioctl.obj ansiinit.obj parser.obj
MSGS     = ansi.ctl

all: ansi.sys

$(MSGS): ansi.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' ansi.skl > /dev/null

$(OBJS): %.obj: %.asm $(MSGS) $(wildcard *.inc)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

ansi.sys: $(OBJS) ansi.lnk
	$(LINK) @ansi.lnk
	$(EXE2BIN) ansi.exe ansi.sys
	rm -f ansi.exe

clean:
	rm -f *.obj *.sys *.exe *.map *.lst *.ctl *.cl*
