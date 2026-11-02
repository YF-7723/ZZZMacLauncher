#!/bin/bash
# 重新把 WDF 兼容模块注入当前 Wine 运行时
# 适用场景：Yaagl 更新/重装了 Wine、或游戏报 WDFLDR.SYS not found / initDriver Failed
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

check_support
[ -x "$WINE_BIN" ] || die "未找到 Wine 运行时: $WINE_BIN"

log "重新注入 WDF 模块 ..."
inject_wdf
log "完成"
ls -l "$SUPPORT_DIR/wine/lib/wine/x86_64-windows/wdfldr.sys" \
      "$SUPPORT_DIR/wine/lib/wine/x86_64-windows/wdf01000.sys" 2>/dev/null
