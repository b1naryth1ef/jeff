#!/bin/bash
dub build --combined --parallel ${@:1} &
for dir in $(ls plugins/); do
  pushd plugins/$dir
  dub build --force --combined --parallel ${@:1} &
  popd
done
wait
echo "Finished building"
