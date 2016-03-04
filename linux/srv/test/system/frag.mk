
SRCDIR_SRV_TEST_SYSTEM = srv/test/system
OBJDIR_SRV_TEST_SYSTEM = $(OBJDIR)/$(SRCDIR_SRV_TEST_SYSTEM)

OBJDIRS     +=  $(OBJDIR_SRV_TEST_SYSTEM)
SRV_INCLUDE += -I$(SRCDIR_SRV_TEST_SYSTEM)

FLUMEDBG_OFILES = flumedbg.lo

FLUMEDBG_OBJS = $(foreach ofile, $(FLUMEDBG_OFILES), \
		$(OBJDIR_SRV_TEST_SYSTEM)/$(ofile))

FLUMEDBG = $(OBJDIR_SRV_TEST_SYSTEM)/flumedbg

##-----------------------------------------------------------------------
##

$(OBJDIR_SRV_TEST_SYSTEM)/flumedbg.C: $(SRCDIR_SRV_TEST_SYSTEM)/flumedbg.py
	@mkdir -p $(@D)
	@echo "+  gen: $@"
	$(V)$(PYTHON) $< > $@ || (rm -f $@ && false)

##
##-----------------------------------------------------------------------


##-----------------------------------------------------------------------
##

srcdir = $(SRCDIR_SRV_TEST_SYSTEM)
objdir = $(OBJDIR_SRV_TEST_SYSTEM)

include make/srv.mk

##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

$(FLUMEDBG): $(FLUMEDBG_OBJS) $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD)

##
##-----------------------------------------------------------------------

all: $(FLUMEDBG)

install-srv-test-system: \
	install-srv-test-system-flumedbg

install-srv-test-system-% : $(OBJDIR_SRV_TEST_SYSTEM)/%
	@echo "+ inst:" `basename $<` "-> $(FLUMESRVBIN)"
	@mkdir -p $(FLUMESRVBIN)
	$(V)$(LT_INSTALL) $(BINMODE) $< $(FLUMESRVBIN)
