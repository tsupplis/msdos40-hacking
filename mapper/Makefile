# MS-DOS 4.00 - Mapper Library Makefile

ROOT     ?= $(CURDIR)/..
SDKBIN   ?= $(ROOT)/sdk/bin

export EMU2_DRIVE_C ?= $(ROOT)

EMU2     = emu2
MASM     = $(EMU2) $(SDKBIN)/masm.exe
LIB      = $(EMU2) $(SDKBIN)/lib.exe

AFLAGS   = -Mx -t -I. -I'C:\asminc'

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
	@echo | $(MASM) $(AFLAGS) '$<,$@;'

f_first.obj f_close.obj f_next.obj: find.inc
charin.obj: kbd.inc
qfsinfo.obj: error.inc
sighand.obj: msc.inc
getmsg.obj: messages.inc

mapper.lib: $(OBJS)
	rm -f mapper.lib mapper.bak mapper.lst mapper.lbr
	@printf "mapper.lib\r\ny\r\n" > mapper.lbr
	@for obj in $(OBJS); do \
		if [ "$$obj" = "gmachmod.obj" ]; then \
			printf "+$$obj\r\n" >> mapper.lbr; \
		else \
			printf "+$$obj &\r\n" >> mapper.lbr; \
		fi \
	done
	@printf "mapper.lst;\r\n" >> mapper.lbr
	$(LIB) @mapper.lbr
	rm -f mapper.lbr

clean:
	rm -f *.obj *.lib *.bak *.lst *.map mapper.lbr
