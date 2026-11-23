ROOT ?= $(CURDIR)/../..
SDKBIN ?= $(ROOT)/sdk/bin
export EMU2_DRIVE_C ?= $(ROOT)

.PHONY: all clean
all: help.com

MSGDIR ?= $(ROOT)/messages

$(MSGDIR)/usa-ms.idx: $(MSGDIR)/usa-ms.msg
	$(MAKE) -C $(MSGDIR)

help.cl1: help.skl $(MSGDIR)/usa-ms.msg $(MSGDIR)/usa-ms.idx
	emu2 $(SDKBIN)/nosrvbld.exe help.skl 'C:\messages\usa-ms.msg' > /dev/null

help.obj: help.asm help.cl1
	@echo | emu2 $(SDKBIN)/masm.exe -Mx -t 'help.asm,help.obj;'

help.com: help.obj
	emu2 $(SDKBIN)/link.exe 'help;'
	emu2 $(SDKBIN)/exe2bin.exe help.exe help.com
	rm -f help.exe

clean:
	rm -f help.obj help.exe help.com help.map help.cl1
