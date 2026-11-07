# MS-DOS 4.00 - BACKUP Makefile

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

ASM_OBJS = _parse.obj _msgret.obj
MSGS     = backup.ctl

.PHONY: all clean

all: backup.com

$(MSGS): backup.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' backup.skl > /dev/null

$(ASM_OBJS): %.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

# backup is compiled without optimisation (-Od), as in the original build
backup.obj: backup.c backpars.h backup.h $(MSGS)
	$(CL) -c -AS -Od -Zp -I. -I'C:\include' -Fo$@ $< -- INCLUDE='C:\sdk\include' PATH='C:\sdk\bin'

backup.com: backup.obj $(ASM_OBJS) $(MAPPER)/mapper.lib
	$(LINK) '/NOE backup+_parse+_msgret,backup,nul,C:\mapper\mapper+C:\sdk\lib\comsubs;' -- LIB='C:\sdk\lib'
	$(CONVERT) backup.exe backup.com
	rm -f backup.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
