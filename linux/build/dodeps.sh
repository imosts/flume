#!/bin/sh

dotmp=0
domv=1

args=`getopt tm $*`
set -- $args
for i
do
  case "$i"
      in
      -t)
	  dotmp=1
	  shift
	  ;;
      -m) 
	  domv=1
	  shift
	  ;;
      --)
	  shift
	  break
	  ;;
      *)
	  echo "bad flag: $i" 1>&2
	  ;;
  esac
done

lo=$1

if [ $# -ne 1 ]
then
    echo "need 1 argument (a .lo file name)" 1>&2
    exit 1
fi

stem=`dirname $lo`/`basename ${lo} .lo`
tmp_d=$stem.Td
perm_d=$stem.d
	  
if [ $dotmp -eq 1 ]
then
    echo "-MT $lo -MD -MP -MF $tmp_d"
elif [ $domv -eq 1 ]
then
    echo "mv $tmp_d $perm_d"
else
    echo "Don't know what to do!" 1>&2
    exit 1
fi
