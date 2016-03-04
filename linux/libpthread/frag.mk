##-----------------------------------------------------------------------
##
## What's this?
##
##   It turns out that when glibc is compiled, a library for libpthread
##   is also created, and then installed on a regular system.  The issue
##   is that libpthread calls into regular open(2).  So when python opens
##   libpthread (as it does, before libc), then calls to os.open will
##   get the open(2) from libpthread.  We want to avoid that situation
##   so we make a modified libpthread and install it in our runtime,
##   right alongside libc.
##
##-----------------------------------------------------------------------

DIR = libpthread

SRCDIR_LIBPTHREAD = libpthread
OBJDIR_LIBPTHREAD = $(OBJDIR)/$(SRCDIR_LIBPTHREAD)

LIBPTHREAD_BASE = libpthread.so
LIBPTHREAD_BASE_V = $(LIBPTHREAD_BASE).0
LIBPTHREAD = $(OBJDIR_LIBPTHREAD)/$(LIBPTHREAD_BASE)

OBJDIRS += $(OBJDIR_LIBPTHREAD)

##-----------------------------------------------------------------------

LIBPTHREAD_EXTRA_LIB = $(OBJDIR_LIBPTHREAD)/libpthread-extra.os

LIBPTHREAD_EXTRA_CFILES = extra.c
LIBPTHREAD_EXTRA_OFILES = $(patsubst %.c, %.os, $(LIBPTHREAD_EXTRA_CFILES))

LIBPTHREAD_EXTRA_OBJS = $(foreach ofile, $(LIBPTHREAD_EXTRA_OFILES), \
				$(OBJDIR_LIBPTHREAD)/$(ofile) )

##-----------------------------------------------------------------------

$(OBJDIR_LIBPTHREAD)/%.os: $(SRCDIR_LIBPTHREAD)/%.c
	@echo "+  gcc: $<"
	@mkdir -p $(@D)
	$(V)$(CC) $(LIBC_PIC_CFLAGS) $(LIBC_INCLUDE) -c -o $@ $<

$(LIBPTHREAD_EXTRA_LIB): $(LIBPTHREAD_EXTRA_OBJS)
	@echo "+   ld: $@"
	$(V)$(LD) -r -o $@ $^

##-----------------------------------------------------------------------

LIBPTHREAD_REM_ARCHIVE = $(OBJDIR_LIBC)/libpthread_rem.a
LIBPTHREAD_GLIBC_ARCHIVE = $(OBJDIR_GLIBC)/nptl/libpthread_pic.a

LIBPTHREAD_EXCLUDE = 	ptw-open.os \
			ptw-open64.os \
			ptw-connect.os \
			ptw-close.os 

$(LIBPTHREAD_REM_ARCHIVE): $(LIBPTHREAD_GLIBC_ARCHIVE) $(SRCDIR_LIBC)/frag.mk $(SRCDIR_LIBPTHREAD)/frag.mk
	@echo "+ strp: $@"
	@mkdir -p $(@D)
	$(V)cp $< $@ && ar -d $@ $(notdir $(LIBPTHREAD_EXCLUDE))

LIBPTHREAD_INPUTS = $(LIBPTHREAD_REM_ARCHIVE) $(LIBPTHREAD_EXTRA_LIB)

##-----------------------------------------------------------------------

$(LIBPTHREAD): $(LIBPTHREAD_INPUTS) $(LIBC) $(LDSO)
	@echo "+   ld: $@"
	$(V)$(CC) -shared -static-libgcc -Wl,-O1 -Wl,-z,defs \
		-Wl,-dynamic-linker=build-tree/obj/ld.so/ld.so \
		-B$(OBJDIR_LIBPTHREAD)/libpthread -Bcsu \
		-Wl,--version-script=$(OBJDIR_GLIBC)/libpthread.map \
		-Wl,-soname=$(LIBPTHREAD_BASE_V) \
		-Wl,-z,combreloc \
		-Wl,-z,relro \
		-Wl,--enable-new-dtags,-z,nodelete \
		-Wl,--enable-new-dtags,-z,initfirst \
		-e __nptl_main \
		-o $@ \
		-T $(OBJDIR_GLIBC)/shlib.lds \
		$(OBJDIR_GLIBC)/csu/abi-note.o \
		-Wl,--whole-archive $(LIBPTHREAD_INPUTS) \
		-Wl,--no-whole-archive \
		$(OBJDIR_GLIBC)/elf/interp.os \
		$(LIBC) \
		$(OBJDIR_GLIBC)/libc_nonshared.a $(LDSO)

##-----------------------------------------------------------------------

all: $(LIBPTHREAD)

install-libpthread: \
	install-libpthread-so \
	install-libpthread-lnk

install-libpthread-so: $(LIBPTHREAD)
	@echo "+ inst:" $@ "->" $(FLUMERLIB)
	$(V)$(INSTALL) $(LIBMODE) $< $(FLUMERLIB)

install-libpthread-lnk:  
	@echo "+ link:" $(FLUMERLIB)/$(LIBPTHREAD_BASE_V) "->" $(LIBPTHREAD_BASE)
	$(V)ln -sf $(LIBPTHREAD_BASE) $(FLUMERLIB)/$(LIBPTHREAD_BASE_V)
