#!/bin/bash
# 切换 Wine 运行时（不启动游戏）
# 用法: switch-runtime.sh [dxmt|d3dmetal]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

MODE="${1:-dxmt}"
case "$MODE" in dxmt|d3dmetal) ;; *) die "未知模式: ${MODE}（可选 dxmt / d3dmetal）" ;; esac

check_support
kill_wine_processes
install_runtime_from_snapshot "$MODE"
log "切换完成，当前运行时: wine-$(wine_version)（${MODE}）"
