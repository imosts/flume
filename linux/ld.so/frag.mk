
DIR := ld.so

# set up global dirs and objects of note

LDSO_DIR := $(DIR)
OBJDIR_LDSO := $(OBJDIR)/ld.so
LDSO := $(OBJDIR_LDSO)/ld.so
LDSO_RECOVER := $(OBJDIR_LDSO)/flume-ldso-recover

LDSO_EXPORT_LIST := $(LDSO_DIR)/exports.list

OBJDIRS += $(OBJDIR_LDSO)



##-----------------------------------------------------------------------
##
## We have to build a few (OK, one) last objects in order to get ld.so
## to call into flume.
##
LDSO_INTERPOSE_LIB := $(OBJDIR_LDSO)/rtld-interpose.os

LDSO_INTERPOSE_CFILES := ldso_interpose.c
LDSO_INTERPOSE_OFILES := $(patsubst %.c, %.os, $(LDSO_INTERPOSE_CFILES))

LDSO_INTERPOSE_OBJS = $(foreach ofile, $(LDSO_INTERPOSE_OFILES), \
			$(OBJDIR_LDSO)/$(ofile) )

$(OBJDIR_LDSO)/%.os: $(LDSO_DIR)/%.c
	@echo "+  gcc: $<"
	@mkdir -p $(@D)
	$(V)$(CC) $(LDSO_CFLAGS) $(LDSO_INCLUDE) -c -o $@ $<

$(LDSO_INTERPOSE_LIB): $(LDSO_INTERPOSE_OBJS)
	@echo "+   ld: $@"
	$(V)$(LD) -r -o $@ $^

##
## end rtld-interpose.os
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
## Collect all of the objects that we'll be using when making our
## final product ld.so
## 

RTLD_LIBC := $(OBJDIR_GLIBC)/elf/rtld-libc.a
DL_ALLOBJS := $(OBJDIR_GLIBC)/elf/dl-allobjs.os

LDSO_DEPS := \
	$(LDSO_INTERPOSE_LIB) \
	$(FLUMEC_LDSO) \
	$(MORELIBC_OS) \
	$(GLIBC_BUILD_STAMP)

LDSO_INPUTS := \
	$(LDSO_INTERPOSE_LIB) \
	$(FLUMEC_LDSO) \
	$(MORELIBC_OS) \
	$(DL_ALLOBJS) \
	$(RTLD_LIBC) 

##
## end collection of ld.so object inputs
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
## Generate ld.so.map and ld.so, as taken from plash
##

LDSO_LINKER_SCRIPT := $(OBJDIR_LDSO)/ld.so.lds
LDSO_GLIBC_LDMAP := $(OBJDIR_GLIBC)/ld.map
FLUME_LDSO_LDMAP := $(OBJDIR_LDSO)/ldso.flume.map

##-----------------------------------------------------------------------

##  Need to doctor the LDMAP to export some new flume-y symbols

$(FLUME_LDSO_LDMAP): $(LDSO_GLIBC_LDMAP) $(MAP_EDITOR) $(LDSO_EXPORT_LIST)
	@echo "+  gen: $@"
	@mkdir -p $(@D)
	$(V)$(PERL) $(MAP_EDITOR) $(LDSO_EXPORT_LIST) < $< > $@

##-----------------------------------------------------------------------

$(LDSO_LINKER_SCRIPT): $(LDSO_DIR)/frag.mk
	@echo "+  gen: $@"
	@mkdir -p $(@D)
	$(V)$(CC) -nostdlib -nostartfiles -shared \
	  -Wl,-z,combreloc -Wl,-z,defs -Wl,--verbose 2>&1 | \
	LC_ALL=C \
	 sed -e '/^=========/,/^=========/!d;/^=========/d'  \
	 -e 's/\. = 0 + SIZEOF_HEADERS;/& _begin = . - SIZEOF_HEADERS;/' \
	> $@

$(LDSO): $(LDSO_LINKER_SCRIPT) $(LDSO_DEPS) \
	$(GLIBC_BUILD_STAMP) $(FLUME_LDSO_LDMAP)
	@echo "+   ld: $@"
	$(V)$(CC) -nostdlib -nostartfiles -shared -o $@ \
	  -Wl,-z,combreloc \
	  -Wl,-z,defs \
	  -Wl,-z,relro \
	  '-Wl,-(' $(LDSO_INPUTS)  -lgcc '-Wl,-)' \
	  -Wl,--version-script=$(FLUME_LDSO_LDMAP) \
	  -Wl,-soname=$(LDSO_LINK_BASE) \
	  -T $(LDSO_LINKER_SCRIPT)

##
## End plash-borrowed stuff
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
## Make a little statically linked tool to recover from ld.so failures
##

LDSO_RECOVER_CFILES := ldso_recover.c
LDSO_RECOVER_OFILES := $(patsubst %.c, %.o, $(LDSO_RECOVER_CFILES))

LDSO_RECOVER_OBJS := $(foreach ofile, $(LDSO_RECOVER_OFILES), \
				$(OBJDIR_LDSO)/$(ofile) )

LDSO_LOCATION_BKP ?= $(LDSO_LOCATION).bkp

LDSO_RECOVER_DEFINES := -DLDSO_LOCATION='"'$(LDSO_LOCATION)'"' \
			-DLDSO_LOCATION_BKP='"'$(LDSO_LOCATION_BKP)'"' \
			-DLDSO_LINK='"'$(LDSO_LINK)'"'

$(OBJDIR_LDSO)/%.o: $(LDSO_DIR)/%.c
	@echo "+  gcc: $<"
	@mkdir -p $(@D)
	$(V)$(CC) $(LDSO_RECOVER_DEFINES) $(STATIC_CFLAGS) -c -o $@ $<

$(LDSO_RECOVER): $(LDSO_RECOVER_OBJS)
	@echo "+   ld: $<"
	$(V)$(CC) -static -o $@ $^

##
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
## top level rules
##

all: $(LDSO) $(LDSO_RECOVER)

#
# make the recover script setuid, in case lack of ld.so keeps us
# from making a root shell.
#
root-install-ldso-recover: $(LDSO_RECOVER)
	install -m 04755 -o root -g root $(LDSO_RECOVER) /bin

#
# Copy over the original ld-2.4.so to a similar place in the
# same directory.
#
$(LDSO_LOCATION_BKP):
	if test ! -f $(LDSO_LOCATION_BKP) ; then \
		(install -m 0755 -o root -g root $(LDSO_LOCATION) \
			$(LDSO_LOCATION_BKP) && \
		 cmp $(LDSO_LOCATION) $(LDSO_LOCATION_BKP) \
			> /dev/null 2>&1 ) || \
		( echo "XX BACKUP LD.SO FAILED!! XX" && false) ; \
	fi 

#
# Go for it.  Holy shit, I hope this works; at least use LDSO to
# install itself; if that doesn't work, there are other problems
# afoot and the install should fail.
#
root-install-ldso-ldso: $(LDSO_LOCATION_BKP)
	$(LDSO) `which install` -m 0755 -o root -g root \
		$(LDSO) $(LDSO_LOCATION)

root-install-ldso: root-install-ldso-recover root-install-ldso-ldso

##
## end top level rules
##
##-----------------------------------------------------------------------

