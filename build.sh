#!/bin/zsh
# Build, sign and install PixProSwapLayers.app — v1.1.0
#
#   ./build.sh [--no-install]
#
# Installing is the default, as in every other project here.
#
# osacompile writes a bare applet: no CFBundleIdentifier, the stock applet
# icon, no version. All three are put back below, the same way
# PixProTransform's build does it, because codesign seals whatever it finds —
# with no identifier it seals the bundle NAME instead.
set -e
cd "${0:A:h}"

APP="PixProSwapLayers.app"
# Read from the script itself, so the bundle can never claim a version the
# code does not. Hard-coding it here once shipped an app reporting the
# previous release.
VERSION=$(/usr/bin/sed -n 's/^property scriptVersion : "\(.*\)"/\1/p' PixProSwapLayers.applescript)
[[ -n "$VERSION" ]] || { echo "error: no scriptVersion in PixProSwapLayers.applescript" >&2; exit 1; }
SIGN_ID="4208ABA3EC12F24C1F09C7BB624EFF68B44259DB"   # Developer ID Application

if ! security find-identity -p codesigning | grep -q "$SIGN_ID"; then
    echo "error: signing identity $SIGN_ID not in keychain" >&2
    exit 1
fi

echo "==> compiling $VERSION"
rm -rf "$APP"
osacompile -o "$APP" PixProSwapLayers.applescript

# The applet stub is copied from THIS machine by osacompile, so it carries
# this system's minimum macOS. Stamped back before signing — codesign seals
# whatever it finds. See ~/bin/pixpro_lower_min.
~/bin/pixpro_lower_min "$APP"

echo "==> installing the icon"
# osacompile ships the stock applet icon, and writes an Assets.car whose
# CFBundleIconName WINS over CFBundleIconFile — so a custom icns can sit in
# the bundle and never be used. Both have to go.
cp PixProSwapLayers.icns "$APP/Contents/Resources/PixProSwapLayers.icns"
rm -f "$APP/Contents/Resources/applet.icns" "$APP/Contents/Resources/Assets.car"

echo "==> restoring bundle identity (osacompile drops it)"
/usr/bin/python3 - "$APP" "$VERSION" <<'PY'
import plistlib, sys
p = sys.argv[1] + "/Contents/Info.plist"
version = sys.argv[2]
d = plistlib.load(open(p, "rb"))
d.pop("CFBundleIconName", None)
d.update({
    "CFBundleName": "PixProSwapLayers",
    "CFBundleDisplayName": "PixProSwapLayers",
    "CFBundleIdentifier": "com.timmccoy.pixproswaplayers",
    "CFBundleShortVersionString": version,
    "CFBundleVersion": version,
    "NSHumanReadableCopyright": "Copyright © 2026 Tim McCoy. All rights reserved.",
    "CFBundleGetInfoString": "PixProSwapLayers — exchange the stacking order of the selected layers.",
    "NSAppleEventsUsageDescription":
        "PixProSwapLayers swaps the order of the selected layers in Pixelmator Pro for you.",
    "CFBundleIconFile": "PixProSwapLayers",
})
plistlib.dump(d, open(p, "wb"))
PY

# The macOS 26+ icon. The stock Assets.car and its CFBundleIconName are
# removed above; this installs an Assets.car holding the app's own Icon
# Composer icon, which macOS 26+ uses instead of the .icns (still what
# macOS 13-25 show). See ~/bin/glass_icon.
~/bin/glass_icon "$APP" icon/AppIcon.icon

echo "==> signing with Developer ID"
codesign --force --deep --timestamp --options runtime \
    --entitlements "$HOME/My_Applications/_signing/pixpro-applet.entitlements" \
    --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict "$APP"

if [[ "$1" == "--no-install" ]]; then
    echo "==> --no-install: built at $PWD/$APP"
    exit 0
fi

echo "==> installing to /Applications"
pkill -x PixProSwapLayers 2>/dev/null || true
rm -rf "/Applications/$APP"
cp -R "$APP" /Applications/
xattr -dr com.apple.quarantine "/Applications/$APP" 2>/dev/null || true
codesign -dv "/Applications/$APP" 2>&1 | grep -E "Identifier=|Authority="
plutil -extract CFBundleShortVersionString raw "/Applications/$APP/Contents/Info.plist"
echo
echo "Not yet notarized. To notarize and staple:"
echo "  ~/My_Applications/_signing/pixpro_release.sh all /Applications/$APP"
