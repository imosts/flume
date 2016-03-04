
PREFIX := /usr/local
USER := root
GROUP := wheel

# set the $(PREFIX) variable (and others) in your conf/env.mk
-include make/env.mk

# set local settings for this machine
-include make/local.mk

# Depending on what the 'V' verbose parameter is, redirect output
# of libtool and friends to dev/null
ifdef V
	V_REDIRECT = > /dev/null
	V_LIBTOOL = --quiet
	V_LINKER =
	V_PYTHON = --quiet
	V_PATCH = --quiet
else
	V_REDIRECT =
	V_LIBTOOL =
	V_LINKER = -Wl,--stats
	V_PYTHON =
	V_PATCH = 
endif

# All generated files are under TMPROOT;  note this can be a symlink
# to a partition somewhere else off of NFS in situations where it's
# useful to avoid building over NFS.
TMPROOT ?= build-tree
OBJDIR ?= $(TMPROOT)/obj
TMPSRCDIR ?= $(TMPROOT)/src
TMPTARDIR ?= $(TMPROOT)/tar
STAMPDIR ?= $(TMPROOT)/stamp
LOGDIR ?= $(TMPROOT)/log

#
# Where to find .x files, and where to deposit intermediate .c/.h files
# we get from running them through rpcgen.
#
OBJDIR_PROT := $(OBJDIR)/prot
OBJDIR_PROT_EV := $(OBJDIR)/prot-ev
SRCDIR_PROT := ./include/prot

TAG           ?= $(shell $(MYCFG) tag)
FLUMEINC      ?= $(shell $(MYCFG) include)
FLUMEINCEV    ?= $(shell $(MYCFG) include-ev)
FLUMELIB      ?= $(shell $(MYCFG) lib)
FLUMERLIB     ?= $(shell $(MYCFG) rlib)
FLUMESRVBIN   ?= $(shell $(MYCFG) srvbin)
FLUMEBIN      ?= $(shell $(MYCFG) bin)
FLUMETSTBIN   ?= $(shell $(MYCFG) testbin)
FLUMEKODIR    ?= $(shell $(MYCFG) kodir)
FLUMEPYBIN    ?= $(shell $(MYCFG) pybin)
FLUMEOFLAGS   ?= $(shell $(MYCFG) oflags)
FLUMECONFDIR  ?= $(shell $(MYCFG) confdir)
FLUMEIDDHOST  ?= $(shell $(MYCFG) iddhost)
FLUMEIDDPORT  ?= $(shell $(MYCFG) iddport)
FLUMEPGHOST   ?= $(shell $(MYCFG) pghost)
PYPREFIX      ?= $(shell $(MYCFG) runprefix)

STD_BIN      ?= $(STD_PREFIX)/bin

# Build tools (might have been set in conf/local.mk)
PERL ?= perl
CC ?= gcc
CXX ?= g++
LD ?= ld
SWIG ?= swig -c++
INSTALL := install -o $(USER) -g $(GROUP)
DODEPS ?= build/dodeps.sh
EXPORT_EXPANDER ?= python build/expander.py

#
# Include these subfiles, just to be a bit cleaner
#
include make/python.mk

#
# Use libtool for compiling CXX PIC objects, for linking together
# .la's and .so's, and for installing the appropriate stuff into
# the libc dir.
#
LT_CC := libtool --tag=CC $(V_LIBTOOL) --mode=compile $(CC)
LT_CXX := libtool --tag=CXX $(V_LIBTOOL) --mode=compile $(CXX)
LT_LD := libtool --tag=CXX $(V_LIBTOOL) --mode=link $(CXX)
LT_INSTALL := libtool --mode=install $(V_LIBTOOL) $(INSTALL) 

#
# includes vary on which part of the system we're building
#
INCLUDE := -Iinclude -I. -I$(OBJDIR_PROT)
LSM_INCLUDE := -I/lib/modules/$(shell uname -r)/build/include
LDSO_INCLUDE := $(INCLUDE) 
LIBC_INCLUDE := $(INCLUDE)
EV_INCLUDE := -Iinclude -I. -I$(OBJDIR_PROT_EV) -I$(SFSINC)
SRV_INCLUDE := $(EV_INCLUDE) $(MYSQL_INCLUDE)
WRAP_INCLUDE = $(INCLUDE) -Ilang/wrap/
CLNT_INCLUDE := $(INCLUDE) -Iclnt/libflumeclnt -Iclnt/launchers -I$(SFSINC) 

#
# So do CFLAGS
#
LDSO_CFLAGS := -Werror -Wall -g -D_LIBC_REENTRANT -DIN_RTLD \
 -DPIC -DSHARED -DNOT_IN_libc=1 -DIS_IN_rtld=1 -fno-stack-protector -fPIC -O2 \
 -fno-strict-aliasing -MD

LIBC_PIC_CFLAGS := -Werror -Wall -g -D_LIBC_REENTRANT -DPIC -DSHARED \
-fno-stack-protector -fPIC -O2 -fno-strict-aliasing -MD

LIBC_CFLAGS := -Werror -Wall -g -D_LIBC_REENTRANT \
-fno-stack-protector -O2 -fno-strict-aliasing -MD

LSM_CFLAGS := -Werror -Wall -g -O2 -DMODULE -D__KERNEL__ -DLINUX
STATIC_CFLAGS := -Werror -Wall -g -O2 -MD
EV_CFLAGS := -Werror -Wall -g $(FLUMEOFLAGS) 
WRAP_CFLAGS := -Werror -Wall -g -fPIC -DPIC -fno-stack-protector -MD \
$(FLUMEOFLAGS) -fno-strict-aliasing

#
# Various LDflag settings
#
SFS_LDADD := -L$(SFSLIB) -R$(SFSLIB) -ltame -lsfsmisc -larpc -lsfscrypt \
	-lasync $(GMP_ADD)

FLUME_SRV_LDADD = $(SFS_LDADD) $(DMALLOC_LDADD) -lpthread

LDFLAGS :=
FLUME_RPATH := -rpath $(FLUMELIB)
FLUME_RLIB_RPATH := -rpath $(FLUMERLIB)

WRAP_LDFLAGS = -Wl,-R$(FLUMERLIB) -L$(FLUMERLIB) -lc
NONSHARED_LDADD = $(OBJDIR)/ext-src/glibc/libc_nonshared.a

#
# When linking against flume's libc, you actually want one of these:
#  (These must be defined with "=" since $(LDSO) etc are not defined 
#  until after including ld.so/frag.mk)
#
LIBC_LIBS_DYNAMIC = $(LIBC) $(LIBC_LD_SCRIPT) $(LDSO)
LIBC_LIBS_STATIC = $(LIBC_A)

# How to install objects and libs in their appropriate places.
LIBMODE := -m 0444
EXEMODE := -m 0555

# make sure all: is the first target in the makefile
all:

.SUFFIXES:

OBJDIRS :=
SMALL_CLEARDIRS :=

include bin/frag.mk
include ext-src/glibc/frag.mk
include flumec/frag.mk
include ld.so/frag.mk
include libc/frag.mk
include libpthread/frag.mk
include lsm/frag.mk
include test/lsm/frag.mk
include libflume-ev/frag.mk
include srv/libflume-srv/frag.mk
include srv/libamysql/frag.mk
include srv/idd/frag.mk
include srv/rm/frag.mk
include srv/fs/frag.mk
include srv/spawn/frag.mk
include srv/test/unit/frag.mk
include srv/test/system/frag.mk
include lang/wrap/frag.mk
include lang/python/frag.mk
include test/python/frag.mk
include app/web/python/frag.mk
include clnt/helpers/frag.mk
include clnt/libflumeclnt/frag.mk
include clnt/launchers/frag.mk
include clnt/microbench/frag.mk
include clnt/dbv/frag.mk
include conf/frag.mk


install: \
	install-bin \
	install-flumec \
	install-libc \
	install-libpthread \
	install-libflume-ev \
	install-libflume-srv \
	install-libamysql \
	install-idd \
	install-rm \
	install-fs \
	install-spawner \
	install-srv-test-system  \
	install-lang-python \
	install-test-python \
	install-lsm \
	install-app-web-python \
	install-clnt-helpers \
	install-clnt-libflumeclnt \
	install-clnt-launchers \
	install-clnt-microbench \
	install-clnt-dbv \
	install-conf

root-install: \
	root-install-ldso \
	root-install-bin \
	root-install-lang-python 

root-insmod: \
	root-lsm-insmod

root-rmmod: \
	root-lsm-rmmod

realclean:
	rm -rf $(TMPROOT)/*

clean: \
	clean-clnt-dbv
	rm -rf $(OBJDIRS) $(OBJDIR_PROT) $(OBJDIR_PROT_EV) $(OBJDIR)/.deps

#
# Stampclean will cause an untar / patch / configure / build but
# will not wipe out the tarball.
#
stampclean:
	rm -rf $(STAMPDIR)/*

# This magic automatically generates makefile dependencies
# for header files included from C source files we compile,
# and keeps those dependencies up-to-date every time we recompile.
# See 'mergedep.pl' for more information
$(OBJDIR)/.deps: $(foreach dir, $(OBJDIRS), $(wildcard $(dir)/*.d))
	@mkdir -p $(@D)
	@$(PYTHON) build/mergedep.py $@ $^

-include $(OBJDIR)/.deps

always: 
	@:

.PHONY: all always realclean install clean stampclean root-install
