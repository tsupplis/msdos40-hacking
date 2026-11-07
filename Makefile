# MS-DOS 4.00 Rebuild Root Makefile

EMU2     = emu2
SDKBIN   = sdk/bin
SDKINC   = sdk/include
SDKLIB   = sdk/lib
ASMINC   = asminc
INCLUDE  = include

MASM     = $(EMU2) $(SDKBIN)/masm.exe
LINK     = $(EMU2) $(SDKBIN)/link.exe
LIB      = $(EMU2) $(SDKBIN)/lib.exe
CL       = $(EMU2) $(SDKBIN)/cl.exe
EXE2BIN  = $(EMU2) $(SDKBIN)/exe2bin.exe
BUILDIDX = $(EMU2) $(SDKBIN)/buildidx.exe
BUILDMSG = $(EMU2) $(SDKBIN)/buildmsg.exe
NOSRVBLD = $(EMU2) $(SDKBIN)/nosrvbld.exe
CONVERT  = $(EMU2) $(SDKBIN)/convert.exe
DBOF     = $(EMU2) $(SDKBIN)/dbof.exe
EXEFIX   = $(EMU2) $(SDKBIN)/exefix.exe
EXEMOD   = $(EMU2) $(SDKBIN)/exemod.exe
EXEPACK  = $(EMU2) $(SDKBIN)/exepack.exe
ASC2HLP  = $(EMU2) $(SDKBIN)/asc2hlp.exe
COMPRESS = $(EMU2) $(SDKBIN)/compress.com

MAPPER_OBJS = mapper/chdir.obj mapper/getver.obj mapper/f_first.obj mapper/set_tod.obj \
       mapper/write.obj mapper/beep.obj mapper/mkdir.obj mapper/exit.obj mapper/delete.obj mapper/getcntry.obj \
       mapper/f_close.obj mapper/open.obj mapper/read.obj mapper/rmdir.obj mapper/qcurdir.obj mapper/qcurdsk.obj \
       mapper/qverify.obj mapper/qfilemod.obj mapper/sverify.obj mapper/sfilemod.obj mapper/lseek.obj \
       mapper/sfileinf.obj mapper/close.obj mapper/allocseg.obj mapper/freeseg.obj mapper/sel_disk.obj \
       mapper/qfsinfo.obj mapper/f_next.obj mapper/getmsg.obj mapper/get_tod.obj mapper/charin.obj \
       mapper/flushbuf.obj mapper/devconfg.obj mapper/reallseg.obj mapper/putmsg.obj mapper/execpgm.obj \
       mapper/qhandtyp.obj mapper/cwait.obj mapper/kbdgstat.obj mapper/kbdsstat.obj mapper/casemap.obj \
       mapper/dbcs.obj mapper/ioctl.obj mapper/sighand.obj mapper/error.obj mapper/setint24.obj \
       mapper/qfileinf.obj mapper/scurpos.obj mapper/scrollup.obj mapper/wchstra.obj mapper/scntry.obj \
       mapper/setfsinf.obj mapper/gmachmod.obj

COMMON_ASM = common/const2.obj common/msdata.obj common/msdosme.obj common/mstable.obj common/nibdos.obj
COMMON_C   = common/cds.obj common/dpb.obj common/errtst.obj common/kstring.obj common/string.obj common/sysvar.obj

.PHONY: all foundation kernel bios dos command images messages common mapper boot edlin clean tools-check msdos

all: foundation kernel command edlin images

kernel: bios dos
	@echo "=== Sub-task 5: Kernel components (io.sys, msdos.sys) built successfully ==="

bios: messages
	@echo "--- Building BIOS (io.sys) ---"
	$(MAKE) -C kernel/bios

dos: messages common
	@echo "--- Building DOS Kernel (msdos.sys) ---"
	$(MAKE) -C kernel/dos

command: messages
	@echo "--- Building COMMAND.COM ---"
	$(MAKE) -C commands/command

edlin: messages
	@echo "--- Building EDLIN ---"
	$(MAKE) -C commands/edlin

kernel/bios/io.sys: bios
kernel/dos/msdos.sys: dos
commands/command/command.com: command

media/msdos40_base.img: boot/bootsec.bin kernel/bios/io.sys kernel/dos/msdos.sys commands/command/command.com
	@echo "--- Generating bootable floppy image: media/msdos40_base.img ---"
	mformat -f 1440 -C -B boot/bootsec.bin -i $@ ::
	mcopy -i $@ kernel/bios/io.sys ::IO.SYS
	mattrib -i $@ +s +h +r ::IO.SYS
	mcopy -i $@ kernel/dos/msdos.sys ::MSDOS.SYS
	mattrib -i $@ +s +h +r ::MSDOS.SYS
	mcopy -i $@ commands/command/command.com ::COMMAND.COM
	mdir -i $@ -a ::

images: media/msdos40_base.img

foundation: messages boot common mapper
	@echo "=== Sub-task 4: Foundation components built successfully ==="

messages: messages/usa-ms.idx

messages/usa-ms.idx: messages/usa-ms.msg
	$(BUILDIDX) messages/usa-ms.msg

boot: messages/usa-ms.idx boot/msboot.bin boot/bootsec.bin asminc/boot.inc

boot/boot.cl1: boot/boot.skl messages/usa-ms.idx
	$(NOSRVBLD) 'boot\boot.skl' 'messages\usa-ms.msg' > /dev/null

boot/msboot.obj: boot/msboot.asm boot/boot.cl1
	@echo | $(MASM) -Mx -t -Iboot -Iasminc 'boot/msboot.asm,$@;'

boot/msboot.bin: boot/msboot.obj
	$(LINK) 'boot\msboot.obj,boot\msboot.exe;'
	$(EXE2BIN) 'boot\msboot.exe' 'boot\msboot.bin'
	rm -f boot/msboot.exe

boot/bootsec.bin: boot/msboot.bin
	dd if=boot/msboot.bin of=boot/bootsec.bin bs=1 skip=31744 count=512 2>/dev/null

boot/boot.inc: boot/msboot.bin
	$(DBOF) 'boot\msboot.bin' 'boot\boot.inc' 7c00 200

asminc/boot.inc: boot/boot.inc
	cp boot/boot.inc asminc/boot.inc

# Common targets
common: $(COMMON_ASM) $(COMMON_C)

kernel/dos/msdos.cl1 kernel/dos/msdos.cl3: kernel/dos/msdos.skl messages/usa-ms.idx
	$(NOSRVBLD) 'kernel\dos\msdos.skl' 'messages\usa-ms.msg' > /dev/null

common/%.obj: common/%.asm asminc/boot.inc kernel/dos/msdos.cl3
	@echo | $(MASM) -Mx -t -Icommon -Iasminc -Ikernel/dos '$<,$@;'

common/%.obj: common/%.c
	$(CL) -c -AS -Os -Zp -Iinclude -Fo$@ $< -- INCLUDE=$(SDKINC) PATH=$(SDKBIN)

# Mapper library targets
mapper: mapper/mapper.lib

mapper/%.obj: mapper/%.asm
	@echo | $(MASM) -Mx -t -Imapper -Iasminc '$<,$@;'

mapper/mapper.lib: $(MAPPER_OBJS)
	rm -f mapper/mapper.lib mapper/mapper.bak mapper/mapper.lst mapper/mapper.lbr
	@printf "mapper\\mapper.lib\r\ny\r\n" > mapper/mapper.lbr
	@for obj in $(MAPPER_OBJS); do \
		if [ "$$obj" = "mapper/gmachmod.obj" ]; then \
			printf "+$$obj\r\n" | tr '/' '\\' >> mapper/mapper.lbr; \
		else \
			printf "+$$obj &\r\n" | tr '/' '\\' >> mapper/mapper.lbr; \
		fi \
	done
	@printf "mapper\\mapper.lst;\r\n" >> mapper/mapper.lbr
	$(LIB) @mapper/mapper.lbr

tools-check:
	@mkdir -p build/test
	@printf "_TEXT segment byte public 'CODE'\r\nassume cs:_TEXT, ds:_TEXT\r\norg 100h\r\nstart:\r\n mov ax, 4c00h\r\n int 21h\r\n_TEXT ends\r\nend start\r\n" > build/test/chk.asm
	@printf "#include <stdio.h>\r\nint main(void) { printf(\"OK\"); return 0; }\r\n" > build/test/chk.c
	@echo "Testing MASM..." && $(MASM) -Mx -t -I$(ASMINC) build/test/chk.asm,build/test/chk.obj\;
	@echo "Testing LINK..." && $(LINK) 'build\test\chk.obj,build\test\chk.exe;'
	@echo "Testing EXE2BIN..." && $(EXE2BIN) 'build\test\chk.exe' 'build\test\chk.com'
	@echo "Testing CL (C compiler)..." && $(CL) -c -AS -Os -Zp -Fobuild/test/chkc.obj build/test/chk.c -- INCLUDE=$(SDKINC) PATH=$(SDKBIN)
	@echo "Testing LIB..." && rm -f build/test/chk.lib && $(LIB) 'build\test\chk.lib +build\test\chk.obj;'
	@echo "Testing BUILDIDX..." && $(BUILDIDX) messages/usa-ms.msg
	@echo "Testing NOSRVBLD..." && $(NOSRVBLD) 'boot\boot.skl' 'messages\usa-ms.msg' > /dev/null && rm -f boot/boot.cl1
	@echo "Testing BUILDMSG..." && $(BUILDMSG) messages\\usa-ms commands\\command\\command.skl > /dev/null && rm -f command.cl* command.ctl
	@echo "Testing DBOF..." && $(DBOF) 'build\test\chk.com' 'build\test\chk.inc' 0 5
	@echo "Testing CONVERT..." && cp build/test/chk.exe build/test/chkconv.exe && $(CONVERT) build/test/chkconv.exe
	@echo "Testing EXEMOD..." && $(EXEMOD) 'build\test\chk.exe' > /dev/null
	@echo "Testing EXEFIX..." && cp build/test/chk.exe build/test/chkfix.exe && $(EXEFIX) build/test/chkfix.exe 1 1
	@echo "Testing EXEPACK..." && $(EXEPACK) build/test/chk.exe build/test/chkpack.exe
	@echo "Testing ASC2HLP..." && $(ASC2HLP) commands/select/usa.txt build/test/chk.hlp > /dev/null
	@echo "Testing COMPRESS..." && printf "ABCDEF" > build/test/chk.in && $(COMPRESS) build/test/chk.in build/test/chk.out < /dev/null
	@rm -rf build/test
	@echo "=== All 15 vintage tools verified successfully under emu2 ==="

clean:
	rm -rf build
	rm -f messages/*.idx
	rm -f common/*.obj common/*.lst common/*.map
	rm -f mapper/*.obj mapper/*.lib mapper/*.bak mapper/*.lst mapper/*.lbr
	rm -f boot/*.obj boot/*.bin boot/*.exe boot/*.inc boot/*.cl1 boot/*.map boot/*.lst
	rm -f kernel/dos/*.cl1 kernel/dos/*.cl3
	rm -f asminc/boot.inc

msdos:
	./msdos
