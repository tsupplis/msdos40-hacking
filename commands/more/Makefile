# MS-DOS 4.00 - MORE Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = more.obj
MSGS     = more.ctl more.cla more.cl1 more.cl2

.PHONY: all clean

all: more.com

$(MSGS): more.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' more.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

more.com: $(OBJS) more.lnk
	$(LINK) @more.lnk
	$(EXE2BIN) more.exe more.com
	rm -f more.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
