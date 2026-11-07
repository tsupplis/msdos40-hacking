# MS-DOS 4.00 - RECOVER Makefile

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

CONVERT  = $(EMU2) $(SDKBIN)/convert.exe

OBJS     = recdisp.obj recinit.obj recproc.obj recover.obj
MSGS     = recover.ctl recover.cla recover.cl1 recover.cl2

.PHONY: all clean

all: recover.com

$(MSGS): recover.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' recover.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

recover.com: $(OBJS) recover.lnk
	$(LINK) @recover.lnk
	$(CONVERT) recover.exe
	rm -f recover.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
