# MS-DOS 4.00 - SYS Makefile

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

OBJS     = sys1.obj sys2.obj syssr.obj
MSGS     = sys.ctl sys.cla sys.cl1 sys.cl2

.PHONY: all clean

all: sys.com

$(MSGS): sys.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' sys.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

sys.com: $(OBJS) sys.lnk
	$(LINK) @sys.lnk
	$(EXE2BIN) sys.exe sys.com
	rm -f sys.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
