
SRCDIR_LIBFLUME_SRV = srv/libflume-srv
OBJDIR_LIBFLUME_SRV = $(OBJDIR)/$(SRCDIR_LIBFLUME_SRV)

OBJDIRS     += $(OBJDIR_LIBFLUME_SRV)
SRV_INCLUDE += -I$(OBJDIR_LIBFLUME_SRV) -I$(SRCDIR_LIBFLUME_SRV)

LIBFLUME_SRV_OFILES := asyncutil.lo circbuf.lo const.lo ea.lo evalctx.lo \
	filter.lo fsutil.lo handlemgr.lo iddutil.lo okcompat.lo \
	slave.lo spawnutil.lo testharness.lo unixutil.lo cfg.lo

LIBFLUME_SRV_OBJS = $(foreach ofile, $(LIBFLUME_SRV_OFILES), \
			$(OBJDIR_LIBFLUME_SRV)/$(ofile) )

LIBFLUME_SRV_LA = $(OBJDIR_LIBFLUME_SRV)/libflume-srv.la

FLUME_SRV_LAS := $(LIBFLUME_SRV_LA) $(FLUME_SRV_LAS)

##-----------------------------------------------------------------------
##
## Build sources and .C files for tamed things.
##

objdir = $(OBJDIR_LIBFLUME_SRV)
srcdir = $(SRCDIR_LIBFLUME_SRV)

include make/srv.mk

##
## end input sources and .C files 
##
##-----------------------------------------------------------------------


##-----------------------------------------------------------------------
##
## Build an so dynamically linked library
##

$(LIBFLUME_SRV_LA): $(LIBFLUME_SRV_OBJS) $(LIBFLUME_EV_LA)
	@echo "+   ld: $@"
	$(V)$(LT_LD) $(FLUME_RPATH) -shared -o $@ $(LIBFLUME_SRV_OBJS)

##
## end so build
##
##-----------------------------------------------------------------------

.PRECIOUS:  $(OBJDIR_LIBFLUME_SRV)/%.C

all: $(LIBFLUME_SRV_LA)

install-libflume-srv: \
	install-libflume-srv-lib 

install-libflume-srv-lib: $(LIBFLUME_SRV_LA)
	@echo "+ inst:" `basename $<` "-> $(FLUMELIB)"
	@mkdir -p $(FLUMELIB)
	$(V)$(LT_INSTALL) $(LIBMODE) $< $(FLUMELIB)
