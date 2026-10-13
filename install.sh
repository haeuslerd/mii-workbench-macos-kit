#!/bin/bash
# Set up SAP MII Workbench on an Apple Silicon Mac so a downloaded Workbench.jsp
# opens with a double-click. Run from Terminal: ./install.sh
# Safe to re-run. Needs Homebrew (https://brew.sh) and the admin password once.
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/MII Workbench.app"
BUNDLE_ID="io.github.mii-workbench-macos-kit"
JSP_UTI="io.github.mii-workbench-macos-kit.jsp"
CFG="$HOME/.config/mii-workbench"
OWS_PROPS="$HOME/.config/icedtea-web/deployment.properties"

command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }

echo "==> Homebrew packages (OpenWebStart, Azul Zulu 8, duti)"
brew list --cask openwebstart >/dev/null 2>&1 || brew install --cask openwebstart
[ -x /Library/Java/JavaVirtualMachines/zulu-8.jdk/Contents/Home/bin/java ] || brew install --cask zulu@8
command -v duti >/dev/null || brew install duti

echo "==> Launcher script -> ~/bin/mii-workbench"
mkdir -p "$HOME/bin" "$CFG" "$HOME/Library/Logs"
cp "$KIT/bin/mii-workbench" "$HOME/bin/mii-workbench"
chmod +x "$HOME/bin/mii-workbench"

echo "==> Right-click fix: build Java agent -> $CFG/mac-popup-fix.jar"
JDK=/Library/Java/JavaVirtualMachines/zulu-8.jdk/Contents/Home
BUILD="$(mktemp -d)"
mkdir "$BUILD/classes"
"$JDK/bin/javac" -source 8 -target 8 -d "$BUILD/classes" "$KIT/agent/PopupTriggerFix.java"
printf 'Premain-Class: macfix.PopupTriggerFix\n' > "$BUILD/manifest.txt"
"$JDK/bin/jar" cfm "$CFG/mac-popup-fix.jar" "$BUILD/manifest.txt" -C "$BUILD/classes" macfix
cp "$KIT/agent/PopupTriggerFix.java" "$CFG/"
rm -rf "$BUILD"

echo "==> OpenWebStart: keep the Workbench on Java 8"
mkdir -p "$(dirname "$OWS_PROPS")"
touch "$OWS_PROPS"
if grep -q '^ows.jvm.manager.versionRange=' "$OWS_PROPS"; then
    sed -i '' 's/^ows.jvm.manager.versionRange=.*/ows.jvm.manager.versionRange=1.8*/' "$OWS_PROPS"
else
    echo 'ows.jvm.manager.versionRange=1.8*' >> "$OWS_PROPS"
fi

echo "==> Double-click app -> $APP"
mkdir -p "$HOME/Applications"
rm -rf "$APP"
osacompile -o "$APP" "$KIT/app/MII Workbench.applescript"
# Claim .jsp: declare a file type for it and register the app as its owner
python3 - "$APP/Contents/Info.plist" "$BUNDLE_ID" "$JSP_UTI" <<'PY'
import plistlib, sys
path, bundle_id, uti = sys.argv[1:4]
with open(path, "rb") as f:
    pl = plistlib.load(f)
pl["CFBundleIdentifier"] = bundle_id
pl["LSUIElement"] = True  # only starts the launcher, no Dock icon
pl["UTImportedTypeDeclarations"] = [{
    "UTTypeIdentifier": uti,
    "UTTypeDescription": "SAP MII Workbench launcher",
    "UTTypeConformsTo": ["public.data"],
    "UTTypeTagSpecification": {"public.filename-extension": ["jsp"]},
}]
# replaces osacompile's droplet default, which accepts every file type
pl["CFBundleDocumentTypes"] = [{
    "CFBundleTypeName": "SAP MII Workbench launcher",
    "CFBundleTypeRole": "Viewer",
    "LSHandlerRank": "Owner",
    "LSItemContentTypes": [uti],
}]
with open(path, "wb") as f:
    plistlib.dump(pl, f)
PY
[ -f /Applications/OpenWebStart/Icon-512.png ] &&
    sips -s format icns /Applications/OpenWebStart/Icon-512.png --out "$APP/Contents/Resources/droplet.icns" >/dev/null 2>&1 || true
codesign --force --deep -s - "$APP" 2>/dev/null
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
duti -s "$BUNDLE_ID" "$JSP_UTI" all

echo
echo "Done. Download Workbench.jsp from MII and double-click it."
echo "Accept every security prompt (answer Yes). Log: ~/Library/Logs/mii-workbench.log"
