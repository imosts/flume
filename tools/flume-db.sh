#!/bin/bash

# Make sure you have a unique port.
PORT=38425
USER=`flume-cfg user`

`flume-cfg bin`/flume-python /disk/$USER/flume/run/pybin/wctags.py  > ~/flume.env
source ~/flume.env
sudo rm /disk/$USER/sockets/.s.PGSQL.5432
sudo `flume-cfg bin`/`flume-cfg tag`/initfile -c -G -I 127.0.0.1:$PORT `find /disk/$USER/sockets`
ILABEL=`/disk/$USER/flume/run/bin/flume-python -c "import flume.flmos as flmo; print flmo.Label ([flmo.Handle ($MASTERI_CAP).toTag()]).freeze ()"`
sudo `flume-cfg bin`/`flume-cfg tag`/initfile -i $ILABEL -G -I 127.0.0.1:$PORT /disk/$USER/sockets/postgresql
echo "DROP DATABASE $USER; CREATE DATABASE $USER OWNER=$USER" | sudo -u postgres psql
`flume-cfg bin`/flume-python -u /disk/$USER/flume/run/pybin/dbv.py 127.0.0.1 5432
