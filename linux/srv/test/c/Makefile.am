

AM_CPPFLAGS = -I$(top_builddir)/libtrazclnt -I$(top_srcdir)/libtrazclnt

noinst_PROGRAMS = forktest forktest2 testunlink exec printargv reqprivtest \
		simplecgi forkcgi sesscgi shoppingcart newgroup \
		testsetuidtag pipetest exittest testspawn nullcgi \
		opener

forktest_SOURCES = forktest.c
forktest_LDADD = $(LIBTRAZCLNT_C) $(LIBSFS) $(LIBTRAZC)

forktest2_SOURCES = forktest2.c
forktest2_LDADD = $(LIBTRAZCLNT_C) $(LIBSFS) $(LIBTRAZC)

exec_SOURCES = exec.c
opener_SOURCES = opener.c
opener_LDADD = 

printargv_SOURCES = printargv.c

testunlink_SOURCES = testunlink.c
testunlink_LDADD = $(LIBTRAZCLNT_C) $(LIBTRAZC) $(LIBSFS) $(LDADD)

testsetuidtag_SOURCES = testsetuidtag.c
testsetuidtag_LDADD = $(LIBTRAZCLNT_C) $(LIBTRAZC) $(LIBSFS) $(LDADD) 


pipetest_SOURCES = pipetest.c
pipetest_LDADD = $(LIBTRAZCLNT_C) $(LIBTRAZC) $(LIBSFS) $(LDADD) 

testspawn_SOURCES = testspawn.c
testspawn_LDADD = $(LIBTRAZCLNT_C) $(LIBTRAZC) $(LIBSFS) $(LDADD) 

exittest_SOURCES = exittest.c
exittest_LDADD = $(LIBTRAZCLNT_C) $(LIBTRAZC) $(LIBSFS) $(LDADD) 

reqprivtest_SOURCES = reqprivtest.c
reqprivtest_LDADD = $(LIBTRAZCLNT_C) $(LIBTRAZC) $(LIBSFS) $(LIBTRAZC)

simplecgi_SOURCES = simplecgi.c
simplecgi_LDADD = $(LIBTRAZCLNT_C) $(LIBTRAZC) $(LIBSFS) $(LIBTRAZC)

forkcgi_SOURCES = forkcgi.c
forkcgi_LDADD = $(LIBTRAZCLNT_C) $(LIBSFS) $(LIBTRAZC)

sesscgi_SOURCES = sesscgi.c
sesscgi_LDADD = $(LIBSESSCLNT_C) $(LIBTRAZCLNT_C) $(LIBSFS) $(LIBTRAZC)

shoppingcart_SOURCES = shoppingcart.c
shoppingcart_LDADD = $(LIBSESSCLNT_C) $(LIBTRAZCLNT_C) $(LIBSFS) $(LIBTRAZC)

newgroup_SOURCES = newgroup.c
newgroup_LDADD = $(LIBTRAZCLNT_C) $(LIBSFS) $(LIBTRAZC)

nullcgi_SOURCES = nullcgi.c
nullcgi_LDADD = $(LIBTRAZCLNT_C) $(LIBSFS) $(LIBTRAZC)
