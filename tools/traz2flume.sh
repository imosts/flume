#!/bin/sh

repl()
{

    find -E . \( -regex ".*\.(C|T|py|pl|x|h|mk|c|conf)" -and \
                         \! -regex ".*\.svn.*" -and -type f \) \
	-exec perl -pi -e $1 {} \;
}

rename()
{
    FILES=`find . \( -name "*$1*" -and \! -name '*.svn*' \) -type $2 `
    for f in $FILES
    do
      svn mv $f `echo $f | sed -e $3 `
    done
}

renames()
{
    rename $1 d $2
    rename $1 f $2
}



if false
then
repl 's/TRAZ/FLUME/g'
repl 's/traz/flume/g' 
repl 's/Traz/Flume/g'
repl 's/tz/flm/g'

svn commit
fi

renames traz 's/traz/flume/g'
renames tz   's/tz/flm/g'

svn commit
