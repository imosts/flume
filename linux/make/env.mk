
MYCFG = bin/flume-cfg

PREFIX = $(shell ${MYCFG} runprefix)
TAG ?= $(shell ${MYCFG} tag)
STD_PREFIX = /usr

SFSLITE_VERS=""

SFSLIB = /usr/local/lib/sfslite$(SFSLITE_VERS)/$(TAG)
SFSINC = /usr/local/include/sfslite$(SFSLITE_VERS)/$(TAG)
TAME = $(SFSLIB)/tame
ARPCGEN = $(SFSLIB)/arpcgen
RPCC = $(SFSLIB)/rpcc

MYSQL_LDADD := -L/usr/lib -lmysqlclient -lz
MYSQL_INCLUDE := -I/usr/include/mysql

GMP_ADD := -L/usr/lib -lgmp

USER  = $(shell ${MYCFG} user )
GROUP = $(shell ${MYCFG} group )

#
# Figure out if we're on 64-bit or 32-bit linux.  Is this an outrageous
# technique or what?
# 
CPU_BITS := $(shell getconf LONG_BIT)

ifeq ($(CPU_BITS), 64)
X86_64 := 1
ELF_FORMAT=elf64-x86-64
else
ELF_FORMAT=elf32-i386
endif

#
# Set reasonable defaults for glibc; can override in local.mk
#
GLIBC_VERSION := $(shell getconf GNU_LIBC_VERSION | sed -e 's/ /-/' )
GLIBC_VERSNO := $(shell getconf GNU_LIBC_VERSION | awk '{ print $$2 }' )
GLIBC_TARBALL := $(GLIBC_VERSION).tar.bz2
GLIBC_UNTAR_FLAGS := -jx
LDSO_LOCATION := /lib/ld-$(GLIBC_VERSNO).so


LDSO_LINK_BASE := $(if $(X86_64),ld-linux-x86-64.so.2,ld-linux.so.2)
LDSO_LINK := /lib/$(LDSO_LINK_BASE)



#
# Setup a compiler; feel free to override in local.mk if this does not 
# suit you.
#
CC := gcc

#
# Set up dmalloc linking if needed.
#
DMALLOC_LDADD := $(shell $(MYCFG) dmalloc)
