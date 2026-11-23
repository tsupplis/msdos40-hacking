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
COMMON_PREREQS = $(COMMON)/nibdos.obj $(COMMON)/const2.obj $(COMMON)/msdata.obj $(COMMON)/msdosme.obj
MSGS     = share.ctl

.PHONY: all clean

all: share.exe

$(MSGS): share.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' share.skl > /dev/null

$(OBJS): %.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

# Let common check its assembly includes even when the objects already exist.
.PHONY: check-common
check-common: | $(MSGDIR)/$(COUNTRY).idx
	$(MAKE) -C $(COMMON) $(notdir $(COMMON_PREREQS))

$(COMMON_PREREQS): check-common ;

$(MSGDIR)/$(COUNTRY).idx: $(MSGDIR)/$(COUNTRY).msg
	$(MAKE) -C $(MSGDIR) $(COUNTRY).idx

share.exe: $(OBJS) share.lnk $(COMMON_PREREQS)
	$(LINK) @share.lnk

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*
