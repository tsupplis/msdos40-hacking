# MS-DOS 4.00 - CHKDSK Makefile

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

OBJS     = chkdsk1.obj chkdsk2.obj chkproc.obj chkproc2.obj chkprmt.obj chkdisk.obj \
           chkfat.obj chkinit.obj chkdisp.obj
MSGS     = chkdsk.ctl

.PHONY: all clean

all: chkdsk.com

$(MSGS): chkdsk.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' chkdsk.skl > /dev/null

%.obj: %.asm $(MSGS) $(wildcard *.inc)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

chkdsk.com: $(OBJS) chkdsk.lnk
	$(LINK) @chkdsk.lnk
	$(CONVERT) chkdsk.exe
	rm -f chkdsk.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
