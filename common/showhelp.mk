# NOSRVBLD writes beside its input. Stage the skeleton locally so concurrent
# command builds generate independent message includes.
showhelp.cl1: $(ROOT)/common/showhelp.skl $(MSGDIR)/usa-ms.msg $(MSGDIR)/usa-ms.idx
	cp $< showhelp.skl
	emu2 $(SDKBIN)/nosrvbld.exe showhelp.skl 'C:\messages\usa-ms.msg' > /dev/null
	rm -f showhelp.skl
