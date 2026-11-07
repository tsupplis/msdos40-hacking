# MS-DOS 4.00 - EMM386.SYS (production driver only)
#
# The original makefile also had EMM386.COM and a debug EMM386D build (both
# commented out upstream); the debug one needs ..\deb386\buglib.lib which is
# not part of the released tree, so only the production driver is built.

ROOT     ?= $(CURDIR)/../../..
SDKBIN   ?= $(ROOT)/sdk/bin

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
CL       = $(EMU2) $(SDKBIN)/cl.exe

# HIFLAG = -DNOHIMEM turns high memory allocation off (as upstream)
HIFLAG   = -DNOHIMEM
AFLAGS   = -Mx -t -DI386 -DNoBugMode $(HIFLAG)
AINC     = -I. -I'C:\kernel\memm\emm'

.PHONY: all clean emmlib

AOBJS    = memm386.obj elimfunc.obj emm.obj emmmes.obj emminit.obj memmonf.obj \
           init.obj m_state.obj rom_srch.obj ppage.obj allocmem.obj inittab.obj \
           shiphi.obj extpool.obj vdminit.obj i286.obj i386.obj tabdef.obj \
           trapdef.obj vmtrap.obj vminst.obj elimtrap.obj iotrap.obj a20trap.obj \
           oemproc.obj initepg.obj vminit.obj em286ll.obj em386ll.obj moveb.obj \
           maplin.obj retreal.obj rrtrap.obj errhndlr.obj ekbd.obj util.obj \
           initdeb.obj
OBJS     = $(AOBJS) mapdma.obj

INCS     = $(wildcard *.inc *.equ) ../emm/emmdef.inc

all: emm386.sys

# EMMLIB.LIB is built by the sibling directory
../emm/emmlib.lib:
	$(MAKE) -C ../emm

$(AOBJS): %.obj: %.asm $(INCS)
	@echo | $(MASM) $(AFLAGS) $(AINC) '$<,$@;' || { rm -f $@; exit 1; }

mapdma.obj: mapdma.c
	$(CL) /ASw /G2 /Oat /Gs /Ze /Zl /Fc /c /Fo$@ $< -- PATH='C:\sdk\bin' || { rm -f $@; exit 1; }

emm386.sys: $(OBJS) ../emm/emmlib.lib emm386.lnk
	$(LINK) /NOI @emm386.lnk
	rm -f emm386.sys
	mv emm386.exe emm386.sys

clean:
	rm -f *.obj *.sys *.exe *.map *.lst *.bak
