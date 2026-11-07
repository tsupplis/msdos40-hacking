# MS-DOS 4.00 - VDISK.SYS Makefile

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

MSGS     = vdisk.ctl

all: vdisk.sys

$(MSGS): vdisk.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' vdisk.skl > /dev/null

vdisksys.obj: vdisksys.asm vdisksys.inc $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

vdisk.sys: vdisksys.obj vdisk.lnk
	$(LINK) @vdisk.lnk
	$(EXE2BIN) vdisk.exe vdisk.sys
	rm -f vdisk.exe

clean:
	rm -f *.obj *.sys *.exe *.map *.lst *.ctl *.cl*
