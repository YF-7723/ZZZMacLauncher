#!/bin/bash
# 卸载本项目添加的内容（不删除游戏、不删除 Yaagl）
# 用法: uninstall.sh [--purge] [--restore-wine]
#   --purge        同时删除运行时快照与 WDF 备份（约 2GB）
#   --restore-wine 把 Wine 恢复为安装前的 DXMT 快照
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

PURGE=0
RESTORE_WINE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --purge)        PURGE=1; shift ;;
    --restore-wine) RESTORE_WINE=1; shift ;;
    -h|--help)      sed -n '2,7p' "$0"; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

check_support
kill_wine_processes

if [ "$RESTORE_WINE" = "1" ]; then
  if [ -d "$RUNTIMES_DIR/wine-11.0-dxmt" ]; then
    log "恢复 Wine 运行时为 DXMT 快照 ..."
    install_runtime_from_snapshot dxmt
  else
    warn "没有 DXMT 运行时快照，跳过恢复"
  fi
fi

# 删除桌面启动器
for f in "$HOME/Desktop/绝区零-启动.command" "$HOME/Desktop/绝区零-启动(DX12实验-可能崩溃).command"; do
  [ -f "$f" ] && rm -f "$f" && log "已删除: $f"
done

if [ "$PURGE" = "1" ]; then
  log "删除运行时快照与 WDF 备份（约 2GB）..."
  rm -rf "$RUNTIMES_DIR" "$WDF_DIR"
  rm -f "$LAUNCHER_LOG"
fi

log "卸载完成。游戏本体与 Wine 前缀均未改动。"
