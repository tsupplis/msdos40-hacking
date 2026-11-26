# UMBS.SYS
ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe

.PHONY: all clean
all: umbs.sys

umbs.obj: umbs.asm
	@echo | $(MASM) -Mx -t '$<,$@;'

umbs.sys: umbs.obj
	$(LINK) 'umbs.obj,umbs.exe,nul;'
	$(EXE2BIN) umbs.exe umbs.sys

clean:
	rm -f umbs.obj umbs.exe umbs.sys
