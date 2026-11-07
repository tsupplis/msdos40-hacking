# MS-DOS 4.00 - FILESYS Makefile

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

ASM_OBJS = _parse.obj _msgret.obj
MSGS     = filesys.ctl

.PHONY: all clean

all: filesys.exe

$(MSGS): filesys.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' filesys.skl > /dev/null

$(ASM_OBJS): %.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

filesys.obj: filesys.c parse.h msgret.h psdata.h $(MSGS)
	$(CL) -c -AS -Os -Zp -I. -I'C:\include' -Fo$@ $< -- INCLUDE='C:\sdk\include' PATH='C:\sdk\bin'

filesys.exe: filesys.obj $(ASM_OBJS)
	$(LINK) 'filesys+_parse+_msgret;' /NOI -- LIB='C:\sdk\lib'

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*
