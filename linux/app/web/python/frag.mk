
SRCDIR_APP_WEB_PYTHON = app/web/python
SRCDIR_APP_WEB_PYTHON_WIKICODE_TRUSTED = $(SRCDIR_APP_WEB_PYTHON)/wikicode/trusted

##-----------------------------------------------------------------------

build-app-web-python-lib:
	@echo "+ make: $(SRCDIR_APP_WEB_PYTHON)"
	$(V)(cd $(SRCDIR_APP_WEB_PYTHON) \
		&& $(PYTHON) setup.py $(V_PYTHON) build )

##-----------------------------------------------------------------------

APP_WEB_PYTHON_BINS = \
	initumgr.py \
	makefilter.py \
	umgr.py \
	wclaunch.py \
	wclaunch-fast.fcgi \
	wcsetup.py \
	wctags.py \
	flumekvs.py \
	debuginfo.py \
	w5proxy.py \
	w5-prepare-bench.py \
	wcfreeze.py

install-app-web-python-%: $(SRCDIR_APP_WEB_PYTHON)/bin/%
	@mkdir -p $(FLUMEPYBIN)
	@echo "+ inst: $< -> $(FLUMEPYBIN)"
	$(V)$(INSTALL) $(BINMODE) $< $(FLUMEPYBIN)

install-app-web-python-bin: \
	$(foreach p, $(APP_WEB_PYTHON_BINS), install-app-web-python-$(p))

##-----------------------------------------------------------------------

APP_WEB_PYTHON_WIKICODE_TRUSTED = \
	acleditor \
	wceditfile \
	wcfancyhello \
	wchello \
	wcmain

install-app-web-python-wikicode-trusted-%: $(SRCDIR_APP_WEB_PYTHON_WIKICODE_TRUSTED)/%.py
	@mkdir -p $(FLUMEPYBIN)
	@mkdir -p $(FLUMEPYBIN)/wctrusted
	@echo "+ inst: $< -> $(FLUMEPYBIN)/wctrusted"
	$(V)$(INSTALL) $(BINMODE) $< $(FLUMEPYBIN)/wctrusted

install-app-web-python-wikicode-trusted: \
	$(foreach p, $(APP_WEB_PYTHON_WIKICODE_TRUSTED), install-app-web-python-wikicode-trusted-$(p))

##-----------------------------------------------------------------------

install-app-web-python-lib:
	@echo "+ inst: {app/web/python libs} -> $(PYLIBDIR)"
	@mkdir -p $(PYLIBDIR)
	$(V)(cd $(SRCDIR_APP_WEB_PYTHON) && \
		$(PYTHON) setup.py $(V_PYTHON) install --prefix=$(PYPREFIX) )

##-----------------------------------------------------------------------

install-app-web-python: \
	install-app-web-python-lib \
	install-app-web-python-bin \
	install-app-web-python-wikicode-trusted

##-----------------------------------------------------------------------
## --  FLUME DB and W5 tag setup --
##-----------------------------------------------------------------------

FLUMEENV=$(FLUMECONFDIR)flume.env
MASTERI_TAG_FILE=$(FLUMECONFDIR)m_itag
CLEAN_DB='echo "DROP DATABASE $(USER)" | sudo -u $(USER) psql -h $(FLUMEPGHOST) postgres'
MAKE_DB='echo "CREATE DATABASE $(USER) OWNER=$(USER)" | sudo -u $(USER) psql -h $(FLUMEPGHOST) postgres'
SETUP_CMD='source $(FLUMEENV); $(FLUMEBIN)/flume-python -u $(FLUMEPYBIN)/wcsetup.py'
SETUP_EXP_CMD='source $(FLUMEENV); $(FLUMEBIN)/flume-python -u $(FLUMEPYBIN)/wcsetup.py experiment'

APACHE_CONFIG=../httpd/conf/httpd.conf.base
APACHE_PID_FILE=/tmp/httpd-$(USER)/httpd.pid
PROXY_PID_FILE=/tmp/httpd-$(USER)/proxy.pid
DBV_PID_FILE=/tmp/dbv-$(USER)/dbv.pid
DB_STAMP=$(FLUMECONFDIR)db_stamp
PROXY_LOG=/tmp/httpd-$(USER)/proxy.log

PROXY_PORT   ?= $(shell $(MYCFG) proxyport)
APACHE_PORT  ?= $(shell $(MYCFG) apacheport)
W5DOMAIN     ?= $(shell $(MYCFG) w5domain)

DBV_SOCKET_PREFIX = /disk/$(USER)/sockets
DBV_SOCKET_DIRS = \
	$(DBV_SOCKET_PREFIX)/postgresql0 \
	$(DBV_SOCKET_PREFIX)/postgresql1 \
	$(DBV_SOCKET_PREFIX)/postgresql2 \
	$(DBV_SOCKET_PREFIX)/postgresql3

$(FLUMEENV): $(SRCDIR_APP_WEB_PYTHON)/bin/wctags.py
#	make install-app-web-python-wctags 
	$(FLUMEBIN)/flume-python $(FLUMEPYBIN)/wctags.py > $@

$(DBV_SOCKET_PREFIX)/postgresql% : 
	sudo mkdir $@

$(MASTERI_TAG_FILE): $(FLUMEENV) 
	bash -c $(CLEAN_DB)
	bash -c $(MAKE_DB)
	sudo rm -f `find /disk/$(USER)/sockets -name .s.PGSQL.5432`
	sudo bash -c 'source $(FLUMEENV); $(FLUMEBIN)/$(TAG)/initfile -c -G -I $(FLUMEIDDHOST):$(FLUMEIDDPORT) `find /disk/$(USER)/sockets`'
	bash -c 'source $(FLUMEENV); $(FLUMEBIN)/flume-python -c "import flume.flmos as flmo; print flmo.Label ([flmo.Handle ($$MASTERI_CAP).toTag()]).freeze ()" > $(MASTERI_TAG_FILE)'
	sudo bash -c 'source $(FLUMEENV); $(FLUMEBIN)/$(TAG)/initfile -i `cat $(MASTERI_TAG_FILE)` -G -I $(FLUMEIDDHOST):$(FLUMEIDDPORT) /disk/$(USER)/sockets/postgresql*'

clean-db:
	bash -c $(CLEAN_DB)
	bash -c $(MAKE_DB)

run-db: $(MASTERI_TAG_FILE) $(FLUMEENV) $(DBV_SOCKET_DIRS)
	touch $(DB_STAMP)
	mkdir -p /tmp/dbv-$(USER)
	bash -c $(MAKE_DB)
	bash -c 'source $(FLUMEENV); $(FLUMEBIN)/flume-python -u $(FLUMEPYBIN)/dbv.py $(FLUMEPGHOST) 5432 -pid $(DBV_PID_FILE)'

$(APACHE_PID_FILE): $(MASTERI_TAG_FILE) $(APACHE_CONFIG) $(FLUMEENV)
	bash -c 'source $(FLUMEENV); ../httpd/runapache.sh restart'

restart-apache:
	bash -c 'source $(FLUMEENV); ../httpd/runapache.sh restart'

run-apache: $(APACHE_PID_FILE)

$(PROXY_PID_FILE): $(SRCDIR_APP_WEB_PYTHON)/bin/w5proxy.py
#	make install-bin-w5proxy.py
	python -u $(FLUMEPYBIN)w5proxy.py -p $(PROXY_PORT) -pid $(PROXY_PID_FILE) -f $(W5DOMAIN):$(APACHE_PORT) > $(PROXY_LOG) &

start-proxy: $(PROXY_PID_FILE)

stop-proxy:
	if [ -e $(PROXY_PID_FILE) ]; then kill `cat $(PROXY_PID_FILE)`;	rm -f $(PROXY_PID_FILE); fi

restart-proxy:
	make stop-proxy
	make start-proxy

wcsetup:
	@if [ $(SRCDIR_APP_WEB_PYTHON)/bin/wctags.py -nt $(DB_STAMP) ]; then echo "*** wctags.py is newer than the DB process, you should rerun 'make run-db'."; exit 1; fi
	cd ../django; make install
	cd ../Imaging-1.1.6; make install
	bash -c $(SETUP_CMD)

wcsetup-experiment:
	@if [ $(SRCDIR_APP_WEB_PYTHON)/bin/wctags.py -nt $(DB_STAMP) ]; then echo "*** wctags.py is newer than the DB process, you should rerun 'make run-db'."; exit 1; fi
	cd ../django; make install
	cd ../Imaging-1.1.6; make install
	bash -c $(SETUP_EXP_CMD)

wcsetup-clean:
	bash -c 'source $(FLUMEENV); $(FLUMEBIN)/flume-python -u $(FLUMEPYBIN)/wcsetup.py clean_users'

prepare-w5: restart-proxy run-apache wcsetup

prepare-experiment: restart-proxy run-apache wcsetup-experiment



FREEZE_DIR=$(OBJDIR)/freeze
FREEZE_APPS = \
	photoapp \
	blog \
	nullcgi

freeze-photoapp:
	mkdir -p $(FREEZE_DIR)/photoapp
	cd $(FREEZE_DIR)/photoapp; bash -c "source $(FLUMEENV); $(FLUMEBIN)/flume-python -u $(FLUMEPYBIN)/wcsetup.py -appdata photoapp" | python $(FLUMEPYBIN)/wcfreeze.py -

freeze-blog: 
	mkdir -p $(FREEZE_DIR)/blog
	cd $(FREEZE_DIR)/blog; bash -c "source $(FLUMEENV); $(FLUMEBIN)/flume-python -u $(FLUMEPYBIN)/wcsetup.py -appdata blog" | python $(FLUMEPYBIN)/wcfreeze.py -

freeze-nullcgipy: 
	mkdir -p $(FREEZE_DIR)/nullcgipy
	cd $(FREEZE_DIR)/nullcgipy; bash -c "source $(FLUMEENV); $(FLUMEBIN)/flume-python -u $(FLUMEPYBIN)/wcsetup.py -appdata nullcgipy" | python $(FLUMEPYBIN)/wcfreeze.py -nj -

freeze: $(foreach a, $(FREEZE_APPS), freeze-$(a))

freeze-clean:
	rm -rf $(FREEZE_DIR)

all: build-app-web-python-lib
