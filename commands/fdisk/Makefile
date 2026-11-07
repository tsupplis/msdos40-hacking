# MS-DOS 4.00 - FDISK Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
MAPPER   ?= $(ROOT)/mapper
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
CL       = $(EMU2) $(SDKBIN)/cl.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe
NOSRVBLD = $(EMU2) $(SDKBIN)/nosrvbld.exe
MENUBLD  = $(EMU2) $(SDKBIN)/menubld.exe
DBOF     = $(EMU2) $(SDKBIN)/dbof.exe

COUNTRY  = usa-ms

C_OBJS   = main.obj mainmenu.obj d_menus.obj c_menus.obj fdisk.obj display.obj input.obj \
           tdisplay.obj vdisplay.obj space.obj partinfo.obj video.obj makepart.obj \
           int13.obj diskout.obj messages.obj fdparse.obj convert.obj global.obj fdiskm.obj
ASM_OBJS = reboot.obj bootrec.obj fdboot.obj _parse.obj _msgret.obj
MSGS     = fdisk.ctl

.PHONY: all clean

all: fdisk.exe

# --- generated sources ------------------------------------------------------
# menubld turns fdisk.msg + the country message file into the C menu tables
fdiskm.c: fdisk.msg $(MSGDIR)/$(COUNTRY).msg
	$(MENUBLD) fdisk.msg 'C:\messages\$(COUNTRY).msg'

fdisk5.cl1: fdisk5.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(NOSRVBLD) fdisk5.skl 'C:\messages\$(COUNTRY).msg' > /dev/null

$(MSGS): fdisk.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' fdisk.skl > /dev/null

# --- boot record stub: fdboot.asm -> fdboot.bin -> fdboot.inc (via dbof) -----
fdboot.obj: fdboot.asm fdisk5.cl1
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

fdboot.inc: fdboot.obj
	$(LINK) 'fdboot;'
	$(EXE2BIN) fdboot.exe fdboot.bin
	rm -f fdboot.exe
	$(DBOF) fdboot.bin fdboot.inc 600 200

# --- objects ----------------------------------------------------------------
reboot.obj _parse.obj _msgret.obj: %.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

bootrec.obj: bootrec.asm fdboot.inc
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

$(C_OBJS): %.obj: %.c $(wildcard *.h) fdiskm.c
	$(CL) -c -AS -Os -Zp -I. -I'C:\include' -Fo$@ $< -- INCLUDE='C:\sdk\include' PATH='C:\sdk\bin'

fdisk.exe: $(C_OBJS) $(ASM_OBJS) fdisk.lnk $(MAPPER)/mapper.lib
	$(LINK) @fdisk.lnk -- LIB='C:\sdk\lib'

clean:
	rm -f *.obj *.exe *.bin *.map *.lst *.ctl *.cl* fdboot.inc fdiskm.c
