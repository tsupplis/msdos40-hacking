ROOT := $(abspath ..)
export EMU2_DRIVE_C := $(ROOT)
EMU2 ?= emu2
SDK := $(ROOT)/sdk/bin
# Keep one ordered list. GWDATA reserves the PSP and BIBOOT marks the end of data.
OBJS := $(shell tr -d '\r+' < gwbasic.lnk | sed -n 's/\.OBJ$$/.obj/p' | tr A-Z a-z)

.DELETE_ON_ERROR:
.PHONY: all clean check
all: gwbasic.exe

gwbasic.exe: $(OBJS) gwbasic.lnk
	$(EMU2) $(SDK)/link.exe @gwbasic.lnk </dev/null

%.obj: %.asm oem.h bintrp.h ibmres.h gio86u msdosu
	$(EMU2) $(SDK)/masm.exe -t '$<,$@;' </dev/null

math.obj: math1.asm math2.asm

check: gwbasic.exe
	../test/check_gwbasic

clean:
	$(RM) $(OBJS) gwbasic.exe gwbasic.map
