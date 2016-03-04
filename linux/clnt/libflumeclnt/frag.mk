
DIR = clnt/libflumeclnt

SRCDIR_LIBFLUMECLNT := $(DIR)
OBJDIR_LIBFLUMECLNT := $(OBJDIR)/$(SRCDIR_LIBFLUMECLNT)

LIBFLUMECLNTC_BASE := libflumeclnt_c.so
LIBFLUMECLNTC := $(OBJDIR_LIBFLUMECLNT)/$(LIBFLUMECLNTC_BASE)
LIBFLUMECLNTC_LA := $(OBJDIR_LIBFLUMECLNT)/libflumeclnt_c.la

LIBFLUMECLNTCXX_BASE := libflumeclnt_cxx.so
LIBFLUMECLNTCXX := $(OBJDIR_LIBFLUMECLNT)/$(LIBFLUMECLNTCXX_BASE)
LIBFLUMECLNTCXX_LA := $(OBJDIR_LIBFLUMECLNT)/libflumeclnt_cxx.la

OBJDIRS += $(OBJDIR_LIBFLUMECLNT)

LIBFLUMECLNTC_OFILES := cgl.lo
LIBFLUMECLNTC_OBJS := $(foreach ofile, $(LIBFLUMECLNTC_OFILES), \
				$(OBJDIR_LIBFLUMECLNT)/$(ofile) )

LIBFLUMECLNTC_LA := $(OBJDIR_LIBFLUMECLNT)/libflumeclnt_c.la

LIBFLUMECLNTCXX_OFILES := umgrclnt.lo htmlutil.lo flumeutil.lo
LIBFLUMECLNTCXX_OBJS := $(foreach ofile, $(LIBFLUMECLNTCXX_OFILES), \
				$(OBJDIR_LIBFLUMECLNT)/$(ofile) )
LIBFLUMECLNTCXX_LA := $(OBJDIR_LIBFLUMECLNT)/libflumeclnt_cxx.la

LIBCLNT_LA := $(LIBFLUMECLNTC_LA) $(LIBFLUMECLNTCXX_LA)

## Default build rules for .C, .T files...
objdir := $(OBJDIR_LIBFLUMECLNT)
srcdir := $(SRCDIR_LIBFLUMECLNT)
include make/clnt.mk



## Make the appropriate la / libraries at the end of the day
$(LIBFLUMECLNTC_LA): $(LIBFLUMECLNTC_OBJS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) $(FLUME_RLIB_RPATH) -shared -o $@ $^

$(LIBFLUMECLNTCXX_LA): $(LIBFLUMECLNTCXX_OBJS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) $(FLUME_RLIB_RPATH) -shared -o $@ $^ 


all: $(LIBFLUMECLNTC_LA) $(LIBFLUMECLNTCXX_LA)

install-clnt-libflumeclnt: \
	install-clnt-libflumeclntc \
	install-clnt-libflumeclntcxx

install-clnt-libflumeclntc: $(LIBFLUMECLNTC_LA)
	@echo "+ inst:" `basename $<` "-> $(FLUMERLIB)"
	@mkdir -p $(FLUMERLIB)
	$(V)$(LT_INSTALL) $(LIBMODE) $< $(FLUMERLIB)

install-clnt-libflumeclntcxx: $(LIBFLUMECLNTCXX_LA)
	@echo "+ inst:" `basename $<` "-> $(FLUMERLIB)"
	@mkdir -p $(FLUMERLIB)
	$(V)$(LT_INSTALL) $(LIBMODE) $< $(FLUMERLIB)
