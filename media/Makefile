# MS-DOS 4.00 - floppy images (mtools)

ROOT ?= $(CURDIR)/..

BOOTSEC = $(ROOT)/boot/bootsec.bin
IO_SYS  = $(ROOT)/kernel/bios/io.sys
MSDOS   = $(ROOT)/kernel/dos/msdos.sys
COMMAND = $(ROOT)/commands/command/command.com

.PHONY: all clean

all: msdos40_base.img

msdos40_base.img: $(BOOTSEC) $(IO_SYS) $(MSDOS) $(COMMAND)
	rm -f $@
	mformat -f 1440 -C -B $(BOOTSEC) -i $@ ::
	mcopy -i $@ $(IO_SYS) ::IO.SYS
	mattrib -i $@ +s +h +r ::IO.SYS
	mcopy -i $@ $(MSDOS) ::MSDOS.SYS
	mattrib -i $@ +s +h +r ::MSDOS.SYS
	mcopy -i $@ $(COMMAND) ::COMMAND.COM
	mdir -i $@ -a ::

clean:
	rm -f *.img
