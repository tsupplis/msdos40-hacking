# HIMEM.SYS
ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
MSGDIR   ?= $(ROOT)/messages
COUNTRY  = usa-ms
export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe

NOSRVBLD = $(EMU2) $(SDKBIN)/nosrvbld.exe

.PHONY: all clean
all: himem.sys

OBJS = himem.obj a20.obj hma.obj emb.obj move.obj init.obj

$(MSGDIR)/$(COUNTRY).idx: $(MSGDIR)/$(COUNTRY).msg
	$(MAKE) -C $(MSGDIR)

himem.cl1: himem.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(NOSRVBLD) himem.skl 'C:\messages\$(COUNTRY).msg' > /dev/null

init.obj: himem.cl1

%.obj: %.asm
	@echo | $(MASM) -Mx -t '$<,$@;'

himem.sys: $(OBJS)
	$(LINK) 'himem+a20+hma+emb+move+init,himem.exe,nul;'
	$(EXE2BIN) himem.exe himem.sys

clean:
	rm -f $(OBJS) himem.exe himem.sys himem.cl1
