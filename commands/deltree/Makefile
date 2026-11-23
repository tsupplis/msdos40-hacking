# MS-DOS 4.00 - DELTREE Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
CL       = $(EMU2) $(SDKBIN)/cl.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

ASM_OBJS = _msgret.obj
MSGS     = deltree.ctl

.PHONY: all clean

all: deltree.exe

$(MSGDIR)/$(COUNTRY).idx: $(MSGDIR)/$(COUNTRY).msg
	$(MAKE) -C $(MSGDIR)

$(MSGS): deltree.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' deltree.skl > /dev/null

$(ASM_OBJS): %.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

deltree.obj: deltree.c $(MSGS)
	$(CL) -c -AS -Os -Zp -I. -I'C:\include' -Fo$@ $< -- INCLUDE='C:\sdk\include' PATH='C:\sdk\bin'

deltree.exe: deltree.obj $(ASM_OBJS) deltree.lnk
	$(LINK) @deltree.lnk -- LIB='C:\sdk\lib'

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*
