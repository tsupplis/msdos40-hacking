# MS-DOS 4.00 - Messages Makefile
#
# buildidx rewrites the header line of the .msg it indexes, so it runs on a
# scratch copy under build/: the .msg source stays untouched, only the .idx is kept.

ROOT     ?= $(CURDIR)/..
SDKBIN   ?= $(ROOT)/sdk/bin

EMU2     = emu2
BUILDIDX = $(EMU2) $(SDKBIN)/buildidx.exe

COUNTRY  = usa-ms
SCRATCH  = $(ROOT)/build/messages

.PHONY: all clean

all: $(COUNTRY).idx

$(COUNTRY).idx: $(COUNTRY).msg
	rm -rf $(SCRATCH)
	mkdir -p $(SCRATCH)
	cp $(COUNTRY).msg $(SCRATCH)/
	cd $(SCRATCH) && $(BUILDIDX) $(COUNTRY).msg
	cp $(SCRATCH)/$(COUNTRY).idx $@
	rm -rf $(SCRATCH)

clean:
	rm -f *.idx
	rm -rf $(SCRATCH)
