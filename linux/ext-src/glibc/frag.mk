
DIR := ext-src/glibc

GLIBC_PATCHES := $(DIR)/patches
GLIBC_EXTRA := $(DIR)/extra
GLIBC_DIR := $(DIR)

GLIBC_TARBALL_FULL := $(TMPTARDIR)/$(GLIBC_TARBALL)
GLIBC_SRC := $(TMPSRCDIR)/$(GLIBC_VERSION)
GLIBC_INCLUDE = $(GLIBC_SRC)/include

OBJDIR_GLIBC := $(OBJDIR)/ext-src/glibc
OBJDIR_GLIBC_MORELIBC := $(OBJDIR)/ext-src/morelibc

MORELIBC_OS := $(OBJDIR_GLIBC_MORELIBC)/rtld-morelibc.os

UNTAR_STAMP   := $(STAMPDIR)/glibc-untar-stamp
PATCH_STAMP   := $(STAMPDIR)/glibc-patch-stamp
GLIBC_BUILD_STAMP   := $(STAMPDIR)/glibc-build-stamp
CONFIG_STAMP   := $(STAMPDIR)/glibc-config-stamp
FETCH_STAMP    := $(STAMPDIR)/glibc-fetch-stamp

GLIBC_CONFIG_H := $(OBJDIR_GLIBC)/config.h
GLIBC_CONFIGURE := $(GLIBC_SRC)/configure

##-----------------------------------------------------------------------
##
## Rules to build glibc, with very slight ld.so patches.
##

# download the tarball
$(FETCH_STAMP): 
	@echo "+ ftch: $(GLIBC_TARBALL_FULL)"
	@mkdir -p $(dir $(FETCH_STAMP) )
	@mkdir -p $(dir $(GLIBC_TARBALL_FULL) )
	$(V)if test ! -f $(GLIBC_TARBALL_FULL) ; then \
		(cd $(TMPTARDIR) && \
		 wget $(GLIBC_FTP_SITE)/$(GLIBC_TARBALL) ) && \
		 date > $@  ; \
	else  \
		test -f $@ || date > $@ ; \
	fi

# unpack the tarball
$(UNTAR_STAMP): $(FETCH_STAMP)
	@echo "+ untr: $(GLIBC_TARBALL_FULL)"
	@mkdir -p $(@D)
	@mkdir -p $(TMPSRCDIR)
	$(V)PWD=`pwd` 
	$(V)(cd $(TMPSRCDIR) && \
	 tar $(GLIBC_UNTAR_FLAGS) -f $(PWD)/$(GLIBC_TARBALL_FULL)  ) && \
	date > $@

# apply the patch
$(PATCH_STAMP): $(UNTAR_STAMP)
	@echo "+ ptch: $(GLIBC_SRC)"
	@mkdir -p $(OBJDIR_GLIBC)
	$(V)PWD=`pwd` 
	$(V)(cd $(GLIBC_SRC) && \
	 patch $(V_PATCH) -p0 < $(PWD)/$(GLIBC_PATCHES)/glibc-ld.so-patch && \
	 patch $(V_PATCH) -p0 < $(PWD)/$(GLIBC_PATCHES)/gconv-patch ) 
	cp $(GLIBC_EXTRA)/flume-ld-so-interpose.h $(GLIBC_SRC)/elf && \
	cp $(GLIBC_EXTRA)/interpose_stub.c \
	  $(GLIBC_SRC)/elf/dl-flume-interpose.c  && \
	date > $@

# run configure
$(CONFIG_STAMP): $(PATCH_STAMP)
	@echo "+  cfg: $(GLIBC_SRC)"
	@mkdir -p $(LOGDIR)
	$(V)PWD=`pwd`
	$(V)(cd $(OBJDIR_GLIBC) && \
	 CC="$(CC) -fno-stack-protector" \
	 $(PWD)/$(GLIBC_SRC)/configure --prefix=/usr \
				--without-selinux \
				--with-tls \
				--disable-profile ) $(V_REDIRECT) && \
	date > $@

# now do the build
$(GLIBC_BUILD_STAMP): $(CONFIG_STAMP)
	@echo "+ make: $(OBJDIR_GLIBC) [this might take a while]"
	@mkdir -p $(LOGDIR)
	$(V)(cd $(OBJDIR_GLIBC) && $(MAKE) $(PARALLELMFLAGS) ) $(V_REDIRECT) \
	 && date > $@
##
## end of glibc rules
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
## Rules to build the rest of glibc for ld.so, objects that are not 
## normally needed for regular ld.so
##
MORELIBC_OBJS := socket/rtld-recvmsg.os \
		socket/rtld-sendmsg.os \
		socket/rtld-send.os \
		socket/rtld-cmsg_nxthdr.os \
		string/rtld-strncpy.os \
		sunrpc/rtld-xdr_array.os \
		sunrpc/rtld-xdr_intXX_t.os \
		sunrpc/rtld-xdr_mem.os \
		sunrpc/rtld-xdr.os \
		sunrpc/rtld-xdr_ref.os \
		sunrpc/rtld-rpc_prot.os \
		inet/rtld-htonl.os \
		inet/rtld-htons.os \
		socket/rtld-socket.os \
		socket/rtld-connect.os \
		stdlib/rtld-getenv.os \
		string/rtld-strncmp.os \
		io/rtld-xstat.os \
		io/rtld-xstat64.os \
		io/rtld-lxstat.os \
		io/rtld-lxstat64.os

MORELIBC_OBJS_FULL := $(foreach os, $(MORELIBC_OBJS), $(OBJDIR_GLIBC)/$(os))

$(OBJDIR_GLIBC)/%.os: $(CONFIG_STAMP)
	@echo "+ make: $@ [extra glibc object]"
	$(V)PWD=`pwd`
	$(V)make -C $(GLIBC_SRC)/$(dir $* ) \
		objdir=$(PWD)/$(OBJDIR_GLIBC) \
		-f Makefile -f ../elf/rtld-Rules rtld-all \
		rtld-modules=$(@F) $(V_REDIRECT) && touch $@

$(MORELIBC_OS): $(MORELIBC_OBJS_FULL)
	@mkdir -p $(@D)
	@echo "+   ld: $@"
	$(V)$(LD) -r $(MORELIBC_OBJS_FULL) -o $(MORELIBC_OS)

##
## end morelibc/libc extras
##
##-----------------------------------------------------------------------

all: $(GLIBC_BUILD_STAMP) $(MORELIBC_OS)

