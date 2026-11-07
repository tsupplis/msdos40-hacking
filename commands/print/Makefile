# MS-DOS 4.00 - PRINT Makefile

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

OBJS     = print_r.obj print_rm.obj print_t.obj print_tm.obj
MSGS     = print.ctl print.cla

.PHONY: all clean

all: print.com

$(MSGS): print.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' print.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

print.com: $(OBJS) print.lnk
	$(LINK) @print.lnk
	$(CONVERT) print.exe
	rm -f print.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
