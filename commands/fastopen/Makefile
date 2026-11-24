# MS-DOS 4.00 - FASTOPEN Makefile

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

OBJS     = fastopen.obj fastseek.obj fastinit.obj fastp.obj fastsm.obj
MSGS     = fastopen.ctl fastopen.cla fastopen.cl1 fastopen.cl2

.PHONY: all clean

all: fastopen.exe

$(MSGS): fastopen.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' fastopen.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

fastopen.exe: helptest.obj $(OBJS) fastopen.lnk
	$(LINK) @fastopen.lnk

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*

HELP_TOPIC = FASTOPEN
HELP_SEG = CSEG_INIT
HELP_CLASS = -Dnamedclass
include $(ROOT)/common/helptest.mk
