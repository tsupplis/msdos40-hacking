# MS-DOS 4.00 - COMMAND.COM Makefile

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

OBJS     = command1.obj command2.obj rucode.obj rdata.obj init.obj iparse.obj \
           uinit.obj tcode.obj tbatch.obj tbatch2.obj tfor.obj tcmd1a.obj tcmd1b.obj \
           tcmd2a.obj tcmd2b.obj tenv.obj tenv2.obj tmisc1.obj tmisc2.obj tpipe.obj \
           parse2.obj path1.obj path2.obj tucode.obj copy.obj copypr1.obj copypr2.obj \
           cparse.obj tparse.obj tprintf.obj tdata.obj tspc.obj

MSGS     = command.ctl command.cla command.clb command.clc command.cld command.cle \
           command.clf command.cl1 command.cl2 command.cl3 command.cl4

.PHONY: all clean

all: command.com

$(MSGS): command.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' command.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

command.com: $(OBJS) command.lnk
	$(LINK) @command.lnk
	$(EXE2BIN) command.exe command.com
	rm -f command.exe

clean:
	rm -f *.obj *.com *.exe *.map *.lst *.ctl *.cl*
