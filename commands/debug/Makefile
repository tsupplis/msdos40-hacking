# MS-DOS 4.00 - DEBUG Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
CONVERT  = $(EMU2) $(SDKBIN)/convert.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = debug.obj debcom1.obj debcom2.obj debcom3.obj debasm.obj debuasm.obj \
           deberr.obj debconst.obj debmes.obj debems.obj debdata.obj
MSGS     = debug.ctl

.PHONY: all clean

all: debug.com

$(MSGS): debug.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' debug.skl > /dev/null

$(OBJS): %.obj: %.asm $(MSGS) $(wildcard *.inc *.asm)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

debug.com: $(OBJS) debug.lnk
	$(LINK) @debug.lnk
	$(CONVERT) debug.exe
	rm -f debug.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
