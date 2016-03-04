
SRCDIR_CLNT_DBV = clnt/dbv

##-----------------------------------------------------------------------

MARSRCS = \
	$(SRCDIR_CLNT_DBV)/DBV/dbvbindings.py \
	$(SRCDIR_CLNT_DBV)/DBV/grammar.py \
	$(SRCDIR_CLNT_DBV)/DBV/security.py \
	$(SRCDIR_CLNT_DBV)/DBV/semantics.py \
	$(SRCDIR_CLNT_DBV)/DBV/sqlparser.py

$(SRCDIR_CLNT_DBV)/DBV/sql_mar.pyc: $(MARSRCS)
	@echo "+ make: $(SRCDIR_CLNT_DBV)/DBV/sql_mar.pyc"
	$(V)(cd $(SRCDIR_CLNT_DBV)/ \
		&& PYTHONPATH=. $(PYTHON) DBV/sqlparser.py)

build-clnt-dbv-lib: $(SRCDIR_CLNT_DBV)/DBV/sql_mar.pyc
	@echo "+ make: $(SRCDIR_CLNT_DBV)"
	$(V)(cd $(SRCDIR_APP_WEB_PYTHON) \
		&& $(PYTHON) setup.py $(V_PYTHON) build )

##-----------------------------------------------------------------------

CLNT_DBV_BINS = \
	dbv

install-clnt-dbv-%: $(SRCDIR_CLNT_DBV)/bin/%.py
	@mkdir -p $(FLUMEPYBIN)
	@echo "+ inst: $< -> $(FLUMEPYBIN)"
	$(V)$(INSTALL) $(BINMODE) $< $(FLUMEPYBIN)

install-clnt-dbv-bin: \
	$(foreach p, $(CLNT_DBV_BINS), install-clnt-dbv-$(p))

##-----------------------------------------------------------------------

install-clnt-dbv-lib: $(SRCDIR_CLNT_DBV)/DBV/sql_mar.pyc
	@echo "+ inst: {clnt/dbv/DBV libs} -> $(PYLIBDIR)"
	@mkdir -p $(PYLIBDIR)
	$(V)(cd $(SRCDIR_CLNT_DBV) && \
		$(PYTHON) setup.py $(V_PYTHON) install --prefix=$(PYPREFIX) )

##-----------------------------------------------------------------------

install-clnt-dbv: \
	install-clnt-dbv-lib \
	install-clnt-dbv-bin

##-----------------------------------------------------------------------

clean-clnt-dbv:
	rm -rf $(SRCDIR_CLNT_DBV)/DBV/sql_mar.pyc

all: build-clnt-dbv-lib

run-dbv:
