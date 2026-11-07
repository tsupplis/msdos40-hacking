# MS-DOS 4.00 - FORMAT Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
MSGDIR   ?= $(ROOT)/messages
BOOTDIR  ?= $(ROOT)/boot

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
CONVERT  = $(EMU2) $(SDKBIN)/convert.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = display.obj forinit.obj forlabel.obj format.obj forproc.obj msfor.obj forexec.obj
MSGS     = format.ctl

.PHONY: all clean

all: format.com

# boot.cl1 and asminc/boot.inc come from the boot sector build
$(BOOTDIR)/boot.cl1 $(ASMINC)/boot.inc:
	$(MAKE) -C $(BOOTDIR)

boot.cl1: $(BOOTDIR)/boot.cl1
	cp $< $@

$(MSGS): format.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' format.skl > /dev/null

%.obj: %.asm $(MSGS) $(wildcard *.inc)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

msfor.obj: boot.cl1 $(ASMINC)/boot.inc

format.com: $(OBJS) format.lnk
	$(LINK) @format.lnk
	$(CONVERT) format.exe
	rm -f format.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
