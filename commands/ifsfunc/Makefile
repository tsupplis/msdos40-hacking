# MS-DOS 4.00 - IFSFUNC Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
COMMON   ?= $(ROOT)/common
KDOS     ?= $(ROOT)/kernel/dos
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = ifssess.obj ifsdir.obj ifsfile.obj ifshand.obj ifsdev.obj ifsutil.obj \
           ifserror.obj ifsfdos.obj ifsinit.obj ifsflink.obj
MSGS     = ifsfunc.ctl
SHARED   = $(COMMON)/nibdos.obj $(COMMON)/const2.obj $(COMMON)/msdata.obj \
           $(COMMON)/mstable.obj $(COMMON)/msdosme.obj \
           $(KDOS)/msdisp.obj $(KDOS)/mscode.obj

.PHONY: all clean

all: ifsfunc.exe

$(MSGS): ifsfunc.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' ifsfunc.skl > /dev/null

$(OBJS): %.obj: %.asm $(MSGS) $(wildcard *.inc)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' -I'C:\kernel\dos' '$<,$@;'

$(COMMON)/%.obj:
	$(MAKE) -C $(COMMON) $*.obj

$(KDOS)/%.obj:
	$(MAKE) -C $(KDOS) $*.obj

ifsfunc.exe: $(OBJS) $(SHARED) ifsfunc.lnk
	$(LINK) @ifsfunc.lnk

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*
