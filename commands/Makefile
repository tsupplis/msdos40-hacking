# MS-DOS 4.00 - commands dispatcher (original nmake build order)
#
# Ported (GNU make):
SUBDIRS = command assign edlin exe2bin find join more print sort subst sys \
          share nlsfunc comp diskcomp diskcopy label recover tree xcopy \
          fastopen append

# Not yet ported (still old nmake Makefiles, deliberately not dispatched):
#   attrib chkdsk debug fc format backup restore replace fdisk mode mem
#   filesys ifsfunc graftabl graphics keyb select

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
