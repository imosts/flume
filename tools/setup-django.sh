#!/bin/bash

source ~/flume.env
`flume-cfg bin`/flume-python /disk/$USER/flume/run/testbin/dbvtst.py
`flume-cfg bin`/flume-python /disk/$USER/flume/run/pybin/wcsetup.py install_users
$FLUME_SRC/../httpd/runapache.sh start