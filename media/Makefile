# MS-DOS 4.00 - floppy images (mtools)
#
#   msdos40_base.img  boot sector + IO.SYS MSDOS.SYS COMMAND.COM + external commands
#   msdos40_dist.img  base + everything else of the old cpy.bat list (drivers, code pages,
#                     select, graphics.pro)
#   msdos40_full.img  dist + config.sys / autoexec.bat (from this directory)

ROOT ?= $(CURDIR)/..

# Volume label "MSDOS.401": DOS keeps the dot in a label, mtools cannot write that
# form, so the 11 bytes are patched in place. Two copies exist: the root directory
# label entry and the boot sector field (offset 43).
# The label entry must come AFTER the system files: the boot sector requires IO.SYS
# and MSDOS.SYS to be the first two root directory entries, so it lands in slot 2
# (root directory = sector 19 on a 1.44M floppy, 32-byte entries).
LABEL      = MSDOS.401
LABEL_ROOT = 9792
LABEL_BOOT = 43

BOOTSEC = $(ROOT)/boot/bootsec.bin
IO_SYS  = $(ROOT)/kernel/bios/io.sys
MSDOS   = $(ROOT)/kernel/dos/msdos.sys
COMMAND = $(ROOT)/commands/command/command.com

# External commands (everything under commands/ except command.com and select).
# Listed explicitly: a wildcard would be empty on a clean tree.
CMDS = append assign attrib backup chkdsk comp debug diskcomp diskcopy edlin \
       exe2bin fastopen fc fdisk filesys find format graftabl graphics ifsfunc \
       join keyb label mem mode more nlsfunc print recover replace restore \
       share sort subst sys tree xcopy
CMD_FILES = $(foreach c,$(CMDS),$(firstword $(wildcard $(ROOT)/commands/$(c)/$(c).com $(ROOT)/commands/$(c)/$(c).exe) $(ROOT)/commands/$(c)/$(c).exe))

# Rest of the cpy.bat list (vdisk.sys is built too but cpy.bat omits it; it is added here)
SELECT_FILES = $(addprefix $(ROOT)/commands/select/,select.exe select.com select.dat select.prt select.hlp)
EXTRA_FILES  = $(ROOT)/commands/graphics/graphics.pro $(SELECT_FILES) \
               $(ROOT)/kernel/ansi/ansi.sys \
               $(ROOT)/kernel/country/country.sys \
               $(ROOT)/kernel/display/display.sys \
               $(ROOT)/kernel/display/ega/ega.cpi \
               $(ROOT)/kernel/display/lcd/lcd.cpi \
               $(ROOT)/kernel/keyboard/keyboard.sys \
               $(ROOT)/kernel/printer/printer.sys \
               $(ROOT)/kernel/printer/4201/4201.cpi \
               $(ROOT)/kernel/printer/4208/4208.cpi \
               $(ROOT)/kernel/printer/5202/5202.cpi \
               $(ROOT)/kernel/smartdrv/smartdrv.sys \
               $(ROOT)/kernel/ramdrive/ramdrive.sys \
               $(ROOT)/kernel/driver/driver.sys \
               $(ROOT)/kernel/xma2ems/xma2ems.sys \
               $(ROOT)/kernel/xmaem/xmaem.sys \
               $(ROOT)/kernel/vdisk/vdisk.sys \
               $(ROOT)/kernel/memm/memm/emm386.sys

IMAGES = msdos40_base.img msdos40_dist.img msdos40_full.img

# Names expected on the finished full image (used by "make check")
EXPECTED = IO.SYS MSDOS.SYS COMMAND.COM CONFIG.SYS AUTOEXEC.BAT \
           $(shell echo $(notdir $(CMD_FILES) $(EXTRA_FILES)) | tr 'a-z' 'A-Z')

.PHONY: all clean check

all: $(IMAGES)

# FAT names are upper case: mcopy keeps the host name, so upper-case it explicitly.
msdos40_base.img: $(BOOTSEC) $(IO_SYS) $(MSDOS) $(COMMAND) $(CMD_FILES)
	rm -f $@
	mformat -f 1440 -C -B $(BOOTSEC) -i $@ ::
	mcopy -i $@ $(IO_SYS) ::IO.SYS
	mattrib -i $@ +s +h +r ::IO.SYS
	mcopy -i $@ $(MSDOS) ::MSDOS.SYS
	mattrib -i $@ +s +h +r ::MSDOS.SYS
	mlabel -i $@ ::LABEL
	printf '%-11s' '$(LABEL)' | dd of=$@ bs=1 seek=$(LABEL_ROOT) conv=notrunc 2>/dev/null
	printf '%-11s' '$(LABEL)' | dd of=$@ bs=1 seek=$(LABEL_BOOT) conv=notrunc 2>/dev/null
	mcopy -i $@ $(COMMAND) ::COMMAND.COM
	for f in $(CMD_FILES); do \
	  n=`basename $$f | tr 'a-z' 'A-Z'`; \
	  mcopy -i $@ $$f ::$$n || exit 1; \
	done
	mdir -i $@ -a ::

# cp keeps the hidden/system attributes and the boot sector of the base image
msdos40_dist.img: msdos40_base.img $(EXTRA_FILES)
	rm -f $@
	cp msdos40_base.img $@
	for f in $(EXTRA_FILES); do \
	  n=`basename $$f | tr 'a-z' 'A-Z'`; \
	  mcopy -i $@ $$f ::$$n || exit 1; \
	done
	mdir -i $@ -a ::

# The text files are stripped of any CR first, then mcopy -t writes CR/LF, so the
# result is right whether the sources are checked out with LF or CRLF.
# -D o overwrites without asking (the dist image may already hold such a file).
msdos40_full.img: msdos40_dist.img config.sys autoexec.bat
	rm -f $@ config.tmp autoexec.tmp
	cp msdos40_dist.img $@
	tr -d '\r' < config.sys > config.tmp
	tr -d '\r' < autoexec.bat > autoexec.tmp
	mcopy -D o -t -i $@ config.tmp ::CONFIG.SYS
	mcopy -D o -t -i $@ autoexec.tmp ::AUTOEXEC.BAT
	rm -f config.tmp autoexec.tmp
	mdir -i $@ -a ::

# Every expected file must be on the full image, with an upper-case 8.3 name
check: msdos40_full.img
	@mdir -b -i msdos40_full.img -a :: | tr 'a-z' 'A-Z' | sed 's/^:*\///' > .listing.tmp; \
	missing=0; \
	for n in $(EXPECTED); do \
	  grep -qx "$$n" .listing.tmp || { echo "missing on image: $$n"; missing=1; }; \
	done; \
	lower=`mdir -b -i msdos40_full.img -a :: | grep '[a-z]' | wc -l`; \
	rm -f .listing.tmp; \
	[ $$lower -eq 0 ] || { echo "lower-case names on image: $$lower"; missing=1; }; \
	[ $$missing -eq 0 ] && echo "check: all expected files present on msdos40_full.img"; \
	exit $$missing

clean:
	rm -f *.img .listing.tmp
