# MS-DOS 4.00 - kernel dispatcher
#
# Ported (GNU make): all drivers

SUBDIRS = bios dos country ansi keyboard display printer driver ramdrive \
          smartdrv xma2ems vdisk xmaem memm

.PHONY: all clean $(SUBDIRS)

all: $(SUBDIRS)

# SYSINIT uses relocation records from the linked DOS image.
bios: dos

$(SUBDIRS):
	$(MAKE) -C $@

CLEAN_SUBDIRS = $(addprefix clean-,$(SUBDIRS))

.PHONY: $(CLEAN_SUBDIRS)

clean: $(CLEAN_SUBDIRS)

$(CLEAN_SUBDIRS): clean-%:
	$(MAKE) -C $* clean
