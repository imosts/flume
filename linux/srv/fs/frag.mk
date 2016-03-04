
SRCDIR_FS = srv/fs
OBJDIR_FS = $(OBJDIR)/$(SRCDIR_FS)

OBJDIRS += $(OBJDIR_FS)
SRV_INCLUDE += -I$(SRCDIR_FS)

FLUMEFS_OFILES = main.lo basesrv.lo aiodsrv.lo simplesrv.lo filter.lo
INITFS_OFILES = initfs.lo
INITFILE_OFILES = initfile.lo

FLUMEFS_OBJS = $(foreach ofile, $(FLUMEFS_OFILES), $(OBJDIR_FS)/$(ofile) )
INITFS_OBJS = $(foreach ofile, $(INITFS_OFILES), $(OBJDIR_FS)/$(ofile) )
INITFILE_OBJS = $(foreach ofile, $(INITFILE_OFILES), $(OBJDIR_FS)/$(ofile) )

FLUMEFS = $(OBJDIR_FS)/flumefs
INITFS = $(OBJDIR_FS)/initfs
INITFILE = $(OBJDIR_FS)/initfile

##-----------------------------------------------------------------------
##

srcdir = $(SRCDIR_FS)
objdir = $(OBJDIR_FS)

include make/srv.mk

##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

$(FLUMEFS): $(FLUMEFS_OBJS) $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD) 

$(INITFS): $(INITFS_OBJS) $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD)

$(INITFILE): $(INITFILE_OBJS) $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(FLUME_SRV_LDADD)

##
##-----------------------------------------------------------------------

all: $(FLUMEFS) $(INITFS) $(INITFILE)

install-fs: \
	install-fs-flumefs \
	install-fs-initfs \
	install-fs-initfile

install-fs-% : $(OBJDIR_FS)/%
	@echo "+ inst:" `basename $<` "-> $(FLUMESRVBIN)"
	@mkdir -p $(FLUMESRVBIN)
	$(V)$(LT_INSTALL) $(BINMODE) $< $(FLUMESRVBIN)
