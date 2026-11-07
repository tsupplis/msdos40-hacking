# MS-DOS 4.00 - BIOS (io.sys) Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
NOSRVBLD = $(EMU2) $(SDKBIN)/nosrvbld.exe

COUNTRY  = usa-ms

OBJS     = msbio1.obj mscon.obj msaux.obj mslpt.obj msclock.obj msdisk.obj \
           msbio2.obj mshard.obj msinit.obj sysinit1.obj sysconf.obj sysinit2.obj sysimes.obj

.PHONY: all clean

all: io.sys

msbio.cl1: msbio.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(NOSRVBLD) msbio.skl 'C:\messages\$(COUNTRY).msg' > /dev/null

msload.obj: msload.asm msbio.cl1
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

msload.com: msload.obj
	$(LINK) 'msload.obj,msload.exe,,,;'
	$(EXE2BIN) msload.exe msload.com
	rm -f msload.exe

%.obj: %.asm msbio.cl1
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

io.sys: $(OBJS) msload.com locscr msbio.lnk
	$(LINK) @msbio.lnk
	$(EXE2BIN) msbio.exe msbio.bin < locscr
	cat msload.com msbio.bin > io.sys
	rm -f msbio.exe msbio.bin

clean:
	rm -f *.obj *.sys *.com *.bin *.exe *.map *.lst *.cl*
