#!/usr/local/bin/bash
#
#
# wget -q -O - --keep-session-cookies --save-cookies cookies.txt --post-data 'action=login&umgr=/ihome/mwksaaaaaaaba..m2ksaaaaaaaba/setuid/umgr.py.suwrp&name=useralex&password=a&login=Login' http://click.lcs.mit.edu:8000/cgi-bin/moinlaunch/MyStartingPage


if [ $# -ne 5 ]; then
  echo "usage: login-moinusers.sh {-t | -m} num_users moin_userlist umgrid server:port"
  exit 1;
fi

NUMUSERS=$2
USERLIST=$3
UMGR=/ihome/$4/setuid/umgr.py.suwrp
SERVER=$5


COUNT=0
for PAIR in `cat $USERLIST`; do
    if [ $COUNT -ge $NUMUSERS ]; then
        exit
    fi

    NAME=`echo $PAIR | cut -f 1 -d ','`
    PW=`echo $PAIR | cut -f 2 -d ','`

    
    rm -f cookies.txt

    if [ "$1" = "-t" ]; then
        wget -q -O tmp.html --keep-session-cookies --save-cookies cookies.txt \
            --post-data "action=login&umgr=$UMGR&name=$NAME&password=$PW&login=Login" $SERVER/moin/MyStartingPage

        UID=`grep TRAZ_UID cookies.txt | awk '{ print $7 }'`
        GID=`grep TRAZ_GID cookies.txt | awk '{ print $7 }'`
        TPW=`grep TRAZ_TPW cookies.txt | awk '{ print $7 }'`
    
        echo "$NAME $PW $UID $GID $TPW"

    elif [ "$1" = "-m" ]; then
        wget -q -O /dev/null --keep-session-cookies --save-cookies cookies.txt \
            --post-data "action=login&name=$NAME&password=$PW&login=Login" \
            $SERVER/moin/MyStartingPage

        MOIN_ID=`grep MOIN_ID cookies.txt | awk '{ print $7 }'`
    
        echo "$NAME $PW $MOIN_ID"

    else
        echo "you must specify either -t or -m"
        exit 1
    fi



    COUNT=$(($COUNT+1))
done

