%.o: %.c
	gcc -g -O2 -I.. -c $< -o $@

all: ascli forkbomb syscallbomb

LIBRESOLV := $(shell if test `uname -s` = "Linux"; \
	then echo '-lresolv' ; \
	else echo ''; \
	fi )

SFSINC := -I/usr/local/include/sfs \
	  -I/usr/include/sfs \
	  -I/usr/local/include/sfslite \
	  -I/usr/local/include/sfslite-1.1/shdbg

SFSLIB := -L/usr/local/lib/sfs \
	  -L/usr/lib/sfs \
	  -L/usr/local/lib/sfslite \
	  -L/usr/local/lib/sfslite-1.1/shdbg

%.o: %.C
	g++ -g -O2 $(SFSINC) -c $< -o $@

w5cli.o: w5cli.C w5cli.h basecli.h
moincli.o: moincli.C moincli.h tmoincli.h basecli.h
tmoincli.o: tmoincli.C tmoincli.h basecli.h
trazcart.o: trazcart.C trazcart.h basecli.h
ascli.o: ascli.C trazcart.h moincli.h tmoincli.h basecli.h w5cli.h
ascli: ascli.o normdist.o trazcart.o moincli.o tmoincli.o w5cli.o
	g++ -g -O2 -o $@ \
	ascli.o normdist.o trazcart.o moincli.o tmoincli.o w5cli.o \
	$(SFSLIB) -lasync $(LIBRESOLV)

forkbomb: forkbomb.c
	gcc forkbomb.c -o forkbomb

syscallbomb: syscallbomb.c
	gcc syscallbomb.c -o syscallbomb

clean:
	rm -f ascli *.o *.core

.PHONY: clean all default



install:
	install userland-install.sh /home/am0/httpd/htdocs/pub/traz
