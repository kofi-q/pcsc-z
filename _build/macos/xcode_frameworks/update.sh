#!/usr/bin/env bash
set -euo pipefail
set -x

SCRIPT_DIR="$(dirname "$0")"

SDK_PATH='/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.2.sdk'
FRAMEWORKS_PATH="$SDK_PATH/System/Library/Frameworks"

# Clear previous versions.
rm -rf "${SCRIPT_DIR:?}"/Frameworks/
mkdir -p "${SCRIPT_DIR:?}"/Frameworks

# Copy framework files from local SDK.
cp -R $FRAMEWORKS_PATH/PCSC.framework "$SCRIPT_DIR"/Frameworks/PCSC.framework

# Remove unused headers/modules.
find . \( -name "Headers" -o -name "Modules" \) -print0 | xargs -0 rm -rf
