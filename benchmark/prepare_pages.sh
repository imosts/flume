#!/usr/local/bin/bash

if [ $# -ne 3 ]; then
  echo "usage: prepare-pages.sh num_pages {-m | -t} moin_ilab"
  exit 1
fi

NUMPAGES=$1
COUNT=0

while [ $COUNT -lt $NUMPAGES ]; do
  echo "Copying TestPage$COUNT"

  if [ "$2" = "-t" ]; then
      rm -rf TestPage$COUNT
      cp -p -r BaseTestPage TestPage$COUNT
      `traz-cfg bin`/traz/`traz-cfg tag`/initfile -c `find TestPage$COUNT`
      `traz-cfg bin`/traz/`traz-cfg tag`/initfile -i $3 `find TestPage$COUNT`

  elif [ "$2" = "-m" ]; then
      rm -rf TestPage$COUNT
      cp -p -r BaseTestPage TestPage$COUNT
      chown -R yipal TestPage$COUNT
  fi

  COUNT=$(($COUNT+1))
done

