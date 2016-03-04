
SRCDIR_MICROBENCH = clnt/microbench
OBJDIR_MICROBENCH = $(OBJDIR)/$(SRCDIR_MICROBENCH)

OBJDIRS += $(OBJDIR_MICROBENCH)
SRV_INCLUDE += -I$(SRCDIR_MICROBENCH)

SYSCALLBENCH_FLUME_OFILES = syscall-bench-flume.lo testlib.lo
SYSCALLBENCH_LINUX_OFILES = syscall-bench-linux.lo testlib.lo

IPCBENCH_FLUME_OFILES = ipc-bench-flume.lo testlib.lo
IPCBENCH_LINUX_OFILES = ipc-bench-linux.lo testlib.lo

SYSCALLBENCH_FLUME_OBJS = $(foreach ofile, $(SYSCALLBENCH_FLUME_OFILES), $(OBJDIR_MICROBENCH)/$(ofile) )
SYSCALLBENCH_LINUX_OBJS = $(foreach ofile, $(SYSCALLBENCH_LINUX_OFILES), $(OBJDIR_MICROBENCH)/$(ofile) )
IPCBENCH_FLUME_OBJS = $(foreach ofile, $(IPCBENCH_FLUME_OFILES), $(OBJDIR_MICROBENCH)/$(ofile) )
IPCBENCH_LINUX_OBJS = $(foreach ofile, $(IPCBENCH_LINUX_OFILES), $(OBJDIR_MICROBENCH)/$(ofile) )

SYSCALLBENCH_FLUME = $(OBJDIR_MICROBENCH)/syscall-bench-flume
SYSCALLBENCH_LINUX = $(OBJDIR_MICROBENCH)/syscall-bench-linux
IPCBENCH_FLUME = $(OBJDIR_MICROBENCH)/ipc-bench-flume
IPCBENCH_LINUX = $(OBJDIR_MICROBENCH)/ipc-bench-linux

NULLCGI_OFILES = nullcgi.lo
NULLCGI_OBJS = $(foreach ofile, $(NULLCGI_OFILES), $(OBJDIR_MICROBENCH)/$(ofile) )
NULLCGI = $(OBJDIR_MICROBENCH)/nullcgi
NULLCGI_STATIC = $(OBJDIR_MICROBENCH)/nullcgi-static

##-----------------------------------------------------------------------
##

srcdir = $(SRCDIR_MICROBENCH)
objdir = $(OBJDIR_MICROBENCH)
include make/clnt.mk

##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##

$(OBJDIR_MICROBENCH)/syscall-bench-flume.lo: $(srcdir)/syscall-bench.c
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(LT_CC) -DUSE_FLUME=1 $(WRAP_CFLAGS) $(CLNT_INCLUDE) -I$(@D) $(shell $(DODEPS) -t $@ ) -c -o $@ $< && $(shell $(DODEPS) -m $@)

$(OBJDIR_MICROBENCH)/syscall-bench-linux.lo: $(srcdir)/syscall-bench.c
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(LT_CC) $(WRAP_CFLAGS) $(CLNT_INCLUDE) -I$(@D) $(shell $(DODEPS) -t $@ ) -c -o $@ $< && $(shell $(DODEPS) -m $@)

$(OBJDIR_MICROBENCH)/ipc-bench-flume.lo: $(srcdir)/ipc-bench.c
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(LT_CC) -DUSE_FLUME=1 $(WRAP_CFLAGS) $(CLNT_INCLUDE) -I$(@D) $(shell $(DODEPS) -t $@ ) -c -o $@ $< && $(shell $(DODEPS) -m $@)

$(OBJDIR_MICROBENCH)/ipc-bench-linux.lo: $(srcdir)/ipc-bench.c
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(LT_CC) $(WRAP_CFLAGS) $(CLNT_INCLUDE) -I$(@D) $(shell $(DODEPS) -t $@ ) -c -o $@ $< && $(shell $(DODEPS) -m $@)

$(SYSCALLBENCH_FLUME): $(SYSCALLBENCH_FLUME_OBJS) $(FLUME_SRV_LAS) $(LIBFLUMECLNTC_LA) \
		$(LIBFLUMECLNTCXX_LA) $(LIBC_LIBS_DYNAMIC)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(WRAP_LDFLAGS) $(SFS_LDADD) $(FLUME_SRV_LDADD) 

$(SYSCALLBENCH_LINUX): $(SYSCALLBENCH_LINUX_OBJS) $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ -L/usr/lib -lc $(SYSCALLBENCH_LINUX_OBJS) 

$(IPCBENCH_FLUME): $(IPCBENCH_FLUME_OBJS) $(FLUME_SRV_LAS) $(LIBFLUMECLNTC_LA) \
		$(LIBFLUMECLNTCXX_LA) $(LIBC_LIBS_DYNAMIC)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(WRAP_LDFLAGS) $(SFS_LDADD) $(FLUME_SRV_LDADD) 

$(IPCBENCH_LINUX): $(IPCBENCH_LINUX_OBJS) $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ -L/usr/lib -lc $(IPCBENCH_LINUX_OBJS) 

$(NULLCGI): $(NULLCGI_OBJS) $(LIBCLNT_LA) $(LIBFLUMECLNTC_LA) $(FLUME_SRV_LAS) $(LIBC_LIBS_DYNAMIC)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -o $@ $^ $(WRAP_LDFLAGS) $(SFS_LDADD) $(FLUME_SRV_LDADD)

$(NULLCGI_STATIC): $(NULLCGI_OBJS) $(LIBCLNT_LA) $(LIBFLUMECLNTC_LA) $(LIBC_LIBS_STATIC) $(FLUME_SRV_LAS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) -all-static -o $@ $^ $(WRAP_LDFLAGS) $(SFS_LDADD) $(FLUME_SRV_LDADD) 

##
##-----------------------------------------------------------------------

install-clnt-microbench: \
	install-clnt-microbench-syscall-bench-linux \
	install-clnt-microbench-syscall-bench-flume \
	install-clnt-microbench-ipc-bench-linux \
	install-clnt-microbench-ipc-bench-flume \
	install-clnt-microbench-nullcgi-static \
	install-clnt-microbench-nullcgi

install-clnt-microbench-%: $(OBJDIR_MICROBENCH)/%
	@echo "+ inst:" `basename $<` "-> $(FLUMEBIN)"
	@mkdir -p $(FLUMEBIN)
	$(V)$(LT_INSTALL) $(BINMODE) $< $(FLUMEBIN)

all: $(SYSCALLBENCH_FLUME) $(SYSCALLBENCH_LINUX) $(IPCBENCH_FLUME) $(IPCBENCH_LINUX) $(NULLCGI) $(NULLCGI_STATIC)
