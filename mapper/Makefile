# MS-DOS 4.00 - Mapper Library Makefile

ROOT     ?= $(CURDIR)/..
SDKBIN   ?= $(ROOT)/sdk/bin
ASMINC   ?= $(ROOT)/asminc

EMU2     ?= emu2
MASM     ?= $(EMU2) $(SDKBIN)/masm.exe
LIB      ?= $(EMU2) $(SDKBIN)/lib.exe

AFLAGS   = -Mx -t -I$(ROOT)/mapper -I$(ASMINC)

OBJS = chdir.obj getver.obj f_first.obj set_tod.obj \
       write.obj beep.obj mkdir.obj exit.obj delete.obj getcntry.obj \
       f_close.obj open.obj read.obj rmdir.obj qcurdir.obj qcurdsk.obj \
       qverify.obj qfilemod.obj sverify.obj sfilemod.obj lseek.obj \
       sfileinf.obj close.obj allocseg.obj freeseg.obj sel_disk.obj \
       qfsinfo.obj f_next.obj getmsg.obj get_tod.obj charin.obj \
       flushbuf.obj devconfg.obj reallseg.obj putmsg.obj execpgm.obj \
       qhandtyp.obj cwait.obj kbdgstat.obj kbdsstat.obj casemap.obj \
       dbcs.obj ioctl.obj sighand.obj error.obj setint24.obj \
       qfileinf.obj scurpos.obj scrollup.obj wchstra.obj scntry.obj \
       setfsinf.obj gmachmod.obj

.PHONY: all clean

all: mapper.lib

%.obj: %.asm macros.inc
	$(MASM) $(AFLAGS) '$<,$@;'

f_first.obj: f_first.asm macros.inc find.inc
	$(MASM) $(AFLAGS) '$<,$@;'

f_close.obj: f_close.asm macros.inc find.inc
	$(MASM) $(AFLAGS) '$<,$@;'

f_next.obj: f_next.asm macros.inc find.inc
	$(MASM) $(AFLAGS) '$<,$@;'

charin.obj: charin.asm macros.inc kbd.inc
	$(MASM) $(AFLAGS) '$<,$@;'

qfsinfo.obj: qfsinfo.asm macros.inc error.inc
	$(MASM) $(AFLAGS) '$<,$@;'

sighand.obj: sighand.asm macros.inc msc.inc
	$(MASM) $(AFLAGS) '$<,$@;'

getmsg.obj: getmsg.asm macros.inc messages.inc
	$(MASM) $(AFLAGS) '$<,$@;'

mapper.lib: $(OBJS)
	rm -f mapper.lib mapper.bak mapper.lst mapper_build.lbr
	@printf "mapper.lib\r\ny\r\n" > mapper_build.lbr
	@for obj in $(OBJS); do \
		if [ "$$obj" = "gmachmod.obj" ]; then \
			printf "+$$obj\r\n" >> mapper_build.lbr; \
		else \
			printf "+$$obj&\r\n" >> mapper_build.lbr; \
		fi \
	done
	@printf "mapper.lst;\r\n" >> mapper_build.lbr
	$(LIB) @mapper_build.lbr
	rm -f mapper_build.lbr

clean:
	rm -f *.obj *.lib *.bak *.lst *.map mapper_build.lbr
