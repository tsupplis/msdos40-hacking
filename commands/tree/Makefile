# MS-DOS 4.00 - TREE Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = tree.obj treesysp.obj treesysm.obj treepar.obj
MSGS     = tree.ctl tree.cl1 tree.cl2 tree.cla

.PHONY: all clean

all: tree.com

$(MSGS): tree.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' tree.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

tree.com: $(OBJS) tree.lnk
	$(LINK) @tree.lnk
	$(EXE2BIN) tree.exe tree.com
	rm -f tree.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
