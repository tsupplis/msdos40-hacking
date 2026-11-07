# MS-DOS 4.00 - COUNTRY.SYS Makefile

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

all: country.sys

mkcntry.obj: mkcntry.asm mkcntry.inc
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

mkcntry.exe: mkcntry.obj
	$(LINK) 'mkcntry;'

# mkcntry.exe writes country.sys into the current directory
country.sys: mkcntry.exe
	$(EMU2) mkcntry.exe

clean:
	rm -f *.obj *.sys *.exe *.map *.lst
