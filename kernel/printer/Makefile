# MS-DOS 4.00 - PRINTER.SYS Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

.PHONY: all clean

OBJS     = cpspm10.obj cpsfont3.obj prtint2f.obj cpspi07.obj parser.obj
MSGS     = printer.ctl

# 4201.cpi and 4208.cpi are prebuilt binaries shipped in the source tree
all: printer.sys 5202.cpi

$(MSGS): printer.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' printer.skl > /dev/null

$(OBJS): %.obj: %.asm $(MSGS) $(wildcard *.inc)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

printer.sys: $(OBJS) printer.lnk zero.dat
	$(LINK) @printer.lnk
	$(EXE2BIN) printer.exe printer.sys < zero.dat
	rm -f printer.exe

5202.cpi:
	$(MAKE) -C 5202 $@
	cp 5202/$@ $@

clean:
	rm -f *.obj *.sys 5202.cpi *.exe *.map *.lst *.ctl *.cl*
	$(MAKE) -C 5202 clean
