
DIR := conf

CONF_DIR := $(DIR)
OBJDIR_CONF = $(OBJDIR)/$(DIR)

OBJDIRS += $(OBJDIR_CONF)

FLUME_CONF = $(OBJDIR_CONF)/flume.conf.dist
IDD_CONF = $(OBJDIR_CONF)/idd.conf.dist

##-----------------------------------------------------------------------

$(OBJDIR_CONF)/%: $(CONF_DIR)/%.in
	@echo "+  gen: " $@
	@mkdir -p $(@D)
	$(V)$(PERL) -ne '{ s/@@([^@]+)@@/$$ENV{"FLUME_$$1"}/ge; print $$_; }' < $< > $@


##-----------------------------------------------------------------------

all: $(FLUME_CONF) $(IDD_CONF)

install-conf: \
	install-conf-flume \
	install-conf-idd

install-conf-%: $(OBJDIR_CONF)/%.conf.dist
	@echo "+ inst:" `basename $<` "-> $(FLUMECONFDIR)"
	@mkdir -p $(FLUMECONFDIR)
	$(V)$(LT_INSTALL) $(LIBMODE) $< $(FLUMECONFDIR)
