# MS-DOS 4.00 - DISKCOMP Makefile

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

OBJS     = diskcomp.obj dcompsm.obj dcompp.obj dcomppar.obj compinit.obj
MSGS     = diskcomp.ctl diskcomp.cla diskcomp.cl1 diskcomp.cl2

.PHONY: all clean

all: diskcomp.com

$(MSGS): diskcomp.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' diskcomp.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

diskcomp.com: $(OBJS) diskcomp.lnk
	$(LINK) @diskcomp.lnk
	$(EXE2BIN) diskcomp.exe diskcomp.com
	rm -f diskcomp.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
