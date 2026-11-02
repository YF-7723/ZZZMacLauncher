#!/bin/bash
# 公共函数库：路径探测、进程管理、WDF 注入、Vulkan 补丁
# shellcheck shell=bash
set -u

# ---------- 路径（均可用环境变量覆盖） ----------
SUPPORT_DIR="${YAAGL_SUPPORT_DIR:-$HOME/Library/Application Support/Yaagl ZZZ}"
GAME_DIR="${ZZZ_GAME_DIR:-$HOME/Games}"
WINE_PREFIX="${ZZZ_WINE_PREFIX:-$SUPPORT_DIR/wineprefix}"
RUNTIMES_DIR="$SUPPORT_DIR/perf-runtimes"
WDF_DIR="$SUPPORT_DIR/wdf-fix"
LOG_DIR="$HOME/Library/Logs"
LAUNCHER_LOG="$LOG_DIR/ZZZ-launcher.log"

GAME_EXE="$GAME_DIR/ZenlessZoneZero.exe"
GAME_DATA="$GAME_DIR/ZenlessZoneZero_Data"
VULKAN_DLL="$GAME_DATA/Plugins/x86_64/vulkan-1.dll"

# 本仓库内 WDF 模块位置（脚本从仓库拷贝到 $WDF_DIR 再注入）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_WDF_DIR="$REPO_ROOT/third_party/wdf"

WINE_BIN="$SUPPORT_DIR/wine/bin/wine"

# ---------- 日志 ----------
log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '[%s] 警告: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
die()  { printf '[%s] 错误: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; exit 1; }

# ---------- 环境检查 ----------
check_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "本项目仅支持 macOS"
  [ "$(uname -m)" = "arm64" ] || die "需要 Apple Silicon（arm64）Mac"
  if [ ! -x /usr/bin/metalperftrace ]; then
    warn "未找到 metalperftrace（macOS 26+ 自带），性能基准脚本将不可用"
  fi
}

check_game() {
  [ -f "$GAME_EXE" ] || die "未找到游戏可执行文件: ${GAME_EXE}（可用 ZZZ_GAME_DIR=... 指定游戏目录）"
  [ -d "$GAME_DATA" ] || die "未找到游戏数据目录: $GAME_DATA"
}

check_support() {
  [ -d "$SUPPORT_DIR" ] || die "未找到 Yaagl 数据目录: ${SUPPORT_DIR}（请先安装 Yaagl ZZZ 并至少启动一次）"
  [ -d "$WINE_PREFIX" ] || warn "未找到 Wine 前缀: ${WINE_PREFIX}（首次启动时 Wine 会自动创建）"
}

# ---------- Wine 运行时 ----------
wine_version() {
  if [ -x "$WINE_BIN" ]; then
    "$WINE_BIN" --version 2>/dev/null | sed -n 's/^wine-//p' | head -1
  fi
}

wine_is_dxmt() {  # 判断当前运行时是否为 DXMT 版（Wine 11.0 + winemetal）
  [ -f "$SUPPORT_DIR/wine/lib/wine/x86_64-unix/winemetal.so" ] || return 1
  [ -f "$SUPPORT_DIR/wine/lib/wine/x86_64-windows/d3d11.dll" ] || return 1
  local sz
  sz=$(stat -f%z "$SUPPORT_DIR/wine/lib/wine/x86_64-windows/d3d11.dll" 2>/dev/null || echo 0)
  [ "$sz" -gt 3000000 ]
}

wine_is_d3dmetal() {  # 11.20 D3DMetal 运行时（实验性，反作弊不兼容）
  [ "${1:-$(wine_version)}" = "11.20" ] || return 1
  [ -d "$SUPPORT_DIR/wine/lib/external/D3DMetal.framework" ]
}

kill_wine_processes() {
  pkill -9 -f "C:\\\\windows" 2>/dev/null || true
  pkill -9 -f "Yaagl ZZZ/wine" 2>/dev/null || true
  sleep 1
  pkill -9 -f "wineserver|winedevice|wineboot|wine-preloader" 2>/dev/null || true
  sleep 1
}

wineserver_kill() {
  if [ -x "$SUPPORT_DIR/wine/bin/wineserver" ]; then
    "$SUPPORT_DIR/wine/bin/wineserver" -k 2>/dev/null || true
  fi
}

# ---------- WDF 模块 ----------
install_wdf_to_dir() {  # $1 = wine 根目录（含 lib/wine/x86_64-windows）
  local wine_root="$1"
  local lib="$wine_root/lib/wine/x86_64-windows"
  [ -d "$lib" ] || return 1
  mkdir -p "$WDF_DIR"
  if [ -f "$REPO_WDF_DIR/wdfldr.sys" ]; then
    cp -p "$REPO_WDF_DIR/wdfldr.sys" "$REPO_WDF_DIR/wdf01000.sys" "$WDF_DIR/" 2>/dev/null || true
  fi
  [ -f "$WDF_DIR/wdfldr.sys" ] || die "缺少 WDF 模块（$WDF_DIR 与 $REPO_WDF_DIR 都没有）"
  cp -p "$WDF_DIR/wdfldr.sys" "$WDF_DIR/wdf01000.sys" "$lib/"
  chmod 644 "$lib/wdfldr.sys" "$lib/wdf01000.sys" 2>/dev/null || true
}

inject_wdf() {
  install_wdf_to_dir "$SUPPORT_DIR/wine"
}

# ---------- Vulkan 补丁（游戏自带 vulkan-1.dll 与 Wine 冲突，启动时临时移走） ----------
VULKAN_MOVED=0
move_vulkan_away() {
  if [ -f "$VULKAN_DLL" ]; then
    mv -f "$VULKAN_DLL" "$VULKAN_DLL.bak" && VULKAN_MOVED=1
  fi
}

restore_vulkan() {
  if [ "$VULKAN_MOVED" = "1" ] && [ -f "$VULKAN_DLL.bak" ]; then
    mv -f "$VULKAN_DLL.bak" "$VULKAN_DLL"
    VULKAN_MOVED=0
  fi
}

# ---------- 运行时切换 ----------
runtime_snapshot_dir() {  # $1: dxmt|d3dmetal
  case "${1:-dxmt}" in
    dxmt)     echo "$RUNTIMES_DIR/wine-11.0-dxmt" ;;
    d3dmetal) echo "$RUNTIMES_DIR/wine-11.20-d3dmetal" ;;
    *) die "未知运行时: $1（可选 dxmt / d3dmetal）" ;;
  esac
}

install_runtime_from_snapshot() {  # $1: dxmt|d3dmetal
  local mode="$1" src
  src="$(runtime_snapshot_dir "$mode")"
  [ -d "$src" ] || die "运行时快照不存在: ${src}（先运行 scripts/setup.sh）"
  log "安装运行时 $mode ..."
  rm -rf "$SUPPORT_DIR/wine"
  cp -cR "$src" "$SUPPORT_DIR/wine" 2>/dev/null || cp -R "$src" "$SUPPORT_DIR/wine"
  inject_wdf
}

ensure_runtime() {  # $1: dxmt|d3dmetal
  local mode="$1"
  if [ "$mode" = "dxmt" ]; then
    if [ "$(wine_version)" = "11.0" ] && wine_is_dxmt; then
      inject_wdf
      return 0
    fi
    install_runtime_from_snapshot dxmt
  else
    if wine_is_d3dmetal; then
      inject_wdf
      return 0
    fi
    install_runtime_from_snapshot d3dmetal
  fi
}
