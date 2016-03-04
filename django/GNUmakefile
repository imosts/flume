
MYCFG = ../linux/bin/flume-cfg
PREFIX ?= $(shell $(MYCFG) runprefix)
PYBIN ?= $(shell $(MYCFG) pybin)
PYLIB ?= $(shell $(MYCFG) pylib)
PYVERS ?= $(shell $(MYCFG) pyvers)

TMPINSTALL = ./build/install

PYSRC = $(shell python setup.py list_src_files)
PYOBJS = $(foreach f,$(PYSRC),$(f) $(f)c)
PYZIP = $(TMPINSTALL)/django.zip
FILELIST = $(TMPINSTALL)/filelist

all:
	python setup.py build

$(PYZIP): $(PYSRC)
	mkdir -p $(TMPINSTALL)
	python setup.py install --prefix=$(TMPINSTALL)
	cd $(TMPINSTALL)/lib/python$(PYVERS)/site-packages; zip ../../../$(@F) $(PYOBJS)

$(FILELIST): $(PYSRC)
	mkdir -p $(TMPINSTALL)
	python setup.py install --prefix=$(TMPINSTALL)
	cd $(TMPINSTALL)/lib/python$(PYVERS)/site-packages; find . -name "*.py" -o -name "*.pyc" -o -name "*.so" | cut -b 3- > ../../../$(@F)

install: $(FILELIST) $(PYZIP)

clean:
	rm -rf $(TMPINSTALL)/*
