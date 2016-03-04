

##-----------------------------------------------------------------------
##
## default rules that are used over and over

$(objdir)/%.C: $(srcdir)/%.T
	@mkdir -p $(@D)
	@echo "+ tame: $<"
	$(V)$(TAME) -o $@ $< || (rm -f $@ && false)

$(objdir)/%.lo: $(objdir)/%.C
	@mkdir -p $(@D)
	@echo "+  g++: $<"
	$(V)$(LT_CXX) $(EV_CFLAGS) $(SRV_INCLUDE) -I$(@D) $(shell $(DODEPS) -t $@ ) -c -o $@ $< && $(shell $(DODEPS) -m $@) 

$(objdir)/%.lo: $(srcdir)/%.C
	@mkdir -p $(@D)
	@echo "+  g++: $<"
	$(V)$(LT_CXX) $(EV_CFLAGS) $(SRV_INCLUDE) -I$(@D) $(shell $(DODEPS) -t $@) -c -o $@ $< && $(shell $(DODEPS) -m $@)

.PRECIOUS: $(objdir)/%.C $(objdir)/%.h

##
##-----------------------------------------------------------------------
