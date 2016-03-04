
DIR = srv/idd

SRCDIR_IDD = $(DIR)
OBJDIR_IDD = $(OBJDIR)/$(SRCDIR_IDD)

OBJDIRS += $(OBJDIR_IDD)
SRV_INCLUDE += -I$(SRCDIR_IDD)

IDD_OFILES = main.lo idd.lo
IDD_OBJS = $(foreach ofile, $(IDD_OFILES), $(OBJDIR_IDD)/$(ofile) )

IDD = $(OBJDIR_IDD)/idd

##-----------------------------------------------------------------------
##

srcdir = $(SRCDIR_IDD)
objdir = $(OBJDIR_IDD)

include make/srv.mk

##
##-----------------------------------------------------------------------


##-----------------------------------------------------------------------
##

$(IDD): $(IDD_OBJS) $(LIBAMYSQL_LA) $(FLUME_SRV_LAS)
	$(V)$(LT_LD) -o $@ $^ $(LIBAMYSQL_LA) $(FLUME_SRV_LDADD) $(MYSQL_LDADD)

##
##-----------------------------------------------------------------------

all: $(IDD)

install-idd: $(IDD)
	@echo "+ inst:" `basename $<` "-> $(FLUMESRVBIN)"
	@mkdir -p $(FLUMESRVBIN)
	$(V)$(LT_INSTALL) $(BINMODE) $< $(FLUMESRVBIN)
