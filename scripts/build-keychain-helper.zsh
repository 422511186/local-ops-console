#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SOURCE="$ROOT/native/local_ops_keychain.c"
OUTPUT="${1:-$ROOT/bin/local-ops-keychain}"

source "$HOME/.zshrc" >/dev/null 2>&1 || true
proxy_on >/dev/null 2>&1 || true

[[ "$(uname -s)" == "Darwin" ]] || {
  command printf '%s\n' 'Local Ops Keychain Helper 只能在 macOS 上构建' >&2
  exit 1
}

CLANG="$(xcrun --find clang 2>/dev/null || true)"
SDKROOT="$(xcrun --show-sdk-path 2>/dev/null || true)"
[[ -n "$CLANG" && -x "$CLANG" ]] || {
  command printf '%s\n' '缺少 Clang 编译器，请先安装 Xcode Command Line Tools' >&2
  exit 1
}
[[ -n "$SDKROOT" && -d "$SDKROOT" ]] || {
  command printf '%s\n' '找不到 macOS SDK，请重新安装 Xcode Command Line Tools' >&2
  exit 1
}

command mkdir -p "${OUTPUT:h}"

# 默认跟随宿主架构原生编译（方案 A）。
# 传入 LOCAL_OPS_KEYCHAIN_ARCH=arm64|x86_64|universal 可在 Intel Mac 上交叉编译 arm64，
# 或在 Apple Silicon 上交叉编译 x64，universal 编出通用二进制。
ARCH_FLAGS=()
case "${LOCAL_OPS_KEYCHAIN_ARCH:-}" in
  arm64) ARCH_FLAGS=(-arch arm64) ;;
  x86_64) ARCH_FLAGS=(-arch x86_64) ;;
  universal) ARCH_FLAGS=(-arch arm64 -arch x86_64) ;;
  '') ;;
  *)
    command printf '%s\n' "LOCAL_OPS_KEYCHAIN_ARCH 仅支持 arm64、x86_64 或 universal" >&2
    exit 1
    ;;
esac

"$CLANG" -isysroot "$SDKROOT" -mmacosx-version-min=12.0 -O2 -Wall -Wextra \
  "${ARCH_FLAGS[@]}" \
  -framework Security -framework CoreFoundation "$SOURCE" -o "$OUTPUT"
command chmod 755 "$OUTPUT"
/usr/bin/codesign --force --sign - "$OUTPUT" >/dev/null 2>&1 || true
command printf '%s\n' "已构建 Keychain Helper：$OUTPUT（架构：${LOCAL_OPS_KEYCHAIN_ARCH:-native}）"
