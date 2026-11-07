# MS-DOS 4.00 - SHARE Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
COMMON   ?= $(ROOT)/common
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = gshare.obj gshare2.obj sharesr.obj sharelnk.obj
MSGS     = share.ctl

.PHONY: all clean

all: share.exe

$(MSGS): share.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' share.skl > /dev/null

$(OBJS): %.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

$(COMMON)/%.obj:
	$(MAKE) -C $(COMMON) $*.obj

share.exe: $(OBJS) share.lnk $(COMMON)/nibdos.obj $(COMMON)/const2.obj $(COMMON)/msdata.obj $(COMMON)/msdosme.obj
	$(LINK) @share.lnk

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*
