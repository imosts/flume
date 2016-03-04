#!/bin/bash

#AACHE=apache
#CONFIG_BASE=httpd.conf.base

APACHE=apache2
CONFIG_BASE=httpd2.conf.base

PORT=`flume-cfg apacheport`
SSLPORT=`flume-cfg apachesslport`
HTTPDIR=`flume-cfg httpdir`
FLUMEBIN=`flume-cfg bin`
USER=`flume-cfg user`
PYPATH=`flume-cfg pypath`
PYVERS=`flume-cfg pyvers`
RLIB=`flume-cfg rlib`
TLIB=`flume-cfg lib`
SOCKET=`flume-cfg socket`
PYBIN=`flume-cfg pybin`
TESTBIN=`flume-cfg testbin`
FQDN=`flume-cfg w5domain`

TMPDIR=/tmp/httpd-$USER
PID=$TMPDIR/httpd.pid

KEYFILE=$TMPDIR/conf/server.key
CRTFILE=$TMPDIR/conf/server.crt
CONFFILE=$TMPDIR/conf/httpd.conf

usage () {
  echo "usage: ./runapache.sh { start | stop | restart }"
  exit 
}

link () {
    ln -s $1/$2 $CGIBIN/$2
    if ! (test -e $1/$2); then
        echo "WARNING $1/$2 does not exist"
    fi
}

start () {
  CGIBIN=$TMPDIR/cgi-bin
  if (test -e $TMPDIR); then
    if (test -e $PID); then
      kill `cat $PID`
    fi
    rm -rf $TMPDIR/cgi-bin
    rm -rf $TMPDIR/logs
    rm -rf $TMPDIR/htdocs
    rm -rf $CONFFILE
    rm -rf $PID
  fi

  mkdir -p $TMPDIR
  mkdir -p $TMPDIR/logs
  mkdir -p $TMPDIR/htdocs
  mkdir -p $TMPDIR/conf
  echo "Hello, welcome to Flume'd Apache go to <a href='/trusted/'>WikiCode</a>" > $TMPDIR/htdocs/index.html
  cp $HTTPDIR/conf/mime.types $TMPDIR/conf/
  cp -r $HTTPDIR/cgi-bin $TMPDIR/

  # Generate apache configuation file
  cat $HTTPDIR/conf/$CONFIG_BASE    \
      | sed "s|FQDN|$FQDN|"         \
      | sed "s|SERVPORT|$PORT|"     \
      | sed "s|SSLPORT|$SSLPORT|"   \
      | sed "s|USERVAL|$USER|"      \
      | sed "s|PYPATH|$PYPATH|"     \
      | sed "s|PYBIN|$PYBIN|"       \
      | sed "s|TESTBIN|$TESTBIN|"   \
      | sed "s|PYV|$PYVERS|"        \
      | sed "s|FLUMEBIN|$FLUMEBIN|" \
      | sed "s|TZSOCK|$SOCKET|"     \
      | sed "s|RLIB|$RLIB|"         \
      | sed "s|TLIB|$TLIB|"         > $CONFFILE

  if [ ! -e $CRTFILE ]; then
      openssl req -new -x509 -days 365 -sha1 -newkey rsa:1024 -nodes -keyout $KEYFILE -out $CRTFILE -subj '/CN=foobar.com'
  fi

  # Start apache
  $APACHE -f $TMPDIR/conf/httpd.conf
}

stop () {
  if (test -e $PID); then
    kill `cat $PID`
    rm -f $PID
  fi
}

if [ $# -ne 1 ]; then
    usage
elif [ $1 == "start" ]; then 
    start 
elif [ $1 == "stop" ]; then
    stop
elif [ $1 == "restart" ]; then
    stop
    sleep 3
    start
else
    usage
fi


