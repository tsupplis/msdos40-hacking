# MS-DOS 4.00 - ASSIGN Makefile

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

OBJS     = assgmain.obj assgparm.obj
MSGS     = assign.ctl assign.cla assign.cl1 assign.cl2

.PHONY: all clean

all: assign.com

$(MSGS): assign.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' assign.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

assign.com: $(OBJS)
	$(LINK) 'assgmain.obj+assgparm.obj,assign.exe;'
	$(EXE2BIN) assign.exe assign.com
	rm -f assign.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
