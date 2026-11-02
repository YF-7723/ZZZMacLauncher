# Changelog

## v1.0.2 — 2026-11-02

### 隐私
- 移除文档中的本机绝对路径与个人用户名（统一使用 `$HOME` / `<用户名>` 占位）
- git 提交历史作者邮箱改为 GitHub noreply（不暴露真实邮箱）

### 新增
- `scripts/verify.sh`：环境自检（系统 / 游戏 / Wine / WDF / 启动器 / 磁盘），带修复提示
- README 全面重写：三步开始、逐步安装流程（含预期输出与完成标志）、日常维护表、
  隐私与安全章节、文档地图、常见问题速查

### 改进
- 桌面启动器统一命名为「绝区零-启动.command」
- 安装完成后建议运行 `bash scripts/verify.sh` 复核

## v1.0.1 — 2026-11-02

### 新增
- `docs/GAME-UPDATE.md`：游戏版本手工更新完整指南（Yaagl 版本清单过期时，用官方增量包
  从 3.2.0 更新到 3.3.0 的完整流程：deletefiles 处理、hdiff 差分合并、md5 校验、语音包、
  更新后恢复 WDF）
- README 新增「相关项目与鸣谢」章节：Yaagl 项目链接（核心依赖）、Wine、DXMT、
  Dawn Winery/dwproton、metalperftrace、hdiffpatch 等项目与社区致谢
- README / TROUBLESHOOTING Q4 更新：区分「Yaagl 正常更新」与「Yaagl 清单过期需手工更新」两种情况

## v1.0.0 — 2026-11-02

首个可用版本（基于 2026-10-22/23 在 M1 Pro 16GB / macOS 27 上的实测环境整理）：

### 新增
- 反作弊 WDF 兼容模块注入（`wdfldr.sys` / `wdf01000.sys`，来源 dwproton 11.0-15）
- 一键安装脚本 `scripts/setup.sh`：检测环境、快照 DXMT 运行时、注入 WDF、禁用 Mono 弹窗、生成桌面启动器
- 启动器 `scripts/launch-zzz.sh`：自动清理残留、注入 WDF、临时移走 `vulkan-1.dll`（退出自动还原）、日志记录
- 运行时管理：`switch-runtime.sh`、`restore-wdf.sh`、`install-wdf.sh`、`uninstall.sh`
- 可复现性能基准：`scripts/bench/bench_title.sh` + `parse_metalperftrace.py`（macOS 26+ `metalperftrace`）
- 文档：完整运行方案、性能报告、基准方法、反作弊原理、实验记录、故障排查

### 实测结论（M1 Pro 16GB）
- 稳定方案：Wine 11.0 + DXMT（D3D11），反作弊正常，可长时间游玩
- 标题界面 28.0~28.2 FPS（垂直同步锁 30）；游戏内主城 30~40 帧、战斗 <30 帧
- 瓶颈：CPU 转译（约 3.9 核）+ 16GB 内存；GPU 未饱和
- DX12 + D3DMetal + MetalFX 插帧：渲染层可用但反作弊（MHYPBase）崩溃 → 不采用

### 已知问题
- 游戏内 60 帧满帧不可达（CPU 转译瓶颈）
- FSR 帧生成在反作弊存在时不可用
- Wine 运行时升级/被覆盖后需重新执行 `setup.sh` 或 `restore-wdf.sh`
