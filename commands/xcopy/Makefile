# MS-DOS 4.00 - XCOPY Makefile

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

OBJS     = xcopy.obj xcopypar.obj xcpyinit.obj
MSGS     = xcopy.ctl xcopy.cl1 xcopy.cl2 xcopy.cla

.PHONY: all clean

all: xcopy.exe

$(MSGS): xcopy.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' xcopy.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

xcopy.exe: $(OBJS) xcopy.lnk
	$(LINK) @xcopy.lnk

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*
