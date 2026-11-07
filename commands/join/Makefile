# MS-DOS 4.00 - JOIN Makefile

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
SDKINC   ?= $(ROOT)/sdk/include
INCLUDE  ?= $(ROOT)/include
ASMINC   ?= $(ROOT)/asminc
COMMON   ?= $(ROOT)/common
MAPPER   ?= $(ROOT)/mapper
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
CL       = $(EMU2) $(SDKBIN)/cl.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe

COUNTRY  = usa-ms

OBJS     = join.obj _msgret.obj _parse.obj
MSGS     = join.ctl

.PHONY: all clean

all: join.exe

$(MSGS): join.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' join.skl > /dev/null

%.obj: %.asm $(MSGS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

join.obj: join.c $(MSGS)
	$(CL) -c -AS -Os -Zp -I. -I'C:\include' -Fo$@ $< -- INCLUDE='C:\sdk\include' PATH='C:\sdk\bin'

join.exe: $(OBJS) join.lnk $(COMMON)/errtst.obj $(COMMON)/sysvar.obj $(COMMON)/cds.obj $(COMMON)/dpb.obj $(MAPPER)/mapper.lib
	$(LINK) @join.lnk -- LIB='C:\sdk\lib'

clean:
	rm -f *.obj *.exe *.map *.lst *.ctl *.cl*
