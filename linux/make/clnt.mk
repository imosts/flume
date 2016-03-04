

#$(objdir)/%.o: $(objdir)/%.c
#	@echo "+  gcc: $@"
#	@mkdir -p $(@D)
#	$(V)$(LT_CC) $(WRAP_CFLAGS) $(INCLUDE) -c -o $@ $<

$(objdir)/%.lo: $(objdir)/%.c
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(LT_CC) $(WRAP_CFLAGS) $(CLNT_INCLUDE) -I$(@D) $(shell $(DODEPS) -t $@ ) -c -o $@ $< && $(shell $(DODEPS) -m $@)

$(objdir)/%.lo: $(srcdir)/%.c
	@echo "+  gcc: $@"
	@mkdir -p $(@D)
	$(V)$(LT_CC) $(WRAP_CFLAGS) $(CLNT_INCLUDE) -I$(@D) $(shell $(DODEPS) -t $@ ) -c -o $@ $< && $(shell $(DODEPS) -m $@)

$(objdir)/%.lo: $(objdir)/%.C
	@mkdir -p $(@D)
	@echo "+  g++: $<"
	$(V)$(LT_CXX) $(WRAP_CFLAGS) $(CLNT_INCLUDE) -I$(@D) $(shell $(DODEPS) -t $@ ) -c -o $@ $< && $(shell $(DODEPS) -m $@) 

$(objdir)/%.lo: $(srcdir)/%.C
	@mkdir -p $(@D)
	@echo "+  g++: $<"
	$(V)$(LT_CXX) $(WRAP_CFLAGS) $(CLNT_INCLUDE) -I$(@D) $(shell $(DODEPS) -t $@) -c -o $@ $< && $(shell $(DODEPS) -m $@)

$(objdir)/%.C: $(srcdir)/%.T
	@mkdir -p $(@D)
	@echo "+ tame: $<"
	$(V)$(TAME) -o $@ $< || (rm -f $@ && false)

.PRECIOUS: $(objdir)/%.C $(objdir)/%.h
