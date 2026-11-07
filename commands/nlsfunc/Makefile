# MS-DOS 4.00 - NLSFUNC Makefile

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

OBJS     = nlsfunc.obj nlsparm.obj
MSGS     = nlsfunc.ctl nlsfunc.cla nlsfunc.cl1 nlsfunc.cl2

.PHONY: all clean

all: nlsfunc.exe

$(MSGS): nlsfunc.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' nlsfunc.skl > /dev/null

$(OBJS): %.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

nlsfunc.exe: $(OBJS)
	$(LINK) 'nlsfunc.obj+nlsparm.obj,nlsfunc.exe;'

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*
