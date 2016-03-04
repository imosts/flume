#!/bin/bash

#PYTHON_SUFFIX=lib/python2.4/site-packages
#PREFIX=/usr/local

#TRAZ_CTL_SOCKET= \
#TRAZ_DESIRED_RING=1 \
#PYTHONPATH=${PREFIX}/${PYTHON_SUFFIX} \

LIMIT=1000

for ((a=1; a <= LIMIT ; a++))
do
#  LD_LIBRARY_PATH=/usr/local/lib:${PREFIX}/lib/traz/shared/runtime \
#	python /bin/null.py
`traz-cfg bin`/traz-python `traz-cfg pybin`/null.py
#python `traz-cfg pybin`/null.py
done         

