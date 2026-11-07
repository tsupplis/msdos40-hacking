# MS-DOS 4.00 - FC Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
COMMON   ?= $(ROOT)/common

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
CL       = $(EMU2) $(SDKBIN)/cl.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe

ASM_OBJS = getl.obj itoupper.obj maxmin.obj move.obj string.obj xtab.obj messages.obj
C_OBJS   = fc.obj error.obj fgetl.obj ntoi.obj update.obj

.PHONY: all clean

all: fc.exe

$(ASM_OBJS): %.obj: %.asm
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

$(C_OBJS): %.obj: %.c $(wildcard *.h)
	$(CL) -c -AS -Os -Zp -I. -I'C:\include' -Fo$@ $< -- INCLUDE='C:\sdk\include' PATH='C:\sdk\bin'

$(COMMON)/%.obj:
	$(MAKE) -C $(COMMON) $*.obj

fc.exe: $(C_OBJS) $(ASM_OBJS) $(COMMON)/kstring.obj fc.lnk
	$(LINK) @fc.lnk -- LIB='C:\sdk\lib'

clean:
	rm -f *.obj *.exe *.map *.lst
