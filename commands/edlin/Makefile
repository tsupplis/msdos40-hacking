# MS-DOS 4.00 - EDLIN Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
CONVERT  = $(EMU2) $(SDKBIN)/convert.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = edlin.obj edlcmd1.obj edlcmd2.obj edlmes.obj edlparse.obj
MSGS     = edlin.ctl edlin.cla edlin.clb edlin.cl1 edlin.cl2

.PHONY: all clean

all: edlin.com

$(MSGS): edlin.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' edlin.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

edlin.com: $(OBJS) edlin.lnk
	$(LINK) @edlin.lnk
	$(CONVERT) edlin.exe
	rm -f edlin.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
