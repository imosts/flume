#!/usr/local/bin/bash
#
#
# wget -q -O - --keep-session-cookies --save-cookies cookies.txt --post-data 'action=login&umgr=/ihome/mwksaaaaaaaba..m2ksaaaaaaaba/setuid/umgr.py.suwrp&name=useralex&password=a&login=Login' http://click.lcs.mit.edu:8000/cgi-bin/moinlaunch/MyStartingPage
#
# wget -O - --post-data 'action=userform&name=testuser2&password=pw&password2=pw&email=testuser2&create=Create Profile' click.lcs.mit.edu:8000/cgi-bin/moinlaunch/UserPreferences

if [ $# -ne 3 ]; then
  echo "usage: create-moinusers.sh { -t | -m } num_users server:port/moin"
  exit 1;
fi

MODE=$1
NUMUSERS=$2
URL=$3

COUNT=0
while [ $COUNT -lt $NUMUSERS ]; do
    NAME=`python randname.py`
    EMAIL=$NAME
    PW=pw

    echo "$NAME,$PW"
    if [ "$MODE" = "-t" ]; then
        wget -q -O tmp.html  --post-data "action=createuser&username=$NAME&password=$PW&submit=Create" $URL
    elif [ "$MODE" = "-m" ]; then
        wget -q -O tmp.html --post-data "action=userform&name=$NAME&password=$PW&password2=$PW&email=$NAME&create=Create+Profile" $URL
    else
        echo "invalid mode option"
        exit 1
    fi

    COUNT=$(($COUNT+1))
done

