# MS-DOS 4.00 - COMP Makefile

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

OBJS     = comp1.obj comppar.obj compp.obj compsm.obj comp2.obj
MSGS     = comp.ctl comp.cl1 comp.cl2 comp.cla

.PHONY: all clean

all: comp.com

$(MSGS): comp.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' comp.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

comp.com: $(OBJS) comp.lnk
	$(LINK) @comp.lnk
	$(EXE2BIN) comp.exe comp.com
	rm -f comp.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
