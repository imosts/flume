
DIR := lsm

LSM_DIR := $(DIR)
OBJDIR_LSM := $(OBJDIR)/lsm

LSM     := flume
LSM_KO  := $(OBJDIR_LSM)/$(LSM).ko

OBJDIRS += $(OBJDIR_LSM)

# Just use the toplevel include for this, but supply an absolute path,
# since we're going to be changing into the object directory when building
# the kernel module.
LSM_KO_INCLUDE := $(shell pwd)/include

##-----------------------------------------------------------------------
##
## Build all objects and the associate loadable kernel module
##

LSM_KO_CFILES      := hooks.c
LSM_KO_OFILES      := $(patsubst %.c, %.o, $(LSM_KO_CFILES))
LSM_KO_CFILES_COPY := $(foreach cfile, $(LSM_KO_CFILES), \
			$(OBJDIR_LSM)/$(cfile) )

LSM_KO_MAKEFILE_IN := $(LSM_DIR)/Makefile.in
LSM_KO_MAKEFILE := $(OBJDIR_LSM)/Makefile

$(OBJDIR_LSM)/%.c: $(LSM_DIR)/%.c
	@mkdir -p $(@D)
	$(V)cp $< $@ 

$(LSM_KO_MAKEFILE): $(LSM_KO_MAKEFILE_IN) $(LSM_DIR)/frag.mk
	@echo "+  gen: $@"
	@mkdir -p $(@D)
	$(V)cat $< | sed -e s,%%KONAME%%,$(LSM), \
		-e s,%%KO_OFILES%%,"$(LSM_KO_OFILES)", \
		-e s,%%KO_INCLUDE%%,"$(LSM_KO_INCLUDE)", > $@

$(LSM_KO): $(LSM_KO_CFILES_COPY) $(LSM_KO_MAKEFILE)
	@echo "+ make: $@"
	@mkdir -p $(@D)
	$(V)(cd $(OBJDIR_LSM) && $(MAKE) ) $(V_REDIRECT)

##
## End all objects and kernel module
## 
##-----------------------------------------------------------------------

install-lsm: $(LSM_KO)
	@mkdir -p $(FLUMEKODIR)
	@echo "+ inst: $< -> $(FLUMEKODIR)"
	$(V)$(INSTALL) $(LIBMODE) $< $(FLUMEKODIR)

root-lsm-rmmod:
	$(V)for m in capability apparmor commoncap flume; do \
		echo "+ rmmd: $$m" ; \
		(lsmod | grep $$m > /dev/null) && rmmod $$m  ;  \
	done || true

root-lsm-insmod: root-lsm-rmmod
	@echo "+ insm: $(FLUMEKODIR)/flume.ko" 
	$(V)insmod $(FLUMEKODIR)/flume.ko 

all: $(LSM_KO)
