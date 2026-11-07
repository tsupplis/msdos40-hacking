# MS-DOS 4.00 - Common Compilation Units Makefile

ROOT     ?= $(CURDIR)/..
SDKBIN   ?= $(ROOT)/sdk/bin
SDKINC   ?= $(ROOT)/sdk/include
INCLUDE  ?= $(ROOT)/include
ASMINC   ?= $(ROOT)/asminc
KDOS     ?= $(ROOT)/kernel/dos

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     ?= emu2
MASM     ?= $(EMU2) $(SDKBIN)/masm.exe
CL       ?= $(EMU2) $(SDKBIN)/cl.exe

AFLAGS   = -Mx -t -I. -I'C:\asminc' -I'C:\kernel\dos'
CFLAGS   = -c -AS -Os -Zp -I. -I'C:\include'
CENV     = -- INCLUDE='C:\sdk\include' PATH='C:\sdk\bin'

ASM_OBJS = const2.obj msdata.obj msdosme.obj mstable.obj nibdos.obj
C_OBJS   = cds.obj dpb.obj errtst.obj kstring.obj string.obj sysvar.obj

OBJS     = $(ASM_OBJS) $(C_OBJS)

.PHONY: all clean

all: $(OBJS)

$(KDOS)/msdos.cl1 $(KDOS)/msdos.cl3:
	$(MAKE) -C $(KDOS) msdos.cl1

%.obj: %.asm $(KDOS)/msdos.cl1
	@echo | $(MASM) $(AFLAGS) '$<,$@;'

%.obj: %.c
	$(CL) $(CFLAGS) -Fo$@ $< $(CENV)

# Dependencies
errtst.obj: errtst.c $(INCLUDE)/types.h $(INCLUDE)/comsub.h $(INCLUDE)/dpb.h
sysvar.obj: sysvar.c $(INCLUDE)/types.h $(INCLUDE)/sysvar.h
cds.obj:    cds.c $(INCLUDE)/types.h $(INCLUDE)/sysvar.h $(INCLUDE)/cds.h $(INCLUDE)/dpb.h
dpb.obj:    dpb.c $(INCLUDE)/dpb.h $(ASMINC)/dpb.inc
kstring.obj: kstring.c
string.obj: string.c

nibdos.obj: nibdos.asm $(KDOS)/mssw.asm $(KDOS)/msconst.asm $(ASMINC)/dossym.inc $(ASMINC)/dosseg.asm $(ASMINC)/mshead.asm
const2.obj: const2.asm $(ASMINC)/dossym.inc $(ASMINC)/devsym.inc $(ASMINC)/dosseg.asm
msdata.obj: msdata.asm $(KDOS)/mssw.asm $(ASMINC)/dosseg.asm $(ASMINC)/dosmac.inc $(KDOS)/msinit.asm $(ASMINC)/devsym.inc $(ASMINC)/vector.inc $(ASMINC)/buffer.inc $(ASMINC)/dirent.inc $(ASMINC)/dpb.inc $(ASMINC)/curdir.inc $(ASMINC)/find.inc $(ASMINC)/pdb.inc $(ASMINC)/sf.inc $(ASMINC)/arena.inc $(ASMINC)/mi.inc
msdata2.obj: msdata2.asm $(ASMINC)/dosseg.asm
msdosme.obj: msdosme.asm $(KDOS)/mssw.asm $(ASMINC)/dosseg.asm $(KDOS)/dosmes.asm $(ASMINC)/dosmac.inc $(ASMINC)/intnat.inc $(ASMINC)/divmes.asm
mstable.obj: mstable.asm $(KDOS)/mssw.asm $(KDOS)/ms_table.asm $(ASMINC)/dossym.inc $(ASMINC)/dosseg.asm $(KDOS)/misc2.asm
printf.obj: printf.asm

clean:
	rm -f *.obj *.lst *.map
