# MS-DOS 4.00 - MODE Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = main.obj scrntab.obj modescrn.obj rescode.obj modecom.obj modeprin.obj \
           modevid.obj modeleng.obj modeecho.obj modecp.obj display.obj typamat.obj \
           invoke.obj parshell.obj modepars.obj modemes.obj
MSGS     = mode.ctl

.PHONY: all clean

all: mode.com

$(MSGS): mode.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' mode.skl > /dev/null

$(OBJS): %.obj: %.asm $(MSGS) $(wildcard *.inc *.stc)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

mode.com: $(OBJS) mode.lnk
	$(LINK) @mode.lnk
	$(EXE2BIN) mode.exe mode.com
	rm -f mode.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
