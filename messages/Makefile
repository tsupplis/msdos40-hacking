# MS-DOS 4.00 - Messages Makefile

EMU2     = emu2
SDKBIN   = ../sdk/bin
BUILDIDX = $(EMU2) $(SDKBIN)/buildidx.exe

COUNTRY  = usa-ms

all: $(COUNTRY).idx

$(COUNTRY).idx: $(COUNTRY).msg
	$(BUILDIDX) $(COUNTRY).msg

clean:
	rm -f *.idx
