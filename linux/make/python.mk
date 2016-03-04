
PYTHON      ?= python
PYVERS      ?= $(shell $(MYCFG) pyvers $(PYTHON) )
PYPREFIX    ?= ${PREFIX}
PYLIBDIR    ?= $(shell $(MYCFG) pylib $(PYTHON) )
PYSCRIPTDIR ?= $(shell $(MYCFG) pybin)

SYSPYPREFIX = $(shell $(PYTHON) -c 'import sys; print sys.prefix')
SYSPYINCLUDE = -I$(SYSPYPREFIX)/include/python$(PYVERS)
