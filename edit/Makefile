ROOT ?= $(CURDIR)/..
SDKBIN ?= $(ROOT)/sdk/bin
export EMU2_DRIVE_C ?= $(ROOT)

CL = emu2 $(SDKBIN)/cl.exe
LINK = emu2 $(SDKBIN)/link.exe
CFLAGS = -c -AC -Os -W3 -I'C:\sdk\include'

.PHONY: all clean test
all: edit.exe

%.obj: %.c
	$(CL) $(CFLAGS) -Fo$@ $< -- PATH='C:\sdk\bin'

edit.exe: edit.obj screen.obj fsave.obj Makefile
	$(LINK) '/STACK:8192 edit+screen+fsave,edit,NUL;' -- LIB='C:\sdk\lib'

edit.obj: screen.h fsave.h
screen.obj: screen.h
fsave.obj: fsave.h

test: edit.exe testfile.exe testsave.exe
	python3 test-file.py
	python3 test-save.py

testfile.obj: edit.c screen.h fsave.h
testfile.exe: testfile.obj screen.obj fsave.obj Makefile
	$(LINK) '/STACK:8192 testfile+screen+fsave,testfile,NUL;' -- LIB='C:\sdk\lib'

testsave.obj: fsave.c fsave.h
testsave.exe: testsave.obj
	$(LINK) 'testsave,testsave,NUL;' -- LIB='C:\sdk\lib'

clean:
	rm -f *.obj *.exe *.map
.NOTPARALLEL:
