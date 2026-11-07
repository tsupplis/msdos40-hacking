# MS-DOS 4.00 - floppy images (mtools)

ROOT ?= $(CURDIR)/..

BOOTSEC = $(ROOT)/boot/bootsec.bin
IO_SYS  = $(ROOT)/kernel/bios/io.sys
MSDOS   = $(ROOT)/kernel/dos/msdos.sys
COMMAND = $(ROOT)/commands/command/command.com

# External commands (everything under commands/ except command.com).
# Listed explicitly: a wildcard would be empty on a clean tree.
CMDS = append assign attrib backup chkdsk comp debug diskcomp diskcopy edlin \
       exe2bin fastopen fc fdisk filesys find format graftabl graphics ifsfunc \
       join keyb label mem mode more nlsfunc print recover replace restore \
       share sort subst sys tree xcopy
CMD_FILES = $(foreach c,$(CMDS),$(firstword $(wildcard $(ROOT)/commands/$(c)/$(c).com $(ROOT)/commands/$(c)/$(c).exe) $(ROOT)/commands/$(c)/$(c).exe))

.PHONY: all clean

all: msdos40_base.img

msdos40_base.img: $(BOOTSEC) $(IO_SYS) $(MSDOS) $(COMMAND) $(CMD_FILES)
	rm -f $@
	mformat -f 1440 -C -B $(BOOTSEC) -i $@ ::
	mcopy -i $@ $(IO_SYS) ::IO.SYS
	mattrib -i $@ +s +h +r ::IO.SYS
	mcopy -i $@ $(MSDOS) ::MSDOS.SYS
	mattrib -i $@ +s +h +r ::MSDOS.SYS
	mcopy -i $@ $(COMMAND) ::COMMAND.COM
	mcopy -i $@ $(CMD_FILES) ::
	mdir -i $@ -a ::

clean:
	rm -f *.img
