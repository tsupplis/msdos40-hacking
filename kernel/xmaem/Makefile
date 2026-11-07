# MS-DOS 4.00 - XMAEM.SYS Makefile

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

OBJS     = indeini.obj indeexc.obj indeemu.obj indexma.obj indedma.obj indei15.obj \
           indeidt.obj indegdt.obj indemsg.obj indepat.obj

all: xmaem.sys

xmaem.cl1: xmaem.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(NOSRVBLD) xmaem.skl 'C:\messages\$(COUNTRY).msg' > /dev/null

$(OBJS): %.obj: %.asm xmaem.cl1 $(wildcard *.inc *.mac)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

# the link writes the finished driver directly (no exe2bin step)
xmaem.sys: $(OBJS) xmaem.lnk
	$(LINK) @xmaem.lnk

clean:
	rm -f *.obj xmaem.sys *.exe *.map *.lst *.cl*
