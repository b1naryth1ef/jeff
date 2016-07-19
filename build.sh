#!/bin/bash
dub build --combined &
for dir in $(ls plugins/); do
  pushd plugins/$dir
  dub build --force &
  popd
done
wait
echo "Finished building"
