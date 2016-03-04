
DIR = srv/spawn

SRCDIR_SPAWN = $(DIR)
OBJDIR_SPAWN = $(OBJDIR)/$(SRCDIR_SPAWN)

OBJDIRS += $(OBJDIR_SPAWN)
SRV_INCLUDE += -I$(SRCDIR_SPAWN)

SPAWN_OFILES = main.lo srv.lo setuid.lo fdtab.lo

SPAWN_OBJS = $(foreach ofile, $(SPAWN_OFILES), $(OBJDIR_SPAWN)/$(ofile) )

SPAWNER = $(OBJDIR_SPAWN)/spawner

##-----------------------------------------------------------------------
##

srcdir := $(SRCDIR_SPAWN)
objdir := $(OBJDIR_SPAWN)

include make/srv.mk

##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

$(SPAWNER): $(SPAWN_OBJS) $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD)

##
##-----------------------------------------------------------------------

all: $(SPAWNER)

install-spawner: $(SPAWNER)
	@echo "+ inst:" `basename $<` "-> $(FLUMESRVBIN)"
	@mkdir -p $(FLUMESRVBIN)
	$(V)$(LT_INSTALL) $(BINMODE) $< $(FLUMESRVBIN) $(V_REDIRECT)
