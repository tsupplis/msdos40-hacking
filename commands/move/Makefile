# MS-DOS 4.00 - MOVE Makefile

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
MSGS     = move.ctl

.PHONY: all clean

all: move.exe

$(MSGDIR)/$(COUNTRY).idx: $(MSGDIR)/$(COUNTRY).msg
	$(MAKE) -C $(MSGDIR)

$(MSGS): move.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' move.skl > /dev/null

$(ASM_OBJS): %.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

move.obj: move.c $(ROOT)/include/showhelp.h $(MSGS)
	$(CL) -c -AS -Os -Zp -I. -I'C:\include' -Fo$@ $< -- INCLUDE='C:\sdk\include' PATH='C:\sdk\bin'

move.exe: showhelp.obj move.obj $(ASM_OBJS) move.lnk
	$(LINK) @move.lnk -- LIB='C:\sdk\lib'

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*

include $(ROOT)/common/showhelp.mk

showhelp.obj: $(ROOT)/common/showhelp.asm $(ROOT)/common/showhelp.inc showhelp.cl1
	@echo | $(MASM) -Mx -t -I. -I'C:\common' 'C:\common\showhelp.asm,showhelp.obj;'
