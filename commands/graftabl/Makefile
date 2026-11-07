# MS-DOS 4.00 - GRAFTABL Makefile

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

OBJS     = grtab.obj grtabp.obj grtabsm.obj grtabpar.obj grtabhan.obj grtabus.obj \
           grtabno.obj grtabpo.obj grtabcf.obj grtabml.obj
MSGS     = graftabl.ctl

.PHONY: all clean

all: graftabl.com

$(MSGS): graftabl.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' graftabl.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

graftabl.com: $(OBJS) graftabl.lnk
	$(LINK) @graftabl.lnk
	$(EXE2BIN) graftabl.exe graftabl.com
	rm -f graftabl.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
