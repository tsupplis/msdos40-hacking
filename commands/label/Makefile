# MS-DOS 4.00 - LABEL Makefile

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

OBJS     = label.obj labelm.obj
MSGS     = labl.ctl

.PHONY: all clean

all: label.com

$(MSGS): labl.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' labl.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

label.com: $(OBJS) label.lnk
	$(LINK) @label.lnk
	$(EXE2BIN) label.exe label.com
	rm -f label.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
