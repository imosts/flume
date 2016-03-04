
DIR := libflume-ev

OBJDIR_LIBFLUME_EV := $(OBJDIR)/$(DIR)
SRCDIR_LIBFLUME_EV := $(DIR)

OBJDIRS += $(OBJDIR_LIBFLUME_EV)

PROTS = web txa okcompat flume flume_idd flume_fs flume_spawn tst

LIBFLUME_EV_OFILES_PROT = $(foreach p, $(PROTS), $(p)_prot.lo)

LIBFLUME_EV_OFILES := $(LIBFLUME_EV_OFILES_PROT) labels.lo bf60.lo debug.lo
LIBFLUME_EV_OBJS := $(foreach ofile, $(LIBFLUME_EV_OFILES), \
			$(OBJDIR_LIBFLUME_EV)/$(ofile) )

LIBFLUME_EV_LA := $(OBJDIR_LIBFLUME_EV)/libflume-ev.la

FLUME_SRV_LAS := $(LIBFLUME_EV_LA) $(FLUME_SRV_LAS)

LIBFLUME_EV_HFILES_PROT = $(foreach p, $(PROTS), $(OBJDIR_PROT_EV)/$(p)_prot.h)

##-----------------------------------------------------------------------
## 
## Make all protocol files
## 

$(OBJDIR_PROT_EV)/%.C: $(SRCDIR_PROT)/%.x $(OBJDIR_PROT_EV)/%.h
	@echo "+ rpcc: $@"
	@mkdir -p $(@D)
	$(V)$(RPCC) -o $@ -c $< || (rm -f $@ && false)

$(OBJDIR_PROT_EV)/%.h: $(SRCDIR_PROT)/%.x
	@echo "+ rpcc: $@"
	@mkdir -p $(@D)
	$(V)$(RPCC) -o $@ -h $< || (rm -f $@ && false)

##
## end of protocol files section
##
##-----------------------------------------------------------------------


##-----------------------------------------------------------------------
## 
## Compile down all source files
## 

$(OBJDIR_LIBFLUME_EV)/%.lo: $(OBJDIR_PROT_EV)/%.C $(OBJDIR_PROT_EV)/%.h
	@echo "+  g++: $@"
	@mkdir -p $(@D)
	$(V)$(LT_CXX) $(EV_CFLAGS) $(EV_INCLUDE) $(shell $(DODEPS) -t $@) -c -o $@ $< && $(shell $(DODEPS) -m $@)
 

$(OBJDIR_LIBFLUME_EV)/%.lo: $(SRCDIR_LIBFLUME_EV)/%.C
	@echo "+  g++: $@"
	@mkdir -p $(@D)
	$(V)$(LT_CXX) $(EV_CFLAGS) $(EV_INCLUDE) $(shell $(DODEPS) -t $@) -c -o $@ $< && $(shell $(DODEPS) -m $@)

##
## End compile of source files
##
##-----------------------------------------------------------------------

##-----------------------------------------------------------------------
##
## Combine the files into a .so
##

$(LIBFLUME_EV_LA): $(LIBFLUME_EV_OBJS)
	@echo "+   ld: $@"
	$(V)$(LT_LD) $(FLUME_RPATH) -shared -o $@ $^ $(SFS_LDADD)

##
## End of .so generation
##
##-----------------------------------------------------------------------

all: $(LIBFLUME_EV_LA)

#
# Tell gmake not to throw away these files
#
.PRECIOUS: $(OBJDIR_PROT_EV)/%.C $(OBJDIR_PROT_EV)/%.h 

install-libflume-ev: \
	install-libflume-ev-lib \
	install-libflume-ev-include 

install-libflume-ev-lib: $(LIBFLUME_EV_LA)
	@echo "+ inst:" `basename $<` "-> $(FLUMELIB)"
	@mkdir -p $(FLUMELIB)
	$(V)$(LT_INSTALL) $(LIBMODE) $< $(FLUMELIB)

install-libflume-ev-include: $(LIBFLUME_EV_HFILES_PROT)
	@mkdir -p $(FLUMEINCEV)
	$(V)for h in $^; do \
		echo "+ inst:" `basename $$h` "(ev) -> $(FLUMEINCEV)" ; \
		$(INSTALL) $(LIBMODE) $$h $(FLUMEINCEV) ; \
	done

