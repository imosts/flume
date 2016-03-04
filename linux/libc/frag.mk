

DIR = libc

# set up global dirs and objects of note

SRCDIR_LIBC = libc
OBJDIR_LIBC = $(OBJDIR)/$(SRCDIR_LIBC)
LIBC_BASE = libc.so.6
LIBC = $(OBJDIR_LIBC)/$(LIBC_BASE)
LIBC_A = $(OBJDIR_LIBC)/libc.a
LIBC_LD_SCRIPT_BASE = libc.so
LIBC_LD_SCRIPT = $(OBJDIR_LIBC)/$(LIBC_LD_SCRIPT_BASE)
LIBC_LD_SCRIPT_PERM = $(LIBC_LD_SCRIPT).perm
MAP_EDITOR = build/edit-libc-map.pl
LIBC_EXPORT_LIST_IN = $(SRCDIR_LIBC)/exports.list.in
LIBC_EXPORT_LIST = $(OBJDIR_LIBC)/exports.list

OBJDIRS += $(OBJDIR_LIBC)

##-----------------------------------------------------------------------
##
## We have to build a few (OK, one) last objects in order to get ld.so
## to call into flume.
##
LIBC_INTERPOSE_PIC_LIB = $(OBJDIR_LIBC)/libc-interpose-pic.a
LIBC_INTERPOSE_LIB = $(OBJDIR_LIBC)/libc-interpose.a

LIBC_INTERPOSE_CFILES = \
	open.c \
	mkdir.c \
	link.c \
	symlink.c \
	chmod.c \
	close.c \
	unlink.c \
	rmdir.c \
	readlink.c \
	utimes.c \
	rename.c \
	access.c \
	xstat.c \
	xstat64.c \
	lxstat.c \
	lxstat64.c \
	getpid.c \
	socket.c \
	connect.c \
	dup.c

LIBC_INTERPOSE_OSFILES = $(patsubst %.c, %.os, $(LIBC_INTERPOSE_CFILES))
LIBC_INTERPOSE_OFILES = $(patsubst %.c, %.o, $(LIBC_INTERPOSE_CFILES))

LIBC_INTERPOSE_PIC_OBJS = $(foreach ofile, $(LIBC_INTERPOSE_OSFILES), \
				$(OBJDIR_LIBC)/$(ofile) )
LIBC_INTERPOSE_OBJS = $(foreach ofile, $(LIBC_INTERPOSE_OFILES), \
				$(OBJDIR_LIBC)/$(ofile) )

$(OBJDIR_LIBC)/%.os: $(SRCDIR_LIBC)/%.c
	@echo "+  gcc: $<"
	@mkdir -p $(@D)
	$(V)$(CC) $(LIBC_PIC_CFLAGS) $(LIBC_INCLUDE) -c -o $@ $<

$(OBJDIR_LIBC)/%.o: $(SRCDIR_LIBC)/%.c
	@echo "+  gcc: $<"
	@mkdir -p $(@D)
	$(V)$(CC) $(LIBC_CFLAGS) $(LIBC_INCLUDE) -c -o $@ $<

$(LIBC_INTERPOSE_PIC_LIB): $(LIBC_INTERPOSE_PIC_OBJS)
	@echo "+   ld: $@"
	$(V)$(LD) -r -o $@ $^

$(LIBC_INTERPOSE_LIB): $(LIBC_INTERPOSE_OBJS)
	@echo "+   ld: $@"
	$(V)$(LD) -r -o $@ $^


##
## end rtld-interpose.os
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
## Generate stripped down version of libc archive
##

LIBC_PIC_REM_ARCHIVE = $(OBJDIR_LIBC)/libc_pic_rem.a
LIBC_REM_ARCHIVE = $(OBJDIR_LIBC)/libc_rem.a
GLIBC_PIC_ARCHIVE = $(OBJDIR_GLIBC)/libc_pic.a
GLIBC_ARCHIVE = $(OBJDIR_GLIBC)/libc.a

GLIBC_EXCLUDE_OS = \
		io/open.os \
		io/open64.os \
		io/mkdir.os \
		io/link.os \
		io/symlink.os \
		io/chmod.os \
		io/close.os \
		io/unlink.os \
		io/rmdir.os \
		io/readlink.os \
		io/rename.os \
		misc/utimes.os \
		io/access.os \
		io/xstat.os \
		io/xstat64.os \
		io/lxstat.os \
		io/lxstat64.os \
		posix/getpid.os \
		io/socket.os \
		io/connect.os \
		io/dup.os

GLIBC_EXCLUDE_O = $(patsubst %.os, %.o, $(GLIBC_EXCLUDE_OS))

$(LIBC_PIC_REM_ARCHIVE): $(GLIBC_BUILD_STAMP) $(SRCDIR_LIBC)/frag.mk
	@echo "+ strp: $@"
	@mkdir -p $(@D)
	$(V)cp $(GLIBC_PIC_ARCHIVE) $@ \
		&& ar -d $@ $(notdir $(GLIBC_EXCLUDE_OS))

$(LIBC_REM_ARCHIVE): $(GLIBC_BUILD_STAMP) $(SRCDIR_LIBC)/frag.mk
	@echo "+ strp: $@"
	@mkdir -p $(@D)
	$(V)cp $(GLIBC_ARCHIVE) $@ && ar -d $@ $(notdir $(GLIBC_EXCLUDE_O))

##
## end libc archive generation
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
## Collect all of the objects that we'll be using when making our
## final product ld.so
## 

LIBC_INPUTS := $(LIBC_INTERPOSE_PIC_LIB) $(LIBC_PIC_REM_ARCHIVE) $(FLUMEC_PIC_LIB)

##
## end collection of ld.so object inputs
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
##  Preprocess the export map

$(LIBC_EXPORT_LIST): $(LIBC_EXPORT_LIST_IN)
	@echo "+  gen: $@"
	$(V)$(EXPORT_EXPANDER) < $< > $@

##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
## Generate ld.so.map and ld.so, as taken from plash
##

LIBC_LINKER_SCRIPT := $(OBJDIR_GLIBC)/libc.so.lds
LIBC_GLIBC_LDMAP := $(OBJDIR_GLIBC)/libc.map
FLUME_LIBC_LDMAP := $(OBJDIR_LIBC)/libc.flume.map

$(FLUME_LIBC_LDMAP): $(LIBC_GLIBC_LDMAP) $(MAP_EDITOR) $(LIBC_EXPORT_LIST)
	@echo "+  gen: $@"
	@mkdir -p $(@D)
	$(V)$(PERL) $(MAP_EDITOR) $(LIBC_EXPORT_LIST) < $< > $@

$(LIBC_LINKER_SCRIPT): $(SRCDIR_LIBC)/frag.mk
	@echo "+  gen: $@"
	@mkdir -p $(@D)
	$(V)$(CC) -shared -Wl,-O1 -nostdlib -nostartfiles \
	-Wl,-dynamic-linker=/lib/ld-linux.so.2 \
	-Wl,-z,combreloc \
	-Wl,--verbose 2>&1 | \
    sed  \
        -e '/^=========/,/^=========/!d;/^=========/d' \
        -e 's/^.*\.hash[ 	]*:.*$$/  .note.ABI-tag : { *(.note.ABI-tag) } &/' \
        -e 's/^.*\*(\.dynbss).*$$/& \
	 PROVIDE(__start___libc_freeres_ptrs = .); \
	 *(__libc_freeres_ptrs) \
	 PROVIDE(__stop___libc_freeres_ptrs = .);/' \
	> $@



# Comment from Plash:
#
# Arguments that have been removed:
#   -L	. -Lmath -Lelf -Ldlfcn -Lnss -Lnis -Lrt -Lresolv -Lcrypt -Llinuxthreads
#   -Wl,-rpath-link=.:math:elf:dlfcn:nss:nis:rt:resolv:crypt:linuxthreads
# echo NB. could remove -Wl,-O1 for faster linking
#
# MK: Unfortunately, need to link against $(LDSO_STD) rather than
# $(LDSO); not sure why.
#
$(LIBC): $(LIBC_LINKER_SCRIPT) $(LIBC_INPUTS) $(LIBC_GLIBC_LDMAP) $(LDSO) \
	$(FLUME_LIBC_LDMAP)
	@echo "+   ld: $@"
	$(V)$(CC) $(V_LINKER) -Wl,--no-keep-memory -Wl,-O1 \
	-shared -static-libgcc \
	-Wl,-z,defs \
	-Wl,-dynamic-linker=$(LDSO) \
	-Wl,--version-script=$(FLUME_LIBC_LDMAP) \
	-Wl,-soname=libc.so.6 \
	-Wl,-z,combreloc \
	-nostdlib -nostartfiles -e __libc_main -u __register_frame \
	-o $@ \
	-T $(LIBC_LINKER_SCRIPT) \
	$(OBJDIR_GLIBC)/csu/abi-note.o \
	$(OBJDIR_GLIBC)/elf/soinit.os \
        -Wl,--whole-archive $(LIBC_PIC_REM_ARCHIVE) -Wl,--no-whole-archive \
	$(LIBC_INTERPOSE_PIC_LIB) \
	$(FLUMEC_PIC_LIB) \
	$(OBJDIR_GLIBC)/elf/sofini.os  \
	$(OBJDIR_GLIBC)/elf/interp.os  \
	$(LDSO) \
	-lgcc -lgcc_eh  

#
# The permanent libc.so link script, that will be installed in the global
# place on the system for this..
#
$(LIBC_LD_SCRIPT_PERM): $(LIBC)
	@echo "+  gen: $@"
	@echo "OUTPUT_FORMAT($(ELF_FORMAT))" > $@
	@echo "GROUP( " $(FLUMERLIB)/$(LIBC_BASE) " /usr/lib/libc_nonshared.a AS_NEEDED( $(LDSO_LINK)  ))" >> $@

#
# The temporary (build-time) script that is used only when building other 
# flume programs that need to link against the new libc (such as launchers
#
$(LIBC_LD_SCRIPT): $(LIBC)
	@echo "+  gen: $@"
	@echo "OUTPUT_FORMAT($(ELF_FORMAT))" > $@
	@echo "GROUP( " $(LIBC) " /usr/lib/libc_nonshared.a AS_NEEDED( $(LDSO_LINK) ))" >> $@

#
# Static version of flume libc
#
$(LIBC_A): $(LIBC_REM_ARCHIVE) $(LIBC_INTERPOSE_LIB) $(FLUMEC_LIB)
	@echo "+   ld: $@"
	@mkdir -p $(@D)
	$(V)ar -cr $@ $^

##
## End plash-borrowed stuff
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
## top level rules
##

all: $(LIBC) $(LIBC_LD_SCRIPT) $(LIBC_LD_SCRIPT_PERM) $(LIBC_A)

install-libc: \
	install-libc-libc-so \
	install-libc-ld-script \
	install-libc-libc-a

install-libc-libc-so: $(LIBC)
	@echo "+ inst:" `basename $<` "-> $(FLUMERLIB)"
	@mkdir -p $(FLUMERLIB)
	$(V)$(LT_INSTALL) $(LIBMODE) $< $(FLUMERLIB) 

install-libc-ld-script: $(LIBC_LD_SCRIPT_PERM)
	@echo "+ inst:" $@ "->" $(FLUMERLIB)/$(LIBC_LD_SCRIPT_BASE)
	$(V)$(INSTALL) $(LIBMODE) $< $(FLUMERLIB)/$(LIBC_LD_SCRIPT_BASE)

install-libc-libc-a: $(LIBC_A)
	@echo "+ inst:" `basename $<` "-> $(FLUMERLIB)"
	@mkdir -p $(FLUMERLIB)
	$(V)$(INSTALL) $(LIBMODE) $< $(FLUMERLIB)

##
## end top level rules
##
##-----------------------------------------------------------------------

