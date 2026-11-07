# MS-DOS 4.00 - RESTORE Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
MAPPER   ?= $(ROOT)/mapper
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
CL       = $(EMU2) $(SDKBIN)/cl.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
CONVERT  = $(EMU2) $(SDKBIN)/convert.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

C_OBJS   = restore.obj restpars.obj rtt1.obj rtt3.obj rtdo.obj rtdo1.obj rtold.obj \
           rtold1.obj rtnew.obj rtnew1.obj rtfile.obj rtfile1.obj
ASM_OBJS = _parse.obj _msgret.obj
MSGS     = restore.ctl

.PHONY: all clean

all: restore.com

$(MSGS): restore.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' restore.skl > /dev/null

$(ASM_OBJS): %.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

$(C_OBJS): %.obj: %.c $(wildcard *.h)
	$(CL) -c -AS -Os -Zp -I. -I'C:\include' -Fo$@ $< -- INCLUDE='C:\sdk\include' PATH='C:\sdk\bin'

restore.com: $(C_OBJS) $(ASM_OBJS) restore.lnk $(MAPPER)/mapper.lib
	$(LINK) @restore.lnk -- LIB='C:\sdk\lib'
	$(CONVERT) restore.exe restore.com
	rm -f restore.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
