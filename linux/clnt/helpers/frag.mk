SRCDIR_HELPERS = clnt/helpers
OBJDIR_HELPERS = $(OBJDIR)/$(SRCDIR_HELPERS)

OBJDIRS += $(OBJDIR_HELPERS)

FILEHELPER_OFILES = filehelper.lo
FILEHELPER_OBJS = $(foreach ofile, $(FILEHELPER_OFILES), $(OBJDIR_HELPERS)/$(ofile) )

FILEHELPER = $(OBJDIR_HELPERS)/filehelper
FILEHELPER_STATIC = $(OBJDIR_HELPERS)/filehelper-static

srcdir = $(SRCDIR_HELPERS)
objdir = $(OBJDIR_HELPERS)
include make/clnt.mk



$(FILEHELPER): $(FILEHELPER_OBJS) $(LIBFLUMECLNTC_LA) $(LIBC_LIBS_DYNAMIC)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(WRAP_LDFLAGS) $(LIBC_LD_SCRIPT) $(SFS_LDADD) $(FLUME_SRV_LDADD) 

$(FILEHELPER_STATIC): $(FILEHELPER_OBJS) $(LIBCLNT_LA) $(LIBFLUMECLNTC_LA) $(LIBC_LIBS_STATIC) $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -all-static -o $@ $^ $(WRAP_LDFLAGS) $(SFS_LDADD) $(FLUME_SRV_LDADD) 



install-clnt-helpers-%: $(OBJDIR_HELPERS)/%
	@echo "+ inst:" `basename $<` "-> $(FLUMEBIN)"
	@mkdir -p $(FLUMEBIN)
	$(V)$(LT_INSTALL) $(BINMODE) $< $(FLUMEBIN)

install-clnt-helpers: \
	install-clnt-helpers-filehelper \
	install-clnt-helpers-filehelper-static

all: $(FILEHELPER) $(FILEHELPER_STATIC)
