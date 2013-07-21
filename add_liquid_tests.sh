#!/bin/sh
if [ "$#" -ne 1 ] || ! [ -d "$1" ]; then
  echo "Usage: $0 <directory to liquid source tree>" >&2
  exit 1
fi

LIQUID=$(readlink -e $1)
ln -s $LIQUID/lib test/liquid/lib
ln -s $LIQUID/test/liquid test/liquid/test/liquid
ln -s $LIQUID/test/test_helper.rb test/liquid/test/liquid_test_helper.rb
