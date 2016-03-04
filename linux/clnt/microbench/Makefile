

TRAZINCLUDE=-I/disk/$(USER)/run/include/traz-0.0/$(TRAZ_TAG)/runtime -I/disk/$(USER)/run/include -I/usr/local/include/sfslite/shopt -I/usr/local/include
TRAZLIB=-L/disk/$(USER)/run/lib/traz/$(TRAZ_TAG)/runtime -ltrazclnt_c -ltrazc

CC = gcc
CXX = g++

all: largefb smallfb bw syscall-bench ipc-bench

largefb: large.c
	$(CC) -g -o largefb large.c

smallfb: small.c testlib.o testlib.h
	$(CC) -g -o smallfb small.c testlib.o

syscall-bench: syscall-bench.c testlib.o testlib.h
	$(CC) -g -o syscall-bench syscall-bench.c testlib.o $(TRAZINCLUDE) $(TRAZLIB)

ipc-bench: ipc-bench.c testlib.o testlib.h
	$(CC) -g -o ipc-bench ipc-bench.c testlib.o $(TRAZINCLUDE) $(TRAZLIB)

bw: bw.C
	$(CXX) -g -o bw bw.C

clean: 
	rm -f bw largefb smallfb syscall-bench *.o

install:
	cp ipc-bench /disk/$(USER)/run/bin/
