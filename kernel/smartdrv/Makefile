# MS-DOS 4.00 - SMARTDRV.SYS Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
NOSRVBLD = $(EMU2) $(SDKBIN)/nosrvbld.exe

COUNTRY  = usa-ms

.PHONY: all clean

# flush13 (flush13.c + fl13/flmes) is a separate utility, not part of the
# original default target, so it is not built here.

all: smartdrv.sys

smartdrv.obj: smartdrv.asm $(wildcard *.asm)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

smartdrv.exe: smartdrv.obj
	$(LINK) 'smartdrv,,smartdrv/M;'

smartdrv.sys: smartdrv.exe
	$(EXE2BIN) smartdrv.exe smartdrv.sys

clean:
	rm -f *.obj *.sys *.exe *.map *.lst
