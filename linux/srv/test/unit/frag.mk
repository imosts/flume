

PROGS = $(SRV_TEST_UNIT_IDD) \
	$(SRV_TEST_UNIT_RM) \
	$(SRV_TEST_UNIT_MKSOCKET) \
	$(SRV_TEST_UNIT_PINGPONG) \
	$(SRV_TEST_UNIT_MNTTR)

SRCDIR_SRV_TEST_UNIT = srv/test/unit
OBJDIR_SRV_TEST_UNIT = $(OBJDIR)/$(SRCDIR_SRV_TEST_UNIT)

SRV_TEST_UNIT_IDD = $(OBJDIR_SRV_TEST_UNIT)/idd_tst
SRV_TEST_UNIT_RM = $(OBJDIR_SRV_TEST_UNIT)/rm_tst
SRV_TEST_UNIT_MKSOCKET = $(OBJDIR_SRV_TEST_UNIT)/mksocket
SRV_TEST_UNIT_PINGPONG = $(OBJDIR_SRV_TEST_UNIT)/pingpong
SRV_TEST_UNIT_MNTTR = $(OBJDIR_SRV_TEST_UNIT)/mnttr

OBJDIRS += $(OBJDIR_SRV_TEST_UNIT)

##-----------------------------------------------------------------------
##

srcdir = $(SRCDIR_SRV_TEST_UNIT)
objdir = $(OBJDIR_SRV_TEST_UNIT)

include make/srv.mk

##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

$(SRV_TEST_UNIT_IDD): $(OBJDIR_SRV_TEST_UNIT)/idd_tst.lo $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD)  $(V_REDIRECT)

$(SRV_TEST_UNIT_RM): $(OBJDIR_SRV_TEST_UNIT)/rm_tst.lo $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD)  $(V_REDIRECT)

$(SRV_TEST_UNIT_MKSOCKET): $(OBJDIR_SRV_TEST_UNIT)/mksocket.lo $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD)  $(V_REDIRECT)

$(SRV_TEST_UNIT_PINGPONG): $(OBJDIR_SRV_TEST_UNIT)/pingpong.lo $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD)  $(V_REDIRECT)

$(SRV_TEST_UNIT_MNTTR): $(OBJDIR_SRV_TEST_UNIT)/mnttr.lo $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD) $(V_REDIRECT)

##
##-----------------------------------------------------------------------

all: $(PROGS)

