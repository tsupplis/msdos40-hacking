# MS-DOS 4.00 Rebuild - top-level dispatcher
#
# This file only orders and dispatches; every directory owns its own Makefile.
#   make              build everything that has been ported
#   make <dir>        build one top-level directory (e.g. make kernel)
#   make clean        clean every directory
#   make run          build and boot the floppy image in PCE
#   make tools-check  smoke-test the vintage tools under emu2

SUBDIRS = messages boot common mapper kernel commands media

.PHONY: all clean foundation run msdos tools-check $(SUBDIRS)

all: $(SUBDIRS)

foundation: messages boot common mapper

$(SUBDIRS):
	$(MAKE) -C $@

# Ordering between directories (also correct under make -j)
boot:     messages
common:   messages boot
kernel:   messages boot common mapper
commands: messages common mapper
media:    boot kernel commands

# clean: one clean-<dir> target per directory
CLEAN_SUBDIRS = $(addprefix clean-,$(SUBDIRS))

clean: $(CLEAN_SUBDIRS)

$(CLEAN_SUBDIRS): clean-%:
	$(MAKE) -C $* clean

tools-check:
	$(MAKE) -C sdk tools-check

run msdos: all
	./msdos

# cl.exe (C 5.1) under emu2 shares temp files: concurrent compiles fail with C1042
.NOTPARALLEL:
