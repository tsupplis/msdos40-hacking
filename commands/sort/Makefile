# MS-DOS 4.00 - SORT Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXEFIX   = $(EMU2) $(SDKBIN)/exefix.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = sort.obj sortmes.obj
MSGS     = sort.ctl sort.cla sort.cl1 sort.cl2

.PHONY: all clean

all: sort.exe

$(MSGS): sort.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' sort.skl > /dev/null

sort.obj: sort.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' 'sort.asm,sort.obj;'

sortmes.obj: sortmes.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' 'sortmes.asm,sortmes.obj;'

sort.exe: $(OBJS)
	$(LINK) 'sort.obj+sortmes.obj,sort.exe;'
	$(EXEFIX) sort.exe 1 1

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*
