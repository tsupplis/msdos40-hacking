# MS-DOS 4.00 - kernel dispatcher
#
# Ported (GNU make): bios dos
# Not yet ported (still old nmake Makefiles, deliberately not dispatched):
#   country ansi keyboard display printer driver ramdrive smartdrv xma2ems vdisk xmaem memm

SUBDIRS = bios dos

.PHONY: all clean $(SUBDIRS)

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

CLEAN_SUBDIRS = $(addprefix clean-,$(SUBDIRS))

.PHONY: $(CLEAN_SUBDIRS)

clean: $(CLEAN_SUBDIRS)

$(CLEAN_SUBDIRS): clean-%:
	$(MAKE) -C $* clean
