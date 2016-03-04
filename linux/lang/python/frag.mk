
SRCDIR_LANG_PY = lang/python
OBJDIR_LANG_PY = $(OBJDIR)/$(SRCDIR_LANG_PY)

PY_WRAP_STEM = flume_internal
PY_WRAP_CXX = $(OBJDIR_LANG_PY)/_$(PY_WRAP_STEM).cxx
PY_WRAP_SO = $(OBJDIR_LANG_PY)/_$(PY_WRAP_STEM).so
PY_WRAP_OBJS = $(OBJDIR_LANG_PY)/_$(PY_WRAP_STEM).o $(WRAP_COMMON_OBJS)
PY_WRAP_PY = $(OBJDIR_LANG_PY)/$(PY_WRAP_STEM).py

OBJDIRS += $(OBJDIR_LANG_PY)


##-----------------------------------------------------------------------

# Generate CXX files from swig, etc

$(PY_WRAP_CXX): $(WRAP_SWIG_INPUT)
	@mkdir -p $(@D)
	@echo "+ swig: $@"
	$(V)$(SWIG) -python -o $@ $<

$(OBJDIR_LANG_PY)/%.o: $(OBJDIR_LANG_PY)/%.cxx
	@mkdir -p $(@D)
	@echo "+  g++: $<"
	$(V)$(CXX) $(WRAP_CFLAGS) $(WRAP_INCLUDE) $(SYSPYINCLUDE) -c -o $@ $<

##-----------------------------------------------------------------------

$(PY_WRAP_SO): $(PY_WRAP_OBJS)
	@echo "+   ld: $@"
	$(V)$(CXX) -shared -o $@ $^ $(WRAP_LDFLAGS)

##-----------------------------------------------------------------------

build-lang-python: 
	$(V) ( cd $(SRCDIR_LANG_PY) \
		&& $(PYTHON) setup-flume.py $(V_PYTHON) build \
		&& $(PYTHON) setup-sfs.py $(V_PYTHON) build )

##-----------------------------------------------------------------------

LANG_PYTHON_BINS = mksetuidh

install-lang-python-bin-%: $(SRCDIR_LANG_PY)/bin/%.py
	@mkdir -p $(FLUMEPYBIN)
	@echo "+ inst: $< -> $(FLUMEPYBIN)"
	$(V)$(INSTALL) $(BINMODE) $< $(FLUMEPYBIN)

install-lang-python-bin: \
	$(foreach p, $(LANG_PYTHON_BINS), install-lang-python-bin-$(p))


##-----------------------------------------------------------------------

install-lang-python: \
	install-lang-python-so \
	install-lang-python-py \
	install-lang-python-lib \
	install-lang-python-bin

install-lang-python-so: $(PY_WRAP_SO)
	@echo "+ inst:" $(notdir $< ) "-> $(PYLIBDIR)"
	@mkdir -p $(PYLIBDIR)
	$(V)$(INSTALL) $(LIBMODE) $< $(PYLIBDIR)

install-lang-python-py: $(PY_WRAP_PY)
	@echo "+ inst:" $(notdir $< ) "-> $(PYLIBDIR)"
	@mkdir -p $(PYLIBDIR)
	$(V)$(INSTALL) $(LIBMODE) $< $(PYLIBDIR)

install-lang-python-lib: build-lang-python
	@echo "+ inst: {python libs} -> $(PYLIBDIR)"
	@mkdir -p $(PYLIBDIR)
	$(V)(cd $(SRCDIR_LANG_PY) \
	  && $(PYTHON) setup-flume.py $(V_PYTHON) install --prefix=$(PYPREFIX) )

root-install-lang-python:
	@echo "+ inst: {sfs/python libs} -> {main Python dir}"
	$(V)(cd $(SRCDIR_LANG_PY) && \
	  $(PYTHON) setup-sfs.py $(V_PYTHON) install)

all: $(PY_WRAP_SO) build-lang-python
