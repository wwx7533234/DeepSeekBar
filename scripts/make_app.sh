#!/bin/bash
# 打包 DeepSeekBar.app（菜单栏应用，不占 Dock）
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> swift build -c release"
swift build -c release

DIST=dist
APP="$DIST/DeepSeekBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/DeepSeekBar "$APP/Contents/MacOS/DeepSeekBar"

# 图标
if [ ! -f "$DIST/AppIcon.icns" ] || [ scripts/generate_icon.swift -nt "$DIST/AppIcon.icns" ]; then
    echo "==> 生成 App 图标"
    swift scripts/generate_icon.swift scripts/AppIcon.iconset >/dev/null
    iconutil -c icns scripts/AppIcon.iconset -o "$DIST/AppIcon.icns"
fi
cp "$DIST/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>DeepSeekBar</string>
    <key>CFBundleIdentifier</key><string>com.dsbar.deepseek</string>
    <key>CFBundleName</key><string>DeepSeekBar</string>
    <key>CFBundleDisplayName</key><string>DeepSeek 余额与用量</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.3.1</string>
    <key>CFBundleVersion</key><string>5</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

xattr -cr "$APP" 2>/dev/null || true
# Documents 在 iCloud 同步目录下，Finder 会反复打 FinderInfo，签名前再清一次
xattr -d com.apple.FinderInfo "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP"
echo "==> ✅ $APP"
