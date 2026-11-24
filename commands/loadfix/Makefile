ROOT ?= $(CURDIR)/../..
SDKBIN ?= $(ROOT)/sdk/bin
MSGDIR ?= $(ROOT)/messages
COUNTRY = usa-ms
export EMU2_DRIVE_C ?= $(ROOT)

.PHONY: all clean
all: loadfix.com

$(MSGDIR)/$(COUNTRY).idx: $(MSGDIR)/$(COUNTRY).msg
	$(MAKE) -C $(MSGDIR)

loadfix.cl1: loadfix.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	emu2 $(SDKBIN)/nosrvbld.exe loadfix.skl 'C:\messages\$(COUNTRY).msg' > /dev/null

loadfix.obj: loadfix.asm loadfix.cl1 $(ROOT)/common/showhelp.inc showhelp.cl1
	@echo | emu2 $(SDKBIN)/masm.exe -Mx -t -I'C:\common' 'loadfix.asm,loadfix.obj;'

loadfix.com: loadfix.obj
	emu2 $(SDKBIN)/link.exe 'loadfix;'
	emu2 $(SDKBIN)/exe2bin.exe loadfix.exe loadfix.com
	rm -f loadfix.exe

clean:
	rm -f loadfix.obj loadfix.exe loadfix.com loadfix.map loadfix.cl1 showhelp.cl1

include $(ROOT)/common/showhelp.mk
