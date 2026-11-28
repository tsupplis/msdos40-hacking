.DELETE_ON_ERROR:
ROOT ?= $(CURDIR)/..

# Volume label "MSDOS.401": DOS keeps the dot in a label, mtools cannot write that
# form, so the 11 bytes are patched in place. Two copies exist: the root directory
# label entry and the boot sector field (offset 43).
# The label entry must come AFTER the system files: the boot sector requires IO.SYS
# and MSDOS.SYS to be the first two root directory entries, so it lands in slot 2
# (root directory = sector 19 on a 1.44M floppy, 32-byte entries).
LABEL      = MSDOS.401
ROOT_SECTOR = 19
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
CMD_FILES = $(ROOT)/edit/edit.exe $(foreach c,$(CMDS),$(firstword $(wildcard $(ROOT)/commands/$(c)/$(c).com $(ROOT)/commands/$(c)/$(c).exe) $(ROOT)/commands/$(c)/$(c).exe))

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

FULL_FILES = $(ROOT)/gwbasic/gwbasic.exe

SDK = $(ROOT)/sdk
DEV_BIN = $(addprefix $(SDK)/bin/,cl.exe c1.exe c2.exe c3.exe cl.err c1.err c23.err \
          masm.exe link.exe lib.exe nmake.exe tools.ini) \
          $(ROOT)/commands/debug/debug.com $(ROOT)/commands/exe2bin/exe2bin.exe $(ROOT)/edit/edit.exe $(FULL_FILES)
DEV_LIB = $(addprefix $(SDK)/lib/,slibce.lib slibfp.lib em.lib)
DEV_HEADERS = $(wildcard $(SDK)/include/*.h $(SDK)/include/sys/*.h)
DEV_EXAMPLES = $(addprefix $(SDK)/examples/,c/Makefile c/hello.c asm/Makefile asm/hello.asm)

# The four 360 KB file groups also define the two 720 KB volumes.
byname = $(foreach name,$(1),$(filter %/$(name).com %/$(name).exe,$(CMD_FILES)))
SYS1 = $(call byname,edit append assign attrib backup chkdsk comp debug diskcomp diskcopy)
SYS2 = $(call byname,edlin exe2bin fastopen fc fdisk find format graftabl graphics help join keyb label deltree move loadfix mem mode more nlsfunc print recover)
EXTRA3 = $(SELECT_FILES) $(filter %/graphics.pro %/ansi.sys %/country.sys %/display.sys,$(EXTRA_FILES))
SYS3 = $(filter-out $(SYS1) $(SYS2),$(CMD_FILES)) $(EXTRA3)
SYS4 = $(filter-out $(EXTRA3),$(EXTRA_FILES)) $(FULL_FILES)

BIN1 = $(filter %/cl.exe %/c1.exe %/c2.exe,$(DEV_BIN))
BIN2 = $(filter %/c3.exe %/cl.err %/c1.err %/c23.err %/masm.exe %/link.exe,$(DEV_BIN))
BIN3 = $(filter-out $(BIN1) $(BIN2),$(DEV_BIN))

SIZES = 1440 720-1 720-2 360-1 360-2 360-3 360-4
SYSTEM = $(addprefix msdos40-,$(addsuffix .img,$(SIZES)))
DEVELOPER = $(addprefix msdos40_dev-,$(addsuffix .img,$(SIZES)))
IMAGES = $(SYSTEM) $(DEVELOPER)
# Names expected on the finished full image (used by "make check")
EXPECTED = EDIT.LIC DOSHELP.HLP IO.SYS MSDOS.SYS COMMAND.COM CONFIG.SYS AUTOEXEC.BAT \
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

# Bind each target to its own inputs and geometry.
define volume
$(1): FILES := $(3)
$(1): SIZE := $(2)
$(1): $(3) Makefile
endef

$(eval $(call volume,msdos40-1440.img,1440,$(CMD_FILES) $(EXTRA_FILES) $(FULL_FILES)))
$(eval $(call volume,msdos40-720-1.img,720,$(SYS1) $(SYS2)))
$(eval $(call volume,msdos40-720-2.img,720,$(SYS3) $(SYS4)))
$(foreach n,1 2 3 4,$(eval $(call volume,msdos40-360-$(n).img,360,$(SYS$(n)))))

FIRST = msdos40-1440.img msdos40-720-1.img msdos40-360-1.img
$(FIRST): BOOT := yes
$(FIRST): $(BOOTSEC) $(IO_SYS) $(MSDOS) $(COMMAND) config.sys autoexec.bat $(ROOT)/edit/LICENSE.md $(ROOT)/doshelp/doshelp.hlp
msdos40-720-1.img: ROOT_SECTOR := 7
msdos40-360-1.img: ROOT_SECTOR := 5

$(SYSTEM):
	rm -f $@.tmp
	mformat -f $(SIZE) -C $(if $(BOOT),-B $(BOOTSEC)) -i $@.tmp ::
	@if test "$(BOOT)" = yes; then set -e; \
	  mcopy -i $@.tmp $(IO_SYS) ::IO.SYS; mattrib -i $@.tmp +s +h +r ::IO.SYS; \
	  mcopy -i $@.tmp $(MSDOS) ::MSDOS.SYS; mattrib -i $@.tmp +s +h +r ::MSDOS.SYS; \
	  for slot in 0 1; do dd if=/dev/zero of=$@.tmp bs=1 seek=$$(($(ROOT_SECTOR)*512 + slot*32 + 12)) count=10 conv=notrunc 2>/dev/null; done; \
	  mlabel -i $@.tmp ::LABEL; \
	  printf '%-11s' '$(LABEL)' | dd of=$@.tmp bs=1 seek=$$(($(ROOT_SECTOR)*512 + 64)) conv=notrunc 2>/dev/null; \
	  printf '%-11s' '$(LABEL)' | dd of=$@.tmp bs=1 seek=$(LABEL_BOOT) conv=notrunc 2>/dev/null; \
	  mcopy -i $@.tmp $(COMMAND) ::COMMAND.COM; \
	  mcopy -t -i $@.tmp $(ROOT)/edit/LICENSE.md ::EDIT.LIC; \
	  mcopy -t -i $@.tmp $(ROOT)/doshelp/doshelp.hlp ::DOSHELP.HLP; \
	  for f in config.sys autoexec.bat; do tr -d '\r' < $$f > $@.txt; mcopy -t -i $@.tmp $@.txt ::$$(echo $$f | tr a-z A-Z); done; \
	fi
	@set -e; for f in $(FILES); do \
	  n=$$(basename "$$f" | tr a-z A-Z); \
	  case $$n in GRAPHICS.PRO|SELECT.PRT) awk '{ sub(/\r$$/,""); printf "%s\r\n", $$0 }' "$$f" > $@.txt; f=$@.txt;; esac; \
	  mcopy -i $@.tmp "$$f" ::$$n; \
	done
	rm -f $@.txt
	mv $@.tmp $@

# Every expected file must be on the full image, with an upper-case 8.3 name
check: msdos40-1440.img
	@mdir -b -i msdos40-1440.img -a :: | tr 'a-z' 'A-Z' | sed 's/^:*\///' > .listing.tmp; \
	missing=0; \
	for n in $(EXPECTED); do \
	  grep -qx "$$n" .listing.tmp || { echo "missing on image: $$n"; missing=1; }; \
	done; \
	lower=`mdir -b -i msdos40-1440.img -a :: | grep '[a-z]' | wc -l`; \
	rm -f .listing.tmp; \
	[ $$lower -eq 0 ] || { echo "lower-case names on image: $$lower"; missing=1; }; \
	[ $$missing -eq 0 ] && echo "check: all expected files present on msdos40-1440.img"; \
	exit $$missing

clean:
	rm -f *.img ../disks.zip ../disks.zip.tmp .listing.tmp crlf.tmp *.img.tmp *.img.txt

DEV4 = $(DEV_LIB) $(DEV_HEADERS) $(DEV_EXAMPLES)
$(eval $(call volume,msdos40_dev-1440.img,1440,$(DEV_BIN) $(DEV4)))
$(eval $(call volume,msdos40_dev-720-1.img,720,$(BIN1) $(BIN2)))
$(eval $(call volume,msdos40_dev-720-2.img,720,$(BIN3) $(DEV4)))
$(foreach n,1 2 3,$(eval $(call volume,msdos40_dev-360-$(n).img,360,$(BIN$(n)))))
$(eval $(call volume,msdos40_dev-360-4.img,360,$(DEV4)))

DEV_FIRST = msdos40_dev-1440.img msdos40_dev-720-1.img msdos40_dev-360-1.img
$(DEV_FIRST): SETUP := yes
$(DEV_FIRST): $(ROOT)/edit/LICENSE.md $(SDK)/env.bat

$(DEVELOPER):
	rm -f $@.tmp
	mformat -C -f $(SIZE) -v MSDOS40DEV -i $@.tmp ::
	@if test "$(SETUP)" = yes; then set -e; \
	  mcopy -t -i $@.tmp $(ROOT)/edit/LICENSE.md ::EDIT.LIC; \
	  mcopy -t -i $@.tmp $(SDK)/env.bat ::ENV.BAT; \
	fi
	@set -e; dirs=" "; for f in $(FILES); do \
	  case $$f in */examples/c/*) dir=EXAMPLES/C;; */examples/asm/*) dir=EXAMPLES/ASM;; \
	    */include/sys/*) dir=INCLUDE/SYS;; */include/*) dir=INCLUDE;; */lib/*) dir=LIB;; *) dir=BIN;; esac; \
	  for path in "$${dir%%/*}" "$$dir"; do case "$$dirs" in *" $$path "*) ;; \
	    *) mmd -i $@.tmp ::$$path; dirs="$$dirs$$path ";; esac; done; \
	  n=$$(basename "$$f" | tr a-z A-Z); mcopy -i $@.tmp "$$f" ::$$dir/$$n; \
	done
	mv $@.tmp $@
