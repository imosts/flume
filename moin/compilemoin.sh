#!/bin/sh

if [ ! $1 ]; then
  echo "usage: compilemoin.sh instance_directory"
  exit 1
fi

D=`pwd`
cd $1/cgi-bin
python compilemoin.py
cd $D

