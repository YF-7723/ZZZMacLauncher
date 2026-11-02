#!/bin/bash
# 一键安装/更新：快照 DXMT 运行时、注入 WDF 模块、生成桌面启动器
# 用法: bash scripts/setup.sh [选项]
#   --game-dir DIR     游戏目录（默认 ~/Games）
#   --support-dir DIR  Yaagl 数据目录（默认 ~/Library/Application Support/Yaagl ZZZ）
#   --force            强制重新快照（覆盖已有运行时备份）
#   --no-desktop       不创建桌面启动器
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

FORCE=0
NO_DESKTOP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --game-dir)    GAME_DIR="$2"; GAME_EXE="$GAME_DIR/ZenlessZoneZero.exe"; GAME_DATA="$GAME_DIR/ZenlessZoneZero_Data"; shift 2 ;;
    --support-dir) SUPPORT_DIR="$2"; WINE_PREFIX="$SUPPORT_DIR/wineprefix"; RUNTIMES_DIR="$SUPPORT_DIR/perf-runtimes"; WDF_DIR="$SUPPORT_DIR/wdf-fix"; WINE_BIN="$SUPPORT_DIR/wine/bin/wine"; shift 2 ;;
    --force)       FORCE=1; shift ;;
    --no-desktop)  NO_DESKTOP=1; shift ;;
    -h|--help)     sed -n '2,10p' "$0"; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

echo "=============================================="
echo " 绝区零 macOS 性能工具箱 · 安装程序"
echo "=============================================="
log "Yaagl 数据目录: $SUPPORT_DIR"
log "游戏目录:      $GAME_DIR"
log "Wine 前缀:     $WINE_PREFIX"

check_macos
check_game
check_support

# ---------- 1. 检查当前 Wine 运行时 ----------
CUR_VERSION="$(wine_version)"
if [ -z "$CUR_VERSION" ]; then
  die "未找到 Wine 运行时（${WINE_BIN}）。请先安装 Yaagl ZZZ，并在其设置中安装/启动一次游戏。"
fi
log "当前 Wine 版本: wine-$CUR_VERSION"
if [ "$CUR_VERSION" != "11.0" ] && [ "$CUR_VERSION" != "11.20" ]; then
  warn "当前 Wine 版本为 ${CUR_VERSION}，本项目仅验证过 11.0（DXMT）与 11.20（D3DMetal 实验）"
fi

# ---------- 2. 准备目录 ----------
mkdir -p "$RUNTIMES_DIR" "$WDF_DIR" "$LOG_DIR"

# ---------- 3. 注入 WDF 模块（反作弊驱动兼容） ----------
log "注入 WDF 兼容模块 ..."
install_wdf_to_dir "$SUPPORT_DIR/wine"
log "WDF 模块已写入: $SUPPORT_DIR/wine/lib/wine/x86_64-windows/"

# ---------- 4. 快照运行时 ----------
snapshot() {  # $1: 名称, $2: 目标目录
  local name="$1" dst="$2"
  if [ -d "$dst" ] && [ "$FORCE" = "0" ]; then
    log "运行时快照已存在，跳过: $dst"
    return 0
  fi
  log "快照运行时 -> $(basename "$dst") （约 1.4~2GB，请稍候）"
  rm -rf "$dst"
  cp -cR "$SUPPORT_DIR/wine" "$dst" 2>/dev/null || cp -R "$SUPPORT_DIR/wine" "$dst"
  log "快照完成: $dst"
}

if wine_is_dxmt; then
  snapshot "DXMT" "$RUNTIMES_DIR/wine-11.0-dxmt"
elif [ -d "$SUPPORT_DIR/wine-backup-11.0-dxmt" ]; then
  if [ ! -d "$RUNTIMES_DIR/wine-11.0-dxmt" ] || [ "$FORCE" = "1" ]; then
    log "从既有备份创建 DXMT 运行时快照 ..."
    rm -rf "$RUNTIMES_DIR/wine-11.0-dxmt"
    cp -cR "$SUPPORT_DIR/wine-backup-11.0-dxmt" "$RUNTIMES_DIR/wine-11.0-dxmt" 2>/dev/null \
      || cp -R "$SUPPORT_DIR/wine-backup-11.0-dxmt" "$RUNTIMES_DIR/wine-11.0-dxmt"
  fi
else
  warn "当前 Wine 不是 DXMT 运行时（无 winemetal.so），且未找到 wine-backup-11.0-dxmt"
  warn "请先在 Yaagl 中使用默认 Wine 11.0 DXMT 运行时启动一次游戏，再重新运行本脚本"
fi

# 若已有 D3DMetal 实验运行时，也一并快照（可选，见 docs/EXPERIMENTS.md）
if wine_is_d3dmetal "$CUR_VERSION"; then
  snapshot "D3DMetal" "$RUNTIMES_DIR/wine-11.20-d3dmetal"
elif [ -d "$SUPPORT_DIR/perf-runtimes/wine-11.20-d3dmetal" ] && [ ! -d "$RUNTIMES_DIR/wine-11.20-d3dmetal" ]; then
  cp -cR "$SUPPORT_DIR/perf-runtimes/wine-11.20-d3dmetal" "$RUNTIMES_DIR/wine-11.20-d3dmetal" 2>/dev/null || true
fi

# ---------- 5. 关闭 Wine Mono/Gecko 弹窗（游戏不需要 .NET） ----------
if [ -d "$WINE_PREFIX" ] && [ -x "$WINE_BIN" ]; then
  log "禁用 Wine Mono/Gecko 安装弹窗 ..."
  (
    export WINEPREFIX="$WINE_PREFIX"
    "$WINE_BIN" reg add "HKCU\\Software\\Wine\\DllOverrides" /v mscoree /d "" /f >/dev/null 2>&1 || true
    "$WINE_BIN" reg add "HKCU\\Software\\Wine\\DllOverrides" /v mshtml /d "" /f >/dev/null 2>&1 || true
    "$SUPPORT_DIR/wine/bin/wineserver" -k 2>/dev/null || true
  )
fi

# ---------- 6. 创建桌面启动器 ----------
if [ "$NO_DESKTOP" = "0" ]; then
  DESKTOP="$HOME/Desktop"
  mkdir -p "$DESKTOP"
  make_launcher() {  # $1: 文件名, $2: 模式
    local f="$DESKTOP/$1"
    cat > "$f" <<EOF
#!/bin/bash
exec "$REPO_ROOT/scripts/launch-zzz.sh" --mode $2
EOF
    chmod +x "$f"
    log "已创建桌面启动器: $f"
  }
  make_launcher "绝区零-启动.command" dxmt
  if [ -d "$RUNTIMES_DIR/wine-11.20-d3dmetal" ]; then
    make_launcher "绝区零-启动(DX12实验-可能崩溃).command" d3dmetal
  fi
  cat > "$DESKTOP/绝区零-使用说明.txt" <<EOF
绝区零 macOS 启动说明
=====================
启动：双击「绝区零-启动.command」
日志：~/Library/Logs/ZZZ-launcher.log
卸载：bash "$REPO_ROOT/scripts/uninstall.sh"

游戏内建议设置：
  垂直同步 → 关闭；帧率上限 → 60；光线追踪 → 关闭
  画质 高/中；角色/特效/阴影 中；体积雾/AO/动态模糊/景深 关
想更高帧数：渲染精度 1.0 → 0.85

注意：不要删除 $SUPPORT_DIR/perf-runtimes 与 wdf-fix 目录
EOF
fi

# ---------- 7. 完成 ----------
echo
echo "=============================================="
log "安装完成 ✅"
echo "  -> 双击桌面「绝区零-启动.command」开始游戏"
echo "  -> 性能报告与原理：$(basename "$REPO_ROOT")/docs/"
echo "=============================================="
