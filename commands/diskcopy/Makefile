# MS-DOS 4.00 - DISKCOPY Makefile

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

OBJS     = diskcopy.obj dcopysm.obj dcopyp.obj dcopypar.obj copyinit.obj
MSGS     = diskcopy.ctl diskcopy.cla diskcopy.cl1 diskcopy.cl2

.PHONY: all clean

all: diskcopy.com

$(MSGS): diskcopy.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' diskcopy.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

diskcopy.com: $(OBJS) diskcopy.lnk
	$(LINK) @diskcopy.lnk
	$(EXE2BIN) diskcopy.exe diskcopy.com
	rm -f diskcopy.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
