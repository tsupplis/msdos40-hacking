# MS-DOS 4.00 - vintage toolchain smoke tests (run under emu2)

ROOT ?= $(CURDIR)/..

EMU2     = emu2
SDKBIN   = sdk/bin
SDKINC   = sdk/include

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

# every check runs from the repository root, where the tool paths are relative
AT       = @cd $(ROOT) &&

.PHONY: tools-check

tools-check:
	$(AT) mkdir -p build/test
	$(AT) printf "_TEXT segment byte public 'CODE'\r\nassume cs:_TEXT, ds:_TEXT\r\norg 100h\r\nstart:\r\n mov ax, 4c00h\r\n int 21h\r\n_TEXT ends\r\nend start\r\n" > build/test/chk.asm
	$(AT) printf "#include <stdio.h>\r\nint main(void) { printf(\"OK\"); return 0; }\r\n" > build/test/chk.c
	$(AT) echo "Testing MASM..." && $(MASM) -Mx -t -Iasminc build/test/chk.asm,build/test/chk.obj\;
	$(AT) echo "Testing LINK..." && $(LINK) 'build\test\chk.obj,build\test\chk.exe;'
	$(AT) echo "Testing EXE2BIN..." && $(EXE2BIN) 'build\test\chk.exe' 'build\test\chk.com'
	$(AT) echo "Testing CL (C compiler)..." && $(CL) -c -AS -Os -Zp -Fobuild/test/chkc.obj build/test/chk.c -- INCLUDE=$(SDKINC) PATH=$(SDKBIN)
	$(AT) echo "Testing LIB..." && rm -f build/test/chk.lib && $(LIB) 'build\test\chk.lib +build\test\chk.obj;'
	$(AT) echo "Testing BUILDIDX..." && $(BUILDIDX) messages/usa-ms.msg
	$(AT) echo "Testing NOSRVBLD..." && $(NOSRVBLD) 'boot\boot.skl' 'messages\usa-ms.msg' > /dev/null && rm -f boot/boot.cl1
	$(AT) echo "Testing BUILDMSG..." && $(BUILDMSG) messages\\usa-ms commands\\command\\command.skl > /dev/null && rm -f command.cl* command.ctl
	$(AT) echo "Testing DBOF..." && $(DBOF) 'build\test\chk.com' 'build\test\chk.inc' 0 5
	$(AT) echo "Testing CONVERT..." && cp build/test/chk.exe build/test/chkconv.exe && $(CONVERT) build/test/chkconv.exe
	$(AT) echo "Testing EXEMOD..." && $(EXEMOD) 'build\test\chk.exe' > /dev/null
	$(AT) echo "Testing EXEFIX..." && cp build/test/chk.exe build/test/chkfix.exe && $(EXEFIX) build/test/chkfix.exe 1 1
	$(AT) echo "Testing EXEPACK..." && $(EXEPACK) build/test/chk.exe build/test/chkpack.exe
	$(AT) echo "Testing ASC2HLP..." && $(ASC2HLP) commands/select/usa.txt build/test/chk.hlp > /dev/null
	$(AT) echo "Testing COMPRESS..." && printf "ABCDEF" > build/test/chk.in && $(COMPRESS) build/test/chk.in build/test/chk.out < /dev/null
	$(AT) rm -rf build/test
	@echo "=== All 15 vintage tools verified successfully under emu2 ==="
