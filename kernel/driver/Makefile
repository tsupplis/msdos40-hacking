# MS-DOS 4.00 - DRIVER.SYS Makefile

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

MSGS     = driver.ctl

all: driver.sys

$(MSGS): driver.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' driver.skl > /dev/null

driver.obj: driver.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

driver.sys: driver.obj driver.lnk
	$(LINK) @driver.lnk
	$(EXE2BIN) driver.exe driver.sys
	rm -f driver.exe

clean:
	rm -f *.obj *.sys *.exe *.map *.lst *.ctl *.cl*
