# MASM's near call works for both COM and EXE layouts when the launcher
# contributes to the same code segment as the command's entry routine.
MSGDIR ?= $(ROOT)/messages
include $(ROOT)/common/showhelp.mk

helptest.obj: $(ROOT)/common/helptest.asm $(ROOT)/common/showhelp.inc $(ROOT)/asminc/helparg.inc showhelp.cl1
	@echo | emu2 $(SDKBIN)/masm.exe -Mx -t -I. -I'C:\common' -I'C:\asminc' -Dhelpcmd=$(HELP_TOPIC) -Dhelpseg=$(HELP_SEG) $(HELP_CLASS) $(HELP_FLAGS) 'C:\common\helptest.asm,helptest.obj;'
