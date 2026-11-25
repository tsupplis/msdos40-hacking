# MS-DOS 4.00 - Messages Makefile
#
# BUILDIDX updates the section offsets and revision in the catalog as it
# writes the index. BUILDMSG needs the matching pair.
ROOT     ?= $(CURDIR)/..
SDKBIN   ?= $(ROOT)/sdk/bin

EMU2     = emu2
BUILDIDX = $(EMU2) $(SDKBIN)/buildidx.exe

COUNTRY  = usa-ms
SCRATCH  = $(ROOT)/build/messages

.PHONY: all clean

all: $(COUNTRY).idx
	@$(ROOT)/test/check_msgidx $(COUNTRY).msg $(COUNTRY).idx

$(COUNTRY).idx: $(COUNTRY).msg Makefile
	rm -rf $(SCRATCH)
	mkdir -p $(SCRATCH)
	cp $(COUNTRY).msg $(SCRATCH)/
	cd $(SCRATCH) && $(BUILDIDX) $(COUNTRY).msg
	@# Keep the revision stable on a clean rebuild. Publish both generated
	@# files when BUILDIDX has repaired any section headers.
	tail -n +2 $(COUNTRY).msg > $(SCRATCH)/original
	tail -n +2 $(SCRATCH)/$(COUNTRY).msg > $(SCRATCH)/indexed
	if cmp -s $(SCRATCH)/original $(SCRATCH)/indexed; then \
		(head -n 1 $(COUNTRY).msg && tail -n +2 $(SCRATCH)/$(COUNTRY).idx) > $@; \
	else \
		cp $(SCRATCH)/$(COUNTRY).msg $(COUNTRY).msg && cp $(SCRATCH)/$(COUNTRY).idx $@; \
	fi
	rm -rf $(SCRATCH)

clean:
	rm -f *.idx
	rm -rf $(SCRATCH)
