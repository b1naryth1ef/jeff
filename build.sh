#!/bin/bash
dub build --combined &
for dir in $(ls plugins/); do
  pushd plugins/$dir
  dub build --force --combined &
  popd
done
wait
echo "Finished building"
