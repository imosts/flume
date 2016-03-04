
DIR = srv/rm

SRCDIR_RM = $(DIR)
OBJDIR_RM = $(OBJDIR)/$(SRCDIR_RM)

OBJDIRS += $(OBJDIR_RM)
SRV_INCLUDE += -I$(SRCDIR_RM)

FLUMERM_OFILES = proc.lo main.lo rm.lo srv.lo init.lo fs.lo sockets.lo \
	systrace_policy.lo labelops.lo spawn.lo systrace.lo endpoint.lo \
	open.lo

FLUMERM_OBJS = $(foreach ofile, $(FLUMERM_OFILES), $(OBJDIR_RM)/$(ofile) )

FLUMERM = $(OBJDIR_RM)/flumerm

##-----------------------------------------------------------------------
##

srcdir = $(SRCDIR_RM)
objdir = $(OBJDIR_RM)

include make/srv.mk

##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

$(FLUMERM): $(FLUMERM_OBJS) $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD) 

##
##-----------------------------------------------------------------------

all: $(FLUMERM)

install-rm: $(FLUMERM)
	@echo "+ inst:" `basename $<` "-> $(FLUMESRVBIN)"
	@mkdir -p $(FLUMESRVBIN)
	$(V)$(LT_INSTALL) $(BINMODE) $< $(FLUMESRVBIN)
