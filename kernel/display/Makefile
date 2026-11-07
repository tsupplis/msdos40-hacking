# MS-DOS 4.00 - DISPLAY.SYS Makefile

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

OBJS     = display.obj init.obj parser.obj
MSGS     = display.ctl

all: display.sys ega.cpi lcd.cpi

$(MSGS): display.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' display.skl > /dev/null

$(OBJS): %.obj: %.asm $(MSGS) $(wildcard *.inc)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

display.sys: $(OBJS) display.lnk zero.dat
	$(LINK) @display.lnk
	$(EXE2BIN) display.exe display.sys < zero.dat
	rm -f display.exe

# code-page files are built by their own Makefiles and copied up
ega.cpi lcd.cpi: %.cpi:
	$(MAKE) -C $* $@
	cp $*/$@ $@

clean:
	rm -f *.obj *.sys *.cpi *.exe *.map *.lst *.ctl *.cl*
	$(MAKE) -C ega clean
	$(MAKE) -C lcd clean
