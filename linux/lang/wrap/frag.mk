
SRCDIR_WRAP = lang/wrap
OBJDIR_WRAP = $(OBJDIR)/$(SRCDIR_WRAP)
WRAP_SWIG_INPUT = $(SRCDIR_WRAP)/flume.i

WRAP_COMMON_OBJS = $(OBJDIR_WRAP)/flume_i_misc.o

##-----------------------------------------------------------------------

$(OBJDIR_WRAP)/%.o: $(SRCDIR_WRAP)/%.cxx
	@mkdir -p $(@D)
	@echo "+  g++: $<"
	$(V)$(CXX) $(WRAP_CFLAGS) $(WRAP_INCLUDE) -c -o $@ $<

##-----------------------------------------------------------------------
