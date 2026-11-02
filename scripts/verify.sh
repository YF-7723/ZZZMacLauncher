#!/bin/bash
# 环境自检：安装前/出问题时运行，逐项检查并给出建议
# 用法: bash scripts/verify.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

PASS=0
FAIL=0
WARN=0
ok()   { printf '  ✅ %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  ❌ %s\n     -> %s\n' "$1" "${2:-}"; FAIL=$((FAIL+1)); }
warn() { printf '  ⚠️  %s\n     -> %s\n' "$1" "${2:-}"; WARN=$((WARN+1)); }
head_() { printf '\n[%s]\n' "$1"; }

echo "=============================================="
echo " 绝区零 macOS 工具箱 · 环境自检"
echo "=============================================="
echo "路径约定："
echo "  数据目录: $SUPPORT_DIR"
echo "  游戏目录: $GAME_DIR"
echo "  Wine 前缀: $WINE_PREFIX"

head_ "1. 系统"
if [ "$(uname -s)" = "Darwin" ]; then ok "macOS ($(sw_vers -productVersion 2>/dev/null || echo '?'))"; else bad "非 macOS" "本项目仅支持 macOS"; fi
if [ "$(uname -m)" = "arm64" ]; then ok "Apple Silicon (arm64)"; else bad "非 arm64 架构" "需要 Apple Silicon Mac"; fi
if command -v metalperftrace >/dev/null 2>&1; then ok "metalperftrace 可用（性能基准需要）"; else warn "未找到 metalperftrace" "需要 macOS 26+；不影响启动游戏，只影响基准脚本"; fi

head_ "2. 游戏"
if [ -f "$GAME_EXE" ]; then ok "游戏可执行文件存在"; else bad "未找到 $GAME_EXE" "安装 Yaagl 并下载游戏，或用 ZZZ_GAME_DIR 指定游戏目录"; fi
if [ -f "$GAME_DIR/config.ini" ]; then
  V=$(grep -E '^game_version=' "$GAME_DIR/config.ini" 2>/dev/null | cut -d= -f2)
  ok "游戏版本: ${V:-未知}"
else
  warn "未找到 config.ini" "游戏可能未完整安装"
fi
if [ -f "$GAME_DIR/version_info" ]; then
  ok "version_info: $(cat "$GAME_DIR/version_info" 2>/dev/null | head -c 40)"
else
  warn "未找到 version_info" "通常不影响运行"
fi

head_ "3. Yaagl / Wine"
if [ -d "$SUPPORT_DIR" ]; then ok "Yaagl 数据目录存在"; else bad "未找到 $SUPPORT_DIR" "先安装 Yaagl ZZZ 并至少启动一次"; fi
CUR_VER="$(wine_version)"
if [ -n "$CUR_VER" ]; then ok "Wine 运行时: wine-$CUR_VER"; else bad "未找到 Wine 运行时" "在 Yaagl 中安装/启动一次游戏"; fi
if wine_is_dxmt; then ok "当前为 DXMT 运行时（稳定方案）"; else warn "当前 Wine 不是 DXMT 运行时" "运行 bash scripts/switch-runtime.sh dxmt"; fi
if [ -f "$SUPPORT_DIR/wine/lib/wine/x86_64-windows/wdfldr.sys" ] && \
   [ -f "$SUPPORT_DIR/wine/lib/wine/x86_64-windows/wdf01000.sys" ]; then
  ok "WDF 兼容模块已注入（反作弊需要）"
else
  bad "缺少 WDF 兼容模块" "运行 bash scripts/restore-wdf.sh"
fi
if [ -d "$WINE_PREFIX" ]; then ok "Wine 前缀存在"; else warn "未找到 Wine 前缀" "首次启动时 Wine 会自动创建"; fi

head_ "4. 启动器与备份"
if [ -f "$HOME/Desktop/绝区零-启动.command" ] || [ -f "$HOME/Desktop/绝区零-启动(推荐).command" ]; then
  ok "桌面启动器存在"
else
  warn "桌面启动器不存在" "运行 bash install.sh 生成"
fi
if [ -d "$RUNTIMES_DIR/wine-11.0-dxmt" ]; then ok "DXMT 运行时快照存在（可回滚）"; else warn "缺少运行时快照" "运行 bash scripts/setup.sh"; fi
if [ -d "$WDF_DIR" ]; then ok "WDF 备份目录存在"; else warn "缺少 WDF 备份目录" "运行 bash scripts/setup.sh"; fi

head_ "5. 资源"
AVAIL=$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')
if [ -n "${AVAIL:-}" ] && [ "$AVAIL" -gt 10 ]; then ok "磁盘可用 ${AVAIL}GB"; else warn "磁盘可用空间可能不足（${AVAIL:-?}GB）" "运行时快照约需 2GB"; fi

echo
echo "=============================================="
printf '结果: %d 项通过, %d 项警告, %d 项失败\n' "$PASS" "$WARN" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "请按上面的 -> 提示处理，或查看 docs/TROUBLESHOOTING.md"
  exit 1
fi
echo "环境正常，可以开始游戏（bash run.sh 或双击桌面启动器）"
exit 0
