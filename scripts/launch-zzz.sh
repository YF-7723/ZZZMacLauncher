#!/bin/bash
# 绝区零 macOS 启动器（不修改游戏本体）
# 用法: launch-zzz.sh [--mode dxmt|d3dmetal] [--hud 0|1] [--no-kill] [-- 额外游戏参数]
#   dxmt     : Wine 11.0 + DXMT（D3D11，稳定，默认）
#   d3dmetal : Wine 11.20 + GPTK D3DMetal（DX12，实验性；本项目验证到反作弊不兼容，见 docs/EXPERIMENTS.md）
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

MODE="dxmt"
HUD="1"
DO_KILL=1
EXTRA_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --hud)  HUD="$2"; shift 2 ;;
    --no-kill) DO_KILL=0; shift ;;
    --) shift; EXTRA_ARGS=("$@"); break ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done
case "$MODE" in dxmt|d3dmetal) ;; *) die "未知模式: ${MODE}（可选 dxmt / d3dmetal）" ;; esac

mkdir -p "$LOG_DIR"
# 同时输出到终端与日志文件（关闭终端不影响游戏）
exec > >(tee -a "$LAUNCHER_LOG") 2>&1

log "=========== 启动绝区零 mode=$MODE ==========="
log "Yaagl 数据目录: $SUPPORT_DIR"
check_macos
check_game
check_support

if [ "$MODE" = "d3dmetal" ]; then
  warn "D3DMetal/DX12 为实验模式：可进入标题界面，但进入游戏世界时可能触发反作弊异常崩溃"
  warn "详见 docs/EXPERIMENTS.md，建议使用默认 dxmt 模式"
fi

# 1) 清理残留 Wine 进程
if [ "$DO_KILL" = "1" ]; then
  kill_wine_processes
fi

# 2) 确保运行时（如需安装会从快照恢复）
ensure_runtime "$MODE"

# 3) 额外注入一次 WDF（防止运行时被外部程序覆盖）
inject_wdf

# 4) 临时移走游戏自带 vulkan-1.dll（退出时自动还原）
move_vulkan_away
restore_all() {
  wineserver_kill
  restore_vulkan
  log "已还原启动补丁"
}
trap restore_all EXIT

# 5) 组装参数与环境
WIN_GAME="Z:$(printf '%s' "$GAME_EXE" | sed 's|/|\\|g')"
ENVS=(WINEPREFIX="$WINE_PREFIX")
ARGS=()

if [ "$MODE" = "dxmt" ]; then
  ENVS+=(WINEMSYNC=1 WINE_ENABLE_TIMEOUT_FIX=1)
else
  ARGS+=(-use-d3d12)
fi
ENVS+=(MTL_HUD_ENABLED="$HUD")
ENVS+=(GST_PLUGIN_FEATURE_RANK="atdec:MAX,avdec_h264:MAX")
if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
  ARGS+=("${EXTRA_ARGS[@]}")
fi

log "启动游戏（prefix=${WINE_PREFIX}）..."
log "可关闭本终端窗口，不影响游戏运行"
cd "$GAME_DIR" || die "无法进入游戏目录"
env "${ENVS[@]}" "$WINE_BIN" 'C:\windows\system32\steam.exe' "$WIN_GAME" ${ARGS[@]+"${ARGS[@]}"}
RC=$?
log "游戏进程退出 code=$RC"
exit 0
