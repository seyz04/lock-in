#!/bin/zsh
# Builds Lock In with full Xcode and installs it to /Applications/Lock In.app (Launchpad, Spotlight, Dock), then opens it.
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")"
xcodebuild -project LockIn.xcodeproj -target LockIn -configuration Release SYMROOT="$PWD/build" -quiet build
pkill -x LockIn 2>/dev/null || true
APP="/Applications/Lock In.app"
[ -w /Applications ] || APP="$HOME/Applications/Lock In.app"
rm -rf "$APP" "$HOME/Applications/Lock In.app"
cp -R build/Release/LockIn.app "$APP"
codesign --force --deep -s - "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true
open "$APP"
echo "Installed: $APP"
