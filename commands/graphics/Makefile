# MS-DOS 4.00 - GRAPHICS Makefile

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

OBJS     = graphics.obj grint2fh.obj grpattrn.obj grctrl.obj grcpsd.obj grcolprt.obj \
           grbwprt.obj grinst.obj grparse.obj grparms.obj grload.obj grload2.obj grload3.obj
MSGS     = graphics.ctl

.PHONY: all clean

all: graphics.com

$(MSGS): graphics.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' graphics.skl > /dev/null

%.obj: %.asm $(MSGS) $(wildcard *.ext *.str *.equ)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

graphics.com: $(OBJS) graphics.lnk
	$(LINK) @graphics.lnk
	$(EXE2BIN) graphics.exe graphics.com
	rm -f graphics.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
