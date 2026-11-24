# MS-DOS 4.00 - APPEND Makefile

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

OBJS     = append.obj
MSGS     = append.ctl

.PHONY: all clean

all: append.exe

$(MSGS): append.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' append.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

append.exe: helptest.obj $(OBJS)
	$(LINK) 'append.obj+helptest.obj,append.exe;'

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*

HELP_TOPIC = APPEND
HELP_SEG = cseg
HELP_CLASS = -Dnamedclass
include $(ROOT)/common/helptest.mk
