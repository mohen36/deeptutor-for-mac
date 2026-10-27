#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "未找到 Swift 编译器。请执行 xcode-select --install，安装完成后重新运行。"
  exit 1
fi

APP="$SCRIPT_DIR/dist/DeepTutor for Mac Fixed.app"
mkdir -p "$SCRIPT_DIR/dist"

echo "正在编译 Swift 原生 Mac 应用…"
swiftc -O -framework AppKit -framework WebKit Sources/main.swift -o "$SCRIPT_DIR/dist/DeepTutorForMac-compiled"

# Only create the .app bundle after a successful compile; previous failed
# builds could leave an empty Contents/MacOS directory behind.
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SCRIPT_DIR/dist/DeepTutorForMac-compiled" "$APP/Contents/MacOS/DeepTutorForMac"
cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc code signing is local-only; no Apple Developer account required.
codesign --force --deep --sign - "$APP"

echo "构建完成：$APP"
echo "可把 DeepTutor for Mac.app 拖进 /Applications，然后双击运行。"
open "$SCRIPT_DIR/dist"
