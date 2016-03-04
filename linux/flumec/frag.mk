
DIR := flumec

OBJDIR_LIB := $(OBJDIR)/$(DIR)-lib
OBJDIR_LIB_LDSO := $(OBJDIR)/$(DIR)-ldso

FLUMEC_LDSO := $(OBJDIR_LIB_LDSO)/rtld-flumec.os
FLUMEC_PIC_LIB  := $(OBJDIR_LIB)/libc-flumec-pic.a
FLUMEC_LIB  := $(OBJDIR_LIB)/libc-flumec.a

SOCKETCALL_H = $(OBJDIR_LIB)/socketcall.h
LIBC_SOCKETCALL_H = $(GLIBC_SRC)/sysdeps/unix/sysv/linux/socketcall.h

# Global list of all object directories
OBJDIRS += $(OBJDIR_LIB) $(OBJDIR_LIB_LDSO)

#
# The minimal number of flume/sfs libraries needed to build Flume
#

LDSO_CFILES = flume_prot.c srpc.c rwfd.c connect.c stat.c \
	flumelibc.c internal.c fds.c xdr_misc.c stubs.c err.c 

#
# Flume-specific syscalls are found in flumeclnt.c, and are not needed in
# building ld.so
#
LIB_CFILES = $(LDSO_CFILES) flumeclnt.c data.c armor.c data_arr.c flumefork.c

LDSO_OFILES_BASE = $(patsubst %.c,%.os,$(LDSO_CFILES))
LIB_OSFILES_BASE = $(patsubst %.c, %.os, $(LIB_CFILES))
LIB_OFILES_BASE = $(patsubst %.c, %.o, $(LIB_CFILES))

LDSO_OFILES := $(foreach ofile, $(LDSO_OFILES_BASE), \
		 $(OBJDIR_LIB_LDSO)/$(ofile) )

LIB_OSFILES := $(foreach ofile, $(LIB_OSFILES_BASE), $(OBJDIR_LIB)/$(ofile) )

FLUMEC_LIB_OFILES := $(foreach ofile, $(LIB_OFILES_BASE), $(OBJDIR_LIB)/$(ofile) )

LIB_HFILES := \
	flume_alias.h \
	flume_api.h \
	flume_bf60.h \
	flume_clnt.h \
	flume_const.h \
	flume_cpp.h \
	flume_debug.h \
	flume_ev.h \
	flume_ev_debug.h \
	flume_ev_debug_int.h \
	flume_features.h \
	flume_internal.h \
	flume_libc_stubs.h \
	flume_rpc.h \
	flume_sfs.h  \
	flume_pid.h

LIB_HEADERS := $(OBJDIR_PROT)/flume_prot.h \
	$(foreach hfile, $(LIB_HFILES), include/$(hfile) )


$(SOCKETCALL_H): $(LIBC_SOCKETCALL_H)
	@echo "+  cp: $<"
	@mkdir -p $(@D)
	$(V)cp $< $@

##-----------------------------------------------------------------------
##

#
# Generate the .c and .h files from flume_prot.x, and put them
# somewhere under the build dir. Note that we're using the SFS
# RPC generator, since we need things like rpc_program_t that 
# SFS generates for us.
#
$(OBJDIR_PROT)/flume_prot.c: $(SRCDIR_PROT)/flume_prot.x \
		$(OBJDIR_PROT)/flume_prot.h
	@echo "+ arpc: $@"
	@mkdir -p $(@D)
	$(V)$(ARPCGEN) -o $@ -c $< || (rm -f $@ && false)

$(OBJDIR_PROT)/flume_prot.h: $(SRCDIR_PROT)/flume_prot.x
	@echo "+ arpc: $@"
	@mkdir -p $(@D)
	$(V)$(ARPCGEN) -r flume_rpc.h -o $@ -h $< || (rm -f $@ && false)

##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

#
# Generate object files from the .c/.h protocol stubs; one for
# both libc and ld.so varieties.
#
$(OBJDIR_LIB)/flume_prot.os: $(OBJDIR_PROT)/flume_prot.c \
			$(OBJDIR_PROT)/flume_prot.h
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(CC) $(LIBC_PIC_CFLAGS) $(LIBC_INCLUDE) -c -o $@ $<

$(OBJDIR_LIB)/flume_prot.o: $(OBJDIR_PROT)/flume_prot.c \
			$(OBJDIR_PROT)/flume_prot.h
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(CC) $(LIBC_CFLAGS) $(LIBC_INCLUDE) -c -o $@ $<

$(OBJDIR_LIB_LDSO)/flume_prot.os: $(OBJDIR_PROT)/flume_prot.c \
			$(OBJDIR_PROT)/flume_prot.h
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(CC) $(LDSO_CFLAGS) $(LDSO_INCLUDE) -c -o $@ $<
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

# 
# Generic rules for making .c -> .os in the case of regular libc,
# and .c -> .os in the case of ld.so. 
#
$(OBJDIR_LIB)/%.os: $(DIR)/%.c $(SOCKETCALL_H)
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(CC) $(LIBC_PIC_CFLAGS) $(INCLUDE) -I$(OBJDIR_LIB) -c -o $@ $<

$(OBJDIR_LIB)/%.o: $(DIR)/%.c $(SOCKETCALL_H)
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(CC) $(LIBC_CFLAGS) $(INCLUDE) -I$(OBJDIR_LIB) -c -o $@ $<

$(OBJDIR_LIB_LDSO)/%.os: $(DIR)/%.c $(SOCKETCALL_H)
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(CC) $(LDSO_CFLAGS) $(LDSO_INCLUDE) -I$(OBJDIR_LIB) -c -o $@ $<
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

#
# partially link
#
$(FLUMEC_LDSO): $(LDSO_OFILES)
	@echo "+   ld: $@"
	$(V)$(LD) -r -o $@ $^

#
# Will be used more in libc
#
$(FLUMEC_PIC_LIB): $(LIB_OSFILES)
	@echo "+   ld: $@"
	$(V)$(LD) -r -o $@ $^

#
# Will be used more in libc
#
$(FLUMEC_LIB): $(FLUMEC_LIB_OFILES)
	@echo "+   ld: $@"
	$(V)$(LD) -r -o $@ $^

##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

all: $(FLUMEC_LDSO) $(FLUMEC_LIB) $(FLUMEC_PIC_LIB)

#
# Don't install the ld.so stuff; it's just here temporarily.
#
install-flumec: \
	install-flumec-include 

install-flumec-include: $(LIB_HEADERS)
	@mkdir -p $(FLUMEINC)
	$(V)for h in $^; do \
		echo "+ inst:" `basename $$h` " -> $(FLUMEINC)" ; \
		$(INSTALL) $(LIBMODE) $$h $(FLUMEINC) ; \
	done

##
##-----------------------------------------------------------------------
