# MS-DOS 4.00 - Boot Sector Makefile

ROOT     ?= $(CURDIR)/..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     ?= emu2
MASM     ?= $(EMU2) $(SDKBIN)/masm.exe
LINK     ?= $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  ?= $(EMU2) $(SDKBIN)/exe2bin.exe
NOSRVBLD ?= $(EMU2) $(SDKBIN)/nosrvbld.exe
DBOF     ?= $(EMU2) $(SDKBIN)/dbof.exe

COUNTRY  = usa-ms

.PHONY: all clean

all: msboot.bin bootsec.bin $(ASMINC)/boot.inc

boot.cl1: boot.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(NOSRVBLD) boot.skl 'C:\messages\$(COUNTRY).msg' > /dev/null

msboot.obj: msboot.asm boot.cl1
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

msboot.bin: msboot.obj
	$(LINK) 'msboot.obj,msboot.exe;'
	$(EXE2BIN) msboot.exe msboot.bin
	rm -f msboot.exe

bootsec.bin: msboot.bin
	dd if=msboot.bin of=bootsec.bin bs=1 skip=31744 count=512 2>/dev/null

boot.inc: msboot.bin
	$(DBOF) msboot.bin boot.inc 7c00 200

$(ASMINC)/boot.inc: boot.inc
	cp boot.inc $(ASMINC)/boot.inc

clean:
	rm -f *.obj *.bin *.exe *.inc *.cl1 *.map *.lst
	rm -f $(ASMINC)/boot.inc
