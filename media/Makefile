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
       exe2bin fastopen fc fdisk find format graftabl graphics help \
       join keyb label deltree move loadfix mem mode more nlsfunc print recover replace restore \
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
               $(ROOT)/kernel/memm/memm/emm386.sys \
               $(ROOT)/kernel/himem/himem.sys \
               $(ROOT)/kernel/umbs/umbs.sys

EXTRA_TOOLS = $(ROOT)/extra/mbasic.com $(ROOT)/extra/vi.exe
FULL_FILES = $(EXTRA_TOOLS) $(ROOT)/gwbasic/gwbasic.exe

SDK = $(ROOT)/sdk
DEV_BIN = $(addprefix $(SDK)/bin/,cl.exe c1.exe c2.exe c3.exe cl.err c1.err c23.err \
          masm.exe link.exe lib.exe nmake.exe tools.ini) \
          $(ROOT)/commands/debug/debug.com $(ROOT)/commands/exe2bin/exe2bin.exe $(EXTRA_TOOLS)
DEV_LIB = $(addprefix $(SDK)/lib/,slibce.lib slibfp.lib em.lib)
DEV_HEADERS = $(wildcard $(SDK)/include/*.h $(SDK)/include/sys/*.h)
DEV_EXAMPLES = $(addprefix $(SDK)/examples/,c/Makefile c/hello.c asm/Makefile asm/hello.asm)

IMAGES = msdos40_base.img msdos40_dist.img msdos40_full.img msdos40_dev.img

# Names expected on the finished full image (used by "make check")
EXPECTED = DOSHELP.HLP IO.SYS MSDOS.SYS COMMAND.COM CONFIG.SYS AUTOEXEC.BAT \
           $(shell echo $(notdir $(CMD_FILES) $(EXTRA_FILES) $(FULL_FILES)) | tr 'a-z' 'A-Z')

.PHONY: all clean check dist force-images

all: $(IMAGES)

dist: ../disks.zip

# A mounted floppy may have been written since the build. Package fresh media.
ifneq ($(filter dist,$(MAKECMDGOALS)),)
$(IMAGES) ../disks.zip: force-images
endif

../disks.zip: $(IMAGES) Makefile
	zip -q - $(IMAGES) > $@.tmp
	mv $@.tmp $@

# FAT names are upper case: mcopy keeps the host name, so upper-case it explicitly.
msdos40_base.img: $(BOOTSEC) $(IO_SYS) $(MSDOS) $(COMMAND) $(CMD_FILES) $(ROOT)/doshelp/doshelp.hlp Makefile
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
	mcopy -t -i $@ $(ROOT)/doshelp/doshelp.hlp ::DOSHELP.HLP
	mdir -i $@ -a ::

# cp keeps the hidden/system attributes and the boot sector of the base image.
# GRAPHICS.PRO and SELECT.PRT are text files that DOS parses line by line: they are
# stored with CR/LF (the sources here have LF only; the 4.01 tree has CR/LF).
# awk is used (not unix2dos) so no extra tool is needed on the build host.
msdos40_dist.img: msdos40_base.img $(EXTRA_FILES)
	rm -f $@
	cp msdos40_base.img $@
	for f in $(EXTRA_FILES); do \
	  n=`basename $$f | tr 'a-z' 'A-Z'`; \
	  case $$n in \
	  GRAPHICS.PRO|SELECT.PRT) \
	    awk '{ sub(/\r$$/, ""); printf "%s\r\n", $$0 }' $$f > crlf.tmp && \
	    mcopy -i $@ crlf.tmp ::$$n && rm -f crlf.tmp || exit 1;; \
	  *) mcopy -i $@ $$f ::$$n || exit 1;; \
	  esac; \
	done
	mdir -i $@ -a ::

# The text files are stripped of any CR first, then mcopy -t writes CR/LF, so the
# result is right whether the sources are checked out with LF or CRLF.
# -D o overwrites without asking (the dist image may already hold such a file).
msdos40_full.img: msdos40_dist.img config.sys autoexec.bat $(FULL_FILES)
	rm -f $@ config.tmp autoexec.tmp
	cp msdos40_dist.img $@
	for f in $(FULL_FILES); do \
	  n=`basename $$f | tr 'a-z' 'A-Z'`; \
	  mcopy -i $@ $$f ::$$n || exit 1; \
	done
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
	rm -f *.img ../disks.zip ../disks.zip.tmp .listing.tmp crlf.tmp

msdos40_dev.img: Makefile $(SDK)/env.bat $(DEV_BIN) $(DEV_LIB) $(DEV_HEADERS) $(DEV_EXAMPLES)
	rm -f $@.tmp
	mformat -C -f 1440 -v MSDOS40DEV -i $@.tmp ::
	mmd -i $@.tmp ::BIN ::LIB ::INCLUDE ::INCLUDE/SYS ::EXAMPLES ::EXAMPLES/C ::EXAMPLES/ASM
	mcopy -t -i $@.tmp $(SDK)/env.bat ::ENV.BAT
	@set -e; for group in BIN LIB INCLUDE; do \
	  case $$group in BIN) files="$(DEV_BIN)";; LIB) files="$(DEV_LIB)";; \
	    INCLUDE) files="$(DEV_HEADERS)";; esac; \
	  for f in $$files; do \
	    n=`basename "$$f" | tr 'a-z' 'A-Z'`; dir=$$group; \
	    case $$f in */include/sys/*) dir=INCLUDE/SYS;; esac; \
	    mcopy -i $@.tmp "$$f" ::$$dir/$$n; \
	  done; \
	done
	@set -e; for f in $(DEV_EXAMPLES); do \
	  n=`basename "$$f" | tr 'a-z' 'A-Z'`; \
	  case $$f in */examples/c/*) dir=C;; *) dir=ASM;; esac; \
	  mcopy -i $@.tmp "$$f" ::EXAMPLES/$$dir/$$n; \
	done
	mv $@.tmp $@
