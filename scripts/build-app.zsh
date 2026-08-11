#!/bin/zsh
set -euo pipefail

source "$HOME/.zshrc" >/dev/null 2>&1 || true
proxy_on >/dev/null 2>&1 || true

ROOT="${0:A:h:h}"
DESKTOP="$ROOT/desktop"
TARGET_DIR="/Applications"

if [[ ! -w "$TARGET_DIR" ]]; then
  TARGET_DIR="$HOME/Applications"
  command mkdir -p "$TARGET_DIR"
fi

# 默认按宿主架构构建，可通过 LOCAL_OPS_BUILD_ARCH=arm64|x64 覆盖。
# Intel Mac 上 uname -m 返回 x86_64，归一化为 electron-builder 使用的 x64。
case "${LOCAL_OPS_BUILD_ARCH:-}" in
  arm64|x64) ARCH="$LOCAL_OPS_BUILD_ARCH" ;;
  '')
    case "$(uname -m)" in
      arm64) ARCH="arm64" ;;
      x86_64) ARCH="x64" ;;
      *) command printf '%s\n' "不支持的宿主架构：$(uname -m)" >&2; exit 1 ;;
    esac
    ;;
  *) command printf '%s\n' "LOCAL_OPS_BUILD_ARCH 仅支持 arm64 或 x64" >&2; exit 1 ;;
esac

cd "$DESKTOP"
npm install
"$(command -v npm)" run "dmg:${ARCH}"

SOURCE_APP="$DESKTOP/dist/mac-${ARCH}/Local Ops.app"
TARGET_APP="$TARGET_DIR/Local Ops.app"
APP_VERSION="$(node -p 'require("./package.json").version')"
DMG_PATH="$DESKTOP/dist/Local-Ops-${APP_VERSION}-${ARCH}.dmg"

if [[ ! -d "$SOURCE_APP" ]]; then
  command printf '%s\n' "没有找到构建产物：$SOURCE_APP" >&2
  exit 1
fi
if [[ -z "$DMG_PATH" || ! -f "$DMG_PATH" ]]; then
  command printf '%s\n' '没有找到 DMG 构建产物' >&2
  exit 1
fi

/usr/bin/osascript -e 'tell application "Local Ops" to quit' >/dev/null 2>&1 || true
# `before-quit` records the remembered session and can take several seconds.
# Wait for the GUI process itself (the LaunchAgent backend has server.mjs as an
# extra argument) so `open` cannot accidentally reactivate the old build.
OLD_APP_EXECUTABLE="$TARGET_APP/Contents/MacOS/Local Ops"
for attempt in {1..60}; do
  if ! /usr/bin/pgrep -f "^${OLD_APP_EXECUTABLE:q}$" >/dev/null 2>&1; then
    break
  fi
  /bin/sleep 0.1
done
if /usr/bin/pgrep -f "^${OLD_APP_EXECUTABLE:q}$" >/dev/null 2>&1; then
  command printf '%s\n' '旧版 Local Ops 未能正常退出，请退出 App 后重试构建。' >&2
  exit 1
fi
/usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"
/usr/bin/codesign --force --deep --sign - "$TARGET_APP"
/usr/bin/codesign --verify --deep --strict "$TARGET_APP"
/usr/bin/open -n "$TARGET_APP"

command printf '%s\n' "Local Ops.app 已安装到：$TARGET_APP"
command printf '%s\n' "可分发 DMG：$DMG_PATH"
