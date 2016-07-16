#!/bin/bash
for dir in $(ls plugins/); do
  pushd plugins/$dir
  dub build --force &
  popd
done
wait
echo "Finished building"
