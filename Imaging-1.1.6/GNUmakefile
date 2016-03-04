
MYCFG = ../linux/bin/flume-cfg
PREFIX ?= $(shell $(MYCFG) runprefix)
PYBIN ?= $(shell $(MYCFG) pybin)
PYLIB ?= $(shell $(MYCFG) pylib)
PYVERS ?= $(shell $(MYCFG) pyvers)

BUILD = ./build
TMPINSTALL = $(BUILD)/install

PYSRC = $(shell python setup.py list_src_files)
FILELIST = $(TMPINSTALL)/filelist

all:
	python setup.py build

$(FILELIST): $(PYSRC)
	mkdir -p $(TMPINSTALL)
	python setup.py install --prefix=$(TMPINSTALL)
	cd $(TMPINSTALL)/lib/python$(PYVERS)/site-packages/PIL; find . -name "*.py" -o -name "*.pyc" -o -name "*.so" | cut -b 3- > ../../../../$(@F)

install: $(FILELIST)

clean:
	rm -rf $(BUILD)/*
