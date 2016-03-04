
SRCDIR_TEST_PYTHON = test/python

TEST_PYTHON_BINS = \
	dbvtst.py \
	psycopgtst.py \
	pgdbtst.py \
	errno.py \
	file.py \
	freeze.py \
	groups.py \
	idir.py \
	ihome.py \
	kvstst.py \
	labelsets.py \
	makelogin.py \
	mksetuidwrap.py \
	printo.py \
	setuidsh.py \
	sockettst.py \
	sockettst2.py \
	spawn_confined.py \
	spawner.py \
	spawner2.py \
	spawner3.py \
	spawner4.py \
	spawnee.py \
	spawnee2.py \
	spawnee3.py \
	spawnee4.py \
	stat.py \
	statfile.py \
	toktst.py \
	tst1.py \
	tstfilter.py \
	umgrtst.py \
	writefile.py \
	addfromgroup.py \
	getepinfo.py \
	closedfiles_parent.py \
	closedfiles_child.py \
	tstepfile.py \
	open.py \
	xmlrpctst.py \
	labelchangeset.py \
	capxfer.py \
	capxferee.py \
	djangotst.py \
	fork.py \
	getpid.py \
	raw.py \
	forksrvtstee.py \
	forksrvtster.py \
	fastcgi-hello.fcgi \
	dbvloadtest.py \
	spawnnull.py \
	null.py \
	filehelpertst.py  \
	simple_ep.py

install-test-python: \
	$(foreach p, $(TEST_PYTHON_BINS), install-test-python-$(p))

install-test-python-%: $(SRCDIR_TEST_PYTHON)/%
	@mkdir -p $(FLUMETSTBIN)
	@echo "+ inst: $< -> $(FLUMETSTBIN)"
	$(V)$(INSTALL) $(BINMODE) $< $(FLUMETSTBIN)
