#!/usr/local/bin/bash

# Preconditions:
#   a) Create new setuidhandle  `traz-cfg bin`/traz-python `traz-cfg pybin`/mksetuidh.py
#   b) Clear extended attributes for traz mounted partitions

# 0) Make a new usermanager
# 1) Make an s/umgr/moin/ filter (moin trusts umgr)
# 2) Make an s/moin/classic/ filter (classic trusts moin)

# 3) Tag everything in /disk/$USER/moin-instance, /disk/$USER/moin-pages/ with moin_integrity
# 4) Tag /disk/$USER/moin-instance/data/plugin/theme/{rightsidebar|classic} with classic_integrity


TRAZ_CFG=`PATH="$PATH:./bin:../bin" which traz-cfg`
PYRUN=`$TRAZ_CFG bin`/traz-python
PYBIN=`$TRAZ_CFG pybin`
USER=`$TRAZ_CFG user`

echo "UMGR CONFIG"
$PYRUN $PYBIN/initumgr.py | tee tmp1
TRAZ_UMGR_ID=`grep UserID tmp1 | perl -ne '/UserID=(\S+)/; print "$1"'`
UMGR_I_LAB_ARMR=`grep UserID tmp1 | perl -ne '/UserID=(\w+)\.\./; print "$1"'`
echo ""

echo "UMGR->MOIN FILTER"
$PYRUN $PYBIN/makefilter.py -f $UMGR_I_LAB_ARMR moin | tee tmp2
MOIN_I_LAB_LONG=`grep new_integrity tmp2 | awk '{print $2}'`
MOIN_I_LAB_ARMR=`grep new_integrity tmp2 | awk '{print $3}'`
MOIN_I_TAG_LONG=`grep new_integrity tmp2 | awk '{print $4}'`
MOIN_I_TAG_ARMR=`grep new_integrity tmp2 | awk '{print $5}'`
MOIN_I_TAG_PW=`grep new_integrity tmp2 | awk '{print $6}'`
UMGR_MOIN_FILTER=`grep filter tmp2 | awk '{print $2}'`
echo ""

echo "MOIN->CLASSIC FILTER"
$PYRUN $PYBIN/makefilter.py -f $MOIN_I_LAB_ARMR classic | tee tmp3
CLASSIC_I_LAB_LONG=`grep new_integrity tmp3 | awk '{print $2}'`
CLASSIC_I_LAB_ARMR=`grep new_integrity tmp3 | awk '{print $3}'`
CLASSIC_I_TAG_LONG=`grep new_integrity tmp3 | awk '{print $4}'`
CLASSIC_I_TAG_ARMR=`grep new_integrity tmp3 | awk '{print $5}'`
CLASSIC_I_TAG_PW=`grep new_integrity tmp3 | awk '{print $6}'`
MOIN_CLASSIC_FILTER=`grep filter tmp3 | awk '{print $2}'`
echo ""

echo "MOIN->RIGHTSIDEBAR FILTER"
$PYRUN $PYBIN/makefilter.py -f $MOIN_I_LAB_ARMR rightsidebar | tee tmp3
RIGHTSIDEBAR_I_LAB_LONG=`grep new_integrity tmp3 | awk '{print $2}'`
RIGHTSIDEBAR_I_LAB_ARMR=`grep new_integrity tmp3 | awk '{print $3}'`
RIGHTSIDEBAR_I_TAG_LONG=`grep new_integrity tmp3 | awk '{print $4}'`
RIGHTSIDEBAR_I_TAG_ARMR=`grep new_integrity tmp3 | awk '{print $5}'`
RIGHTSIDEBAR_I_TAG_PW=`grep new_integrity tmp3 | awk '{print $6}'`
MOIN_RIGHTSIDEBAR_FILTER=`grep filter tmp3 | awk '{print $2}'`
echo ""

for I in `seq 0 99`
do
  F=~/moin.env.$I
  if [ ! -e $F ]; then
    break
  fi
done
touch $F

for V in TRAZ_UMGR_ID UMGR_I_LAB_ARMR \
    MOIN_I_TAG_LONG MOIN_I_TAG_ARMR MOIN_I_LAB_LONG MOIN_I_LAB_ARMR MOIN_I_TAG_PW \
    CLASSIC_I_TAG_LONG CLASSIC_I_TAG_ARMR CLASSIC_I_LAB_LONG CLASSIC_I_LAB_ARMR CLASSIC_I_TAG_PW \
    RIGHTSIDEBAR_I_TAG_LONG RIGHTSIDEBAR_I_TAG_ARMR RIGHTSIDEBAR_I_LAB_LONG RIGHTSIDEBAR_I_LAB_ARMR RIGHTSIDEBAR_I_TAG_PW \
    UMGR_MOIN_FILTER MOIN_CLASSIC_FILTER MOIN_RIGHTSIDEBAR_FILTER
do
  export `eval "echo $V"`
  echo "setenv $V" `eval "echo \\$$V"`
#  echo "setenv $V" `eval "echo \\$$V"` >> $F
  echo "export $V="`eval "echo \\$$V"` >> $F
done  

# Comment out this section to setup moin for NFS experiments
echo "CREATING INSTANCE"
sh -x ./createinstance.sh -copy > tmp4

echo "Dont forget to update your traz.conf and environment variables"


