# MS-DOS 4.00 - SELECT Makefile
#
# Outputs: select.exe  select.com  select.dat  select.hlp

ROOT     ?= $(CURDIR)/../..
SDKBIN   ?= $(ROOT)/sdk/bin
FDISK    ?= $(ROOT)/commands/fdisk
MSGDIR   ?= $(ROOT)/messages

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
CL       = $(EMU2) $(SDKBIN)/cl.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
LIB      = $(EMU2) $(SDKBIN)/lib.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe
COMPRESS = $(EMU2) $(SDKBIN)/compress.com
ASC2HLP  = $(EMU2) $(SDKBIN)/asc2hlp.exe

COUNTRY  = usa-ms
MSGS     = select.ctl
INCS     = $(wildcard *.inc *.mac *.equ)

# --- select.exe ---------------------------------------------------------------
ASM_OBJS = select0.obj select1.obj select2.obj select2a.obj select3.obj select4.obj \
           select5.obj select5a.obj select6.obj select7.obj select8.obj select9.obj \
           routines.obj routine2.obj gen_coms.obj intvec.obj ckdisp.obj scn_parm.obj \
           prn_def.obj var.obj caservic.obj input.obj initmem.obj mparse.obj \
           mod_copy.obj s_disply.obj bridge.obj asm2c.obj
C_OBJS   = get_stat.obj global.obj int13.obj
# services.lib members (each is an independent object in the library)
SVC_OBJS = selquit.obj selchild.obj services.obj get_help.obj selserv.obj

.PHONY: all clean

all: select.exe select.com select.dat select.hlp

$(MSGS): select.skl $(MSGDIR)/$(COUNTRY).msg $(MSGDIR)/$(COUNTRY).idx
	$(BUILDMSG) 'C:\messages\$(COUNTRY)' select.skl > /dev/null

$(ASM_OBJS) $(SVC_OBJS) sstub.obj: %.obj: %.asm $(MSGS) $(INCS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

$(C_OBJS): %.obj: %.c $(wildcard *.h)
	$(CL) -c -AS -Os -Zp -I. -I'C:\include' -Fo$@ $< -- INCLUDE='C:\sdk\include' PATH='C:\sdk\bin'

# bootrec.obj is the FDISK boot record, built by the fdisk Makefile
bootrec.obj: $(FDISK)/bootrec.obj
	cp $< $@

$(FDISK)/bootrec.obj:
	$(MAKE) -C $(FDISK) bootrec.obj

services.lib: $(SVC_OBJS)
	rm -f services.lib services.bak services.lst services.lbr
	@printf "services.lib\r\ny\r\n" > services.lbr
	@for obj in $(SVC_OBJS); do \
		if [ "$$obj" = "selserv.obj" ]; then \
			printf "+$$obj\r\n" >> services.lbr; \
		else \
			printf "+$$obj &\r\n" >> services.lbr; \
		fi \
	done
	@printf "services.lst;\r\n" >> services.lbr
	$(LIB) @services.lbr
	rm -f services.lbr

# /NOE: symbols defined in the sources supersede library routines
select.exe: $(ASM_OBJS) $(C_OBJS) bootrec.obj services.lib select.lnk
	$(LINK) /NOE @select.lnk -- LIB='C:\sdk\lib'

# --- select.com (stub) --------------------------------------------------------
select.com: sstub.obj
	$(LINK) 'sstub;'
	$(EXE2BIN) sstub.exe select.com
	rm -f sstub.exe

# --- select.dat (panel data, compressed) --------------------------------------
panel.inf: usa.inf
	cp usa.inf panel.inf

panels.obj colors.obj scroll.obj sel-pan.obj: %.obj: %.asm panel.inf $(INCS)
	@echo | $(MASM) -Mx -t -I. -I'C:\asminc' '$<,$@;'

sel-pan.exe: sel-pan.obj panels.obj colors.obj scroll.obj sel-pan.lnk
	$(LINK) @sel-pan.lnk -- LIB='C:\sdk\lib'

# compress.com takes no arguments: it reads sel-pan.dat and writes select.dat
select.dat: sel-pan.exe
	$(EXE2BIN) sel-pan.exe sel-pan.dat
	$(COMPRESS) < /dev/null

# --- select.hlp ---------------------------------------------------------------
select.hlp: usa.txt
	rm -f select.hlp
	$(ASC2HLP) usa.txt select.hlp > /dev/null

clean:
	rm -f *.obj *.exe *.com *.lib *.lbr *.lst *.bak *.map *.ctl *.cl* \
	      sel-pan.dat select.dat select.hlp panel.inf
