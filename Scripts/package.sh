#!/bin/bash
# Builds the app and zips it for a GitHub release: build/Swappy.zip
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build.sh
rm -f build/Swappy.zip
ditto -c -k --keepParent build/Swappy.app build/Swappy.zip
echo "Packaged build/Swappy.zip ($(du -h build/Swappy.zip | cut -f1 | xargs))"
