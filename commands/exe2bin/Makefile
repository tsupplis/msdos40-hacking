# MS-DOS 4.00 - EXE2BIN Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = display.obj e2binit.obj
MSGS     = exe2bin.ctl exe2bin.cla exe2bin.cl1 exe2bin.cl2

.PHONY: all clean

all: exe2bin.exe

$(MSGS): exe2bin.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' exe2bin.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

exe2bin.exe: $(OBJS) exe2bin.lnk
	$(LINK) @exe2bin.lnk

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*
