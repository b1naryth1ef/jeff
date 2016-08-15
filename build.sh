#!/bin/bash
dub build --combined --parallel ${@:1} &
for dir in $(ls -d plugins/*/); do
  pushd $dir
  dub build --force --combined --parallel ${@:1} &
  popd
done
wait
echo "Finished building"
