#!/bin/sh

if [ "x$MOIN_I_TAG_LONG" = "x" ]; then
    echo "Warning: MOIN_I_TAG_LONG is undefined"
fi


USER=`flume-cfg user`
TAG=`flume-cfg tag`
SRC=`flume-cfg srcdir`
RLIB=`flume-cfg rlib`
RUNPREFIX=`flume-cfg runprefix`
BIN=`flume-cfg bin`

CONFIG=/tmp/flume.conf.$USER

rm -f $CONFIG

cat $SRC/conf/flume.conf.$USER \
    | sed "s|FLUME_TAG|$TAG|g" \
    | sed "s|FLUME_RLIB|$RLIB|g" \
    | sed "s|FLUME_RUNPREFIX|$RUNPREFIX|g" \
    | sed "s|FLUME_BIN|$BIN|g" \
    | sed "s|ITAG|$MOIN_I_TAG_LONG|g" \
    > $CONFIG

#FLUME_DEBUG_LEVEL=0x10000 \
#ASRV_TRACE=10 \
#ASRV_TIME=1 \
FLUME_CLOCK=/var/tmp/clock \
MALLOC_OPTIONS=">>>>>>>>>>>" \
`flume-cfg srvbin`/flumerm -f $CONFIG 
#2>&1 | tee out
