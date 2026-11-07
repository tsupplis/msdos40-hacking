# MS-DOS 4.00 - MEMM dispatcher (emm library first, then the driver)

SUBDIRS = emm memm

.PHONY: all clean $(SUBDIRS)

all: $(SUBDIRS)

memm: emm

$(SUBDIRS):
	$(MAKE) -C $@

clean:
	$(MAKE) -C emm clean
	$(MAKE) -C memm clean
