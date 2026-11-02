#!/bin/bash
# 安装/更换 WDF 模块来源
# 用法:
#   install-wdf.sh                          # 使用本仓库 third_party/wdf 内的模块（默认）
#   install-wdf.sh --from-wine /path/to/wine  # 从指定的 Wine 根目录提取
#   install-wdf.sh --from-tarball FILE_OR_URL # 从 dwproton/Wine 的 .tar.xz 发布包提取
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

SOURCE_WINE=""
TARBALL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --from-wine)    SOURCE_WINE="$2"; shift 2 ;;
    --from-tarball) TARBALL="$2"; shift 2 ;;
    -h|--help)      sed -n '2,7p' "$0"; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

mkdir -p "$WDF_DIR"

extract_from_wine_root() {  # $1: wine 根目录
  local root="$1"
  local lib="$root/lib/wine/x86_64-windows"
  [ -f "$lib/wdfldr.sys" ]   || return 1
  [ -f "$lib/wdf01000.sys" ] || return 1
  cp -p "$lib/wdfldr.sys" "$lib/wdf01000.sys" "$WDF_DIR/"
}

if [ -n "$SOURCE_WINE" ]; then
  log "从 Wine 目录提取 WDF: $SOURCE_WINE"
  extract_from_wine_root "$SOURCE_WINE" || die "该 Wine 目录中没有 wdfldr.sys / wdf01000.sys"
elif [ -n "$TARBALL" ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  if printf '%s' "$TARBALL" | grep -q '^https\?://'; then
    log "下载 $TARBALL ..."
    curl -L --max-time 1800 -o "$TMP/pkg.tar.xz" "$TARBALL" || die "下载失败"
    ARCHIVE="$TMP/pkg.tar.xz"
  else
    ARCHIVE="$TARBALL"
  fi
  log "解压并查找 WDF 模块（约 340MB 包，需要一点时间）..."
  tar -xJf "$ARCHIVE" -C "$TMP" 2>/dev/null || die "解压失败: $ARCHIVE"
  FOUND_LIB="$(find "$TMP" -type d -path '*lib/wine/x86_64-windows' | head -1)"
  [ -n "$FOUND_LIB" ] || die "包内未找到 lib/wine/x86_64-windows"
  cp -p "$FOUND_LIB/wdfldr.sys" "$FOUND_LIB/wdf01000.sys" "$WDF_DIR/" 2>/dev/null \
    || die "包内未找到 WDF 模块"
else
  log "使用本仓库 third_party/wdf 内的模块"
  cp -p "$REPO_WDF_DIR/wdfldr.sys" "$REPO_WDF_DIR/wdf01000.sys" "$WDF_DIR/"
fi

chmod 644 "$WDF_DIR/wdfldr.sys" "$WDF_DIR/wdf01000.sys" 2>/dev/null || true
log "已保存到: $WDF_DIR"
shasum -a 256 "$WDF_DIR/wdfldr.sys" "$WDF_DIR/wdf01000.sys" 2>/dev/null || true

# 若当前已有 Wine 运行时，顺手注入
if [ -x "$WINE_BIN" ]; then
  inject_wdf
  log "已注入当前 Wine 运行时"
fi
