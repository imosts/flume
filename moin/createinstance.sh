#!/usr/local/bin/bash
#
#  Creates an instance and compiles pyc files.  Expects all the moin
#  env variables to be set.
#
# run like this:
#  cd dir; ./createinstance.sh [-copy] [-nfs]
#

echo "creating instance"
TRAZ_CFG=`PATH="$PATH:./bin:../bin" which traz-cfg`

if test "${TRAZ_GLOBAL}"; then
    INSTANCE="/usr/local/moin-instance"
    PAGEDIR="/usr/local/moin-pages"
    USERDIR="/usr/local/moin-users"
    THEMEDIR="/usr/local/moin-themes"
elif [ "$1" = "-nfs" ]; then
    INSTANCE="/disk/yipal/moin-instance"
    PAGEDIR="/mnt/rael"
    USERDIR="/mnt/rael"
    THEMEDIR="/mnt/rael"
    INITARGS="-G -I rael.lcs.mit.edu:38423"
else
    INSTANCE="/disk/${USER}/moin-instance"
    PAGEDIR="/disk/${USER}/moin-ihome"
    USERDIR="/disk/${USER}/moin-ihome"
    THEMEDIR="/disk/${USER}/moin-ihome"
fi

if test "${TRAZ_GLOBAL}"; then
    MOIN_USER="www"
else
    MOIN_USER="yipal"
fi

MOIN_FILES=`pwd`
SHARE=$MOIN_FILES/share/moin

echo "** For best performance when benchmarking, checkout traz/moin on the local disk"

for D in $INSTANCE $INSTANCE/cgi-bin $PAGEDIR/$MOIN_I_LAB_ARMR $USERDIR $THEMEDIR \
    $THEMEDIR/$MOIN_I_LAB_ARMR $THEMEDIR/$CLASSIC_I_LAB_ARMR $THEMEDIR/$RIGHTSIDEBAR_I_LAB_ARMR
  do
  if [ ! -e $D ]; then
      mkdir -p $D
  fi
done

if [ "$1" = "-copy" -o "$2" = "-copy" ]; then
  echo "here"
  rm -r $INSTANCE/data
  rm -r $INSTANCE/underlay
  cp -R $SHARE/data $INSTANCE
  cp -R $SHARE/underlay $INSTANCE
  rm -rf `find $INSTANCE -name .svn`
fi

cp -R /disk/yipal/moin-page-backups/* $PAGEDIR/$MOIN_I_LAB_ARMR/

if [ ! "$1" = "-nfs" -a ! "$2" = "-nfs" ]; then
    chown -R $MOIN_USER.$MOIN_USER $INSTANCE $PAGEDIR $USERDIR $THEMEDIR 
    chmod -R ug+rwX $PAGEDIR $USERDIR $THEMEDIR 
    chmod -R o-rwx $PAGEDIR $USERDIR $THEMEDIR 
fi

$PYLIB=`$TRAZ_CFG pylib`
cat $SHARE/server/moin.cgi      \
  | sed "s|PREFIX|$MOIN_FILES|" \
  | sed "s|PYLIB|$PYLIB|"       \
  | sed "s|INSTANCE|$INSTANCE|" > $INSTANCE/cgi-bin/moin.cgi

sed "s|PREFIX|$MOIN_FILES|" $SHARE/server/compilemoin.py > $INSTANCE/cgi-bin/compilemoin.py
cat $SHARE/config/wikiconfig.py | sed "s|INSTANCE|$INSTANCE|" > $INSTANCE/cgi-bin/wikiconfig.py

./compilemoin.sh $INSTANCE


echo "SETTING LABELS"
cp $SHARE/data/plugin/theme/modern.py $THEMEDIR/$MOIN_I_LAB_ARMR/
cp $SHARE/data/plugin/theme/classic.py $THEMEDIR/$CLASSIC_I_LAB_ARMR/
cp $SHARE/data/plugin/theme/rightsidebar.py $THEMEDIR/$RIGHTSIDEBAR_I_LAB_ARMR/

INITFILE=`$TRAZ_CFG bin`/traz/`$TRAZ_CFG tag`/initfile

$INITFILE $INITARGS -c -i $MOIN_I_LAB_LONG `find $PAGEDIR/$MOIN_I_LAB_ARMR`
$INITFILE $INITARGS -c -i $MOIN_I_LAB_LONG `find $THEMEDIR/$MOIN_I_LAB_ARMR`
$INITFILE $INITARGS -c -i $CLASSIC_I_LAB_LONG `find $THEMEDIR/$CLASSIC_I_LAB_ARMR`
$INITFILE $INITARGS -c -i $RIGHTSIDEBAR_I_LAB_LONG `find $THEMEDIR/$RIGHTSIDEBAR_I_LAB_ARMR`


echo "Done."

