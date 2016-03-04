
SRCDIR_LAUNCHERS = clnt/launchers
OBJDIR_LAUNCHERS = $(OBJDIR)/$(SRCDIR_LAUNCHERS)

OBJDIRS += $(OBJDIR_LAUNCHERS)
SRV_INCLUDE += -I$(SRCDIR_LAUNCHERS)

CGILAUNCH_OFILES = cgilaunch.lo
MOINLAUNCH_OFILES = generichelpers.lo moinhelpers.lo moinlaunch.lo
WCLAUNCH_OFILES = generichelpers.lo wclaunch.lo wctrusted.lo

CGILAUNCH_OBJS = $(foreach ofile, $(CGILAUNCH_OFILES), $(OBJDIR_LAUNCHERS)/$(ofile) )
MOINLAUNCH_OBJS = $(foreach ofile, $(MOINLAUNCH_OFILES), $(OBJDIR_LAUNCHERS)/$(ofile) )
WCLAUNCH_OBJS = $(foreach ofile, $(WCLAUNCH_OFILES), $(OBJDIR_LAUNCHERS)/$(ofile) )

CGILAUNCH = $(OBJDIR_LAUNCHERS)/cgilaunch
MOINLAUNCH = $(OBJDIR_LAUNCHERS)/moinlaunch
MOINLAUNCH_STATIC = $(OBJDIR_LAUNCHERS)/moinlaunch-static
WCLAUNCH = $(OBJDIR_LAUNCHERS)/wclaunch

##-----------------------------------------------------------------------
##

srcdir = $(SRCDIR_LAUNCHERS)
objdir = $(OBJDIR_LAUNCHERS)
include make/clnt.mk

##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

## dynamic apps need to be linked against $LDSO for _flume_socket and _flume_attempted_connect

$(CGILAUNCH): $(CGILAUNCH_OBJS) $(FLUME_SRV_LAS) $(LIBCLNT_LA) \
		$(LIBC_LIBS_DYNAMIC)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(WRAP_LDFLAGS) $(LIBC_LD_SCRIPT) $(SFS_LDADD) $(FLUME_SRV_LDADD) 

$(MOINLAUNCH): $(MOINLAUNCH_OBJS) $(LIBCLNT_LA) $(FLUME_SRV_LAS) \
		$(LIBC_LIBS_DYNAMIC)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(WRAP_LDFLAGS) $(LIBC_LD_SCRIPT) $(SFS_LDADD) $(FLUME_SRV_LDADD) 

$(MOINLAUNCH_STATIC): $(MOINLAUNCH_OBJS) $(LIBCLNT_LA) $(FLUME_SRV_LAS) \
		$(LIBC_LIBS_STATIC)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -all-static -o $@ $^ $(WRAP_LDFLAGS) $(SFS_LDADD) $(FLUME_SRV_LDADD) 

$(WCLAUNCH): $(WCLAUNCH_OBJS) $(LIBCLNT_LA) $(FLUME_SRV_LAS) \
		$(LIBC_LIBS_DYNAMIC)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(WRAP_LDFLAGS) $(LIBC_LD_SCRIPT) $(SFS_LDADD) $(FLUME_SRV_LDADD)  

##
##-----------------------------------------------------------------------

install-clnt-launchers: \
	install-clnt-launchers-cgilaunch \
	install-clnt-launchers-moinlaunch \
	install-clnt-launchers-moinlaunch-static \
	install-clnt-launchers-wclaunch

install-clnt-launchers-% : $(OBJDIR_LAUNCHERS)/%
	@echo "+ inst:" `basename $<` "-> $(FLUMEBIN)"
	@mkdir -p $(FLUMEBIN)
	$(V)$(LT_INSTALL) $(BINMODE) $< $(FLUMEBIN)

all: $(MOINLAUNCH) $(MOINLAUNCH_STATIC) $(CGILAUNCH) $(WCLAUNCH)
