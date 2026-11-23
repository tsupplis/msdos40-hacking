ROOT ?= $(CURDIR)/../..
SDKBIN ?= $(ROOT)/sdk/bin
export EMU2_DRIVE_C ?= $(ROOT)

.PHONY: all clean
all: loadfix.com

loadfix.obj: loadfix.asm
	@echo | emu2 $(SDKBIN)/masm.exe -Mx -t 'loadfix.asm,loadfix.obj;'

loadfix.com: loadfix.obj
	emu2 $(SDKBIN)/link.exe 'loadfix;'
	emu2 $(SDKBIN)/exe2bin.exe loadfix.exe loadfix.com
	rm -f loadfix.exe

clean:
	rm -f loadfix.obj loadfix.exe loadfix.com loadfix.map
