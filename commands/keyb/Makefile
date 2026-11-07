# MS-DOS 4.00 - KEYB Makefile

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

OBJS     = keyb.obj parser.obj keybcmd.obj keybtbbl.obj commsubs.obj keybi2f.obj \
           keybi48.obj keybcpsd.obj keybi9.obj keybi9c.obj
MSGS     = keyb.ctl

.PHONY: all clean

all: keyb.com

$(MSGS): keyb.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' keyb.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

keyb.com: $(OBJS) keyb.lnk
	$(LINK) @keyb.lnk
	$(EXE2BIN) keyb.exe keyb.com
	rm -f keyb.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
