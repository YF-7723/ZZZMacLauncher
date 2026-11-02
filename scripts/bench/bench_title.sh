#!/bin/bash
# 标题界面性能基准：自动启动游戏 -> 等待标题界面 -> 采集 60 秒 -> 报告
# 用法: bench_title.sh [--mode dxmt|d3dmetal] [--seconds 60] [--label 名称]
# 说明: 使用 macOS 26+ 自带的 metalperftrace，无需截图/辅助功能权限
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../lib/common.sh
. "$REPO_ROOT/scripts/lib/common.sh"

MODE="dxmt"
SECONDS_TO_MEASURE=60
LABEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)    MODE="$2"; shift 2 ;;
    --seconds) SECONDS_TO_MEASURE="$2"; shift 2 ;;
    --label)   LABEL="$2"; shift 2 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done
[ -n "$LABEL" ] || LABEL="${MODE}_$(date +%H%M%S)"
command -v metalperftrace >/dev/null 2>&1 || die "未找到 metalperftrace（需要 macOS 26+）"

check_macos
check_game
check_support

OUT_ROOT="$REPO_ROOT/bench-out"
OUT="$OUT_ROOT/$LABEL"
mkdir -p "$OUT"
PLAYER_LOG="$WINE_PREFIX/drive_c/users/$(whoami)/AppData/LocalLow/miHoYo/绝区零/Player.log"

log "启动游戏（mode=${MODE}）..."
touch "$OUT/launch.stamp"
nohup "$REPO_ROOT/scripts/launch-zzz.sh" --mode "$MODE" > "$OUT/launch.log" 2>&1 &
disown

ok=0
for i in $(seq 1 80); do
  sleep 5
  if grep -q "Login.SuccessTip" "$PLAYER_LOG" 2>/dev/null && [ "$PLAYER_LOG" -nt "$OUT/launch.stamp" ]; then
    ok=1; break
  fi
  if ! pgrep -f "ZenlessZoneZero" >/dev/null 2>&1 && [ "$i" -ge 12 ]; then
    log "未检测到游戏进程运行"; break
  fi
done
if [ "$ok" != "1" ]; then
  log "未能在超时时间内到达标题界面，请查看 $OUT/launch.log"
  kill_wine_processes
  exit 1
fi
log "已到达标题界面（t=$((i*5))s），等待 $(($SECONDS_TO_MEASURE)) 秒后采集 ..."
sleep "$SECONDS_TO_MEASURE"

log "采集最近 ${SECONDS_TO_MEASURE}s 的 Metal 性能数据 ..."
metalperftrace collect --last "${SECONDS_TO_MEASURE}s" "$OUT/trace" >/dev/null 2>&1
TRACE="$(find "$OUT/trace" -name '*.atrc' | head -1)"
if [ -n "$TRACE" ]; then
  metalperftrace overview "$TRACE" > "$OUT/overview.txt" 2>&1
  log "结果已保存: $OUT/overview.txt"
  sed -n '1,20p' "$OUT/overview.txt"
  python3 "$REPO_ROOT/scripts/bench/parse_metalperftrace.py" "$TRACE" 2>/dev/null || true
fi

log "结束游戏并清理 ..."
pkill -9 -f "ZenlessZoneZero" 2>/dev/null || true
wineserver_kill
log "完成。输出目录: $OUT"
