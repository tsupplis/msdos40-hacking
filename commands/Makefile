# MS-DOS 4.00 - commands dispatcher (original nmake build order)
#
# Ported (GNU make):
SUBDIRS = command attrib assign chkdsk debug edlin exe2bin fdisk find fc format join more \
          print recover restore sort subst sys share nlsfunc ifsfunc mem filesys backup comp \
          diskcomp diskcopy label mode tree replace xcopy graftabl fastopen append \
          graphics keyb select

.PHONY: all clean $(SUBDIRS)

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

CLEAN_SUBDIRS = $(addprefix clean-,$(SUBDIRS))

.PHONY: $(CLEAN_SUBDIRS)

clean: $(CLEAN_SUBDIRS)

$(CLEAN_SUBDIRS): clean-%:
	$(MAKE) -C $* clean

# cl.exe (C 5.1) under emu2 shares temp files: concurrent compiles fail with C1042
.NOTPARALLEL:
