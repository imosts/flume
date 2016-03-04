#!/bin/sh

USER=`flume-cfg user`

# start with idd not running
cd /var/tmp ; nohup `flume-cfg srvbin`/idd -f `flume-cfg confdir`/idd.conf.dist &
sudo `flume-cfg srvbin`/flumerm -f  `flume-cfg confdir`/flume.conf.$USER
