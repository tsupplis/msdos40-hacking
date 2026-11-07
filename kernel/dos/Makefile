# MS-DOS 4.00 - DOS Kernel (msdos.sys) Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc
COMMON   ?= $(ROOT)/common
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
NOSRVBLD = $(EMU2) $(SDKBIN)/nosrvbld.exe

COUNTRY  = usa-ms

DOS_OBJS = msdisp.obj mscode.obj time.obj getset.obj parse.obj misc.obj misc2.obj crit.obj \
           cpmio.obj cpmio2.obj fcbio.obj fcbio2.obj search.obj path.obj ioctl.obj delete.obj \
           rename.obj finfo.obj dup.obj create.obj open.obj dinfo.obj isearch.obj abort.obj \
           close.obj dircall.obj disk.obj disk2.obj disk3.obj dir.obj dir2.obj dev.obj \
           mknode.obj rom.obj fcb.obj msctrlc.obj fat.obj buf.obj proc.obj alloc.obj \
           srvcall.obj util.obj handle.obj macro.obj macro2.obj file.obj lock.obj share.obj \
           extattr.obj ifs.obj

COMMON_PREREQS = $(COMMON)/nibdos.obj $(COMMON)/const2.obj $(COMMON)/msdata.obj \
                 $(COMMON)/mstable.obj $(COMMON)/msdosme.obj

.PHONY: all clean

all: msdos.sys

$(COMMON)/%.obj:
	$(MAKE) -C $(COMMON) $*.obj

msdos.cl1 msdos.cl3: msdos.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(NOSRVBLD) msdos.skl 'C:\messages\$(COUNTRY).msg' > /dev/null

%.obj: %.asm msdos.cl1
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' -I'C:\common' '$<,$@;'

msdos.sys: $(DOS_OBJS) $(COMMON_PREREQS) msdos.lnk
	$(LINK) @msdos.lnk
	$(EXE2BIN) msdos.exe msdos.sys
	rm -f msdos.exe

clean:
	rm -f *.obj *.sys *.exe *.map *.lst *.cl*
