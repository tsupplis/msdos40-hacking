# Media Directory

This directory holds inputs for floppy disk image construction:

- Master/blank 1.44M floppy images (or generated via `mformat`)
- Distribution templates (`autoexec.bat`, `config.sys`)
- Per-image file lists for the image construction rules

PCE helper executables (`pceboot.com`, `pceexit.com`, etc.) reside in `rom/pceutils/`.
PCE ROM files reside in `rom/`.

`make dist` packages the 1,440 KB system and developer disks as
`msdos40-1440.img` and `msdos40_dev-1440.img`. Smaller disks carry the
capacity and a volume number, for example `msdos40-720-1.img` and
`msdos40_dev-720-1.img`. Boot from system disk 1. Developer files keep
their directory paths across volumes.
