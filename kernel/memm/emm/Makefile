# MS-DOS 4.00 - EMMLIB.LIB (EMM functions library used by EMM386.SYS)

ROOT     ?= $(CURDIR)/../../..
SDKBIN   ?= $(ROOT)/sdk/bin

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
CL       = $(EMU2) $(SDKBIN)/cl.exe
LIB      = $(EMU2) $(SDKBIN)/lib.exe

# high memory allocation switched off, as in the original makefile
HIFLAG   = /DNOHIMEM
AFLAGS   = /Mx /t /DI386 /i'C:\kernel\memm\memm' $(HIFLAG)
CFLAGS   = /ASw /G2 /Oat /Gs /Ze /Zl /Fc /c

.PHONY: all clean

COBJS    = emmfunct.obj emm40.obj
AOBJS    = emmp.obj emmsup.obj emmdisp.obj emmdata.obj emminc.obj
OBJS     = $(COBJS) $(AOBJS)

AINC     = ../memm/vdmseg.inc ../memm/vdmsel.inc emmdef.inc

all: emmlib.lib

$(COBJS): %.obj: %.c emm.h
	$(CL) $(CFLAGS) /Fo$@ $< -- PATH='C:\sdk\bin' || { rm -f $@; exit 1; }

$(AOBJS): %.obj: %.asm $(AINC)
	@echo | $(MASM) $(AFLAGS) '$<,$@;' || { rm -f $@; exit 1; }

# the original librarian line adds emminc.obj to nothing (it is only assembled)
emmlib.lib: $(OBJS)
	rm -f emmlib.lib emmlib.lbr
	printf 'emmlib.lib\r\ny\r\n+emmfunct.obj &\r\n+emm40.obj &\r\n+emmp.obj &\r\n+emmsup.obj &\r\n+emmdisp.obj &\r\n+emmdata.obj\r\nemmlib.lst;\r\n' > emmlib.lbr
	$(LIB) @emmlib.lbr > /dev/null || { rm -f $@; exit 1; }
	rm -f emmlib.lbr

clean:
	rm -f *.obj *.lib *.lst *.lbr *.bak
