# ZZZMacLauncher

> 在 **Apple Silicon Mac** 上通过 **Yaagl + Wine** 稳定运行《绝区零》Windows 客户端的
> **完整运行方案 + 性能优化工具箱**。游戏本体零修改。

实测机型：MacBook Pro 14"（M1 Pro，8 核 6P+2E / 14 核 GPU / 16GB），macOS 27。
其他 Apple Silicon Mac 同样适用（帧数会因芯片不同而变化）。

> 文档中出现的 `$HOME`、`~`、`<用户名>` 均为占位符，项目本身不包含任何个人路径或账号信息。

---

## 一、它能解决什么

在 Mac 上跑《绝区零》Windows 版通常会依次卡在这几层，本项目逐层处理：

| 问题 | 现象 | 本项目方案 |
|---|---|---|
| **反作弊驱动无法加载** | `initDriver Failed: Error [4,1114,0]`、启动闪退、报 `WDFLDR.SYS not found` | 注入 Wine 内建的 WDF 兼容模块（来自 Dawn Winery/dwproton 构建，LGPL-2.1） |
| **启动流程脆弱** | 每次开 Yaagl 提心吊胆，被覆盖后不知道怎么恢复 | 一键启动器 + 运行时快照/切换 + 一键恢复脚本，全部可逆 |
| **性能问题无法量化** | 只知道卡，不知道瓶颈在哪 | `metalperftrace` 可复现基准（FPS / 帧时间 / GPU / 内存 / 显存） |
| **设置全凭感觉** | 垂直同步锁帧、画质项吃 CPU、16GB 内存吃紧 | 实测数据 + 游戏内设置对照表（见第六节） |
| **想用 DX12/FSR 插帧** | 网上教程说可以 | 已实测：渲染层可行但**反作弊不兼容**，本项目不启用（见第九节） |

---

## 二、三步开始（TL;DR）

```bash
# 1) 克隆
git clone https://github.com/YF-7723/ZZZMacLauncher.git
cd ZZZMacLauncher

# 2) 安装（自动检测环境、注入 WDF、备份运行时、创建桌面启动器）
bash install.sh

# 3) 启动（也可以双击桌面「绝区零-启动.command」）
bash run.sh
```

> 首次启动会初始化/升级 Wine 前缀，约 1~2 分钟属正常。
> 看到登录界面 / 标题界面 = 成功。

---

## 三、前置条件

### 必须满足

| 条件 | 说明 / 检查方法 |
|---|---|
| Apple Silicon Mac | `uname -m` 输出 `arm64` |
| macOS 26+ | `sw_vers -productVersion`；26+ 才带 `metalperftrace`（基准脚本需要） |
| Rosetta 2 | 一般早已安装；未安装时运行 `softwareupdate --install-rosetta` |
| 已安装 **Yaagl ZZZ** | 用于下载/更新游戏、提供 Wine 运行时 |
| 游戏已下载并至少启动过一次 | 确保 Wine 11.0 DXMT 运行时已就位（Yaagl 默认运行时） |

### 建议

- 磁盘剩余 ≥ 10GB（运行时快照约 2GB）
- 插电使用；关闭低电量模式
- 关闭不必要的大内存程序（浏览器等，16GB 机器尤其重要）

### 一键自检

```bash
bash scripts/verify.sh
```

自检会逐项检查：系统/游戏/版本/运行时/WDF 模块/桌面启动器/磁盘空间，
每一项都会给出 ✅ 或「怎么修」的提示。**安装前跑一次，出问题也先跑它。**

---

## 四、安装流程（预期输出与完成标志）

### Step 1：克隆仓库

```bash
git clone https://github.com/YF-7723/ZZZMacLauncher.git
cd ZZZMacLauncher
```

### Step 2：运行安装

```bash
bash install.sh
```

它会自动完成（全部幂等，可重复运行）：

| 步骤 | 内容 | 完成标志 |
|---|---|---|
| 1 | 检测游戏目录 / Yaagl 数据目录 / Wine 前缀 | `Yaagl 数据目录: ...` 等输出 |
| 2 | 注入 WDF 兼容模块 | `WDF 模块已写入: ...` |
| 3 | 快照当前 Wine 11.0 DXMT 运行时（可回滚，约 2GB） | `快照完成: ...wine-11.0-dxmt` |
| 4 | 禁用 Wine Mono/Gecko 弹窗（游戏不需要 .NET） | 无输出即成功 |
| 5 | 生成桌面启动器 | `已创建桌面启动器: .../绝区零-启动.command` |
| 6 | 打印总结 | `安装完成 ✅` |

> **游戏不在默认目录？**
> `bash install.sh --game-dir /你的/游戏目录`
> （或设置环境变量 `ZZZ_GAME_DIR`）

### Step 3：启动

```bash
bash run.sh
# 或双击桌面「绝区零-启动.command」
```

### Step 4：验证成功

| 检查项 | 成功标志 |
|---|---|
| 登录界面 | 能正常显示登录/标题界面 |
| 游戏版本 | 游戏内显示 3.3.0+（或当前最新） |
| 反作弊 | 不再闪退；`游戏目录/driverError.log` 没有新的 `initDriver Failed` |
| 启动日志 | `~/Library/Logs/ZZZ-launcher.log` 无致命错误 |

### 如果失败（按顺序处理）

```
1. bash scripts/verify.sh          # 先自检，按提示修
2. bash scripts/restore-wdf.sh     # 反作弊相关错误
3. 看日志: ~/Library/Logs/ZZZ-launcher.log
4. 看文档: docs/TROUBLESHOOTING.md
5. 还不行：把日志与 docs/TROUBLESHOOTING.md 对照排查
```

---

## 五、日常使用

| 场景 | 操作 |
|---|---|
| 正常启动 | 双击桌面「绝区零-启动.command」或 `bash run.sh` |
| 启动日志 | `~/Library/Logs/ZZZ-launcher.log` |
| 环境检查 | `bash scripts/verify.sh` |
| **游戏更新** | 常规情况：Yaagl 点「更新」（更新后跑 `restore-wdf.sh`）；<br>Yaagl 清单过期时：见 [`docs/GAME-UPDATE.md`](docs/GAME-UPDATE.md) |
| 反作弊报 WDF 错误 | `bash scripts/restore-wdf.sh` |
| 切换运行时（不启动） | `bash scripts/switch-runtime.sh dxmt` |
| 卸载本项目（保留游戏） | `bash scripts/uninstall.sh` |
| 卸载并清理 2GB 快照 | `bash scripts/uninstall.sh --purge` |
| 恢复安装前的 Wine | `bash scripts/uninstall.sh --restore-wine` |

> ⚠️ 不要删除 `~/Library/Application Support/Yaagl ZZZ/perf-runtimes` 与 `wdf-fix` 目录，
> 它们是回滚与反作弊修复的关键备份。

---

## 六、推荐游戏内设置（实测）

`设置 → 画面` / `设置 → 画面 → 高级`：

| 设置 | 推荐值 | 说明 |
|---|---|---|
| 显示模式 | 全屏 | 跟随桌面分辨率 |
| **垂直同步** | **关闭** | 开启时锁 30/60 帧，最影响手感的一项 |
| 帧率上限 | 60（或无限） | 配合关垂直同步 |
| 画质预设 | 高（卡则中） | |
| 渲染精度 | 1.0（追帧数可 0.85） | 0.85 约 +10~15% 帧数，画质略软 |
| 抗锯齿 | TAA | |
| 全局光照 | 中 | Apple GPU 无硬件光追，高阶 GI 收益低 |
| 阴影精度 | 中 / 高 | 阴影是 CPU 开销大户 |
| 特效质量 | 中 | |
| 角色质量 | 中 / 高 | 16GB 内存建议中 |
| 光线追踪 | 关闭 | |
| 动态模糊 / 景深 | 关闭 | |
| 体积雾 / 环境光遮蔽 | 关 / 低 | |

预期：M1 Pro 16GB 主城约 40~55 帧、战斗约 30~45 帧。
CPU 转译是硬瓶颈，**60 帧满帧不现实**（详见 [`docs/PERFORMANCE-REPORT.md`](docs/PERFORMANCE-REPORT.md)）。

---

## 七、性能数据与基准

标题界面实测（垂直同步开启，锁 ~30 帧）：

| 方案 | FPS | 帧时间 | GPU 时间 | 内存 | Metal 显存 |
|---|---|---|---|---|---|
| Wine 11.0 + DXMT（本项目） | 28.0~28.2 | 35.5~37.9 ms | 7.8~15.9 ms | 2.8 GB | 0.55 GB |
| D3DMetal DX12（实验，反作弊不兼容） | 29.2 | 33.8 ms | 15.1 ms | 5.2 GB | 1.0 GB |

- 完整数据：[`docs/PERFORMANCE-REPORT.md`](docs/PERFORMANCE-REPORT.md)
- 基准方法：[`docs/BENCHMARK.md`](docs/BENCHMARK.md)
- 自测：

```bash
bash scripts/bench/bench_title.sh --mode dxmt --seconds 60 --label before
```

---

## 八、常见问题速查

| 现象 | 处理 |
|---|---|
| 启动闪退 / `initDriver Failed` | `bash scripts/restore-wdf.sh` |
| 弹出 **Wine Mono Installer** | 点 **Cancel**（游戏不需要 .NET；`install.sh` 已尝试永久禁用） |
| 提示「有新版本，请前往启动器更新」 | 先试 Yaagl「更新」；若 Yaagl 说已是最新 → 见 [`docs/GAME-UPDATE.md`](docs/GAME-UPDATE.md) |
| 启动很慢 / 黑屏 | 首次初始化 Wine 前缀，1~2 分钟正常；一直黑屏看日志 |
| 帧数低 / 卡顿 | 关垂直同步 → 降阴影/角色/特效 → 关后台程序（见第六节） |
| 内存不足 | 角色/特效质量降中；玩前重启 Mac；关闭浏览器等 |
| 桌面启动器丢了 | `bash install.sh` 重新生成 |
| `metalperftrace` 找不到 | 需要 macOS 26+ |
| 反作弊崩溃（图标+感叹号+进度条） | 切回稳定运行时：`switch-runtime.sh dxmt` + `restore-wdf.sh` |

全部排障指南：[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)

---

## 九、已知限制（重要）

1. **DX12 / FSR 帧生成不可用**：D3DMetal+MetalFX 方案在渲染层可行，但进入游戏世界时
   会被 HoYoProtect 反作弊判定异常（`MHYPBase.dll` 崩溃），为保护账号本项目不启用。
   详见 [`docs/EXPERIMENTS.md`](docs/EXPERIMENTS.md)。
2. **60 帧满帧不可达**：CPU（Rosetta + Wine 转译）是瓶颈，约占用 3.9 个核心。
3. 游戏更新/反作弊升级可能导致 WDF 方案失效，需要重新注入或等待社区更新。
4. 非官方运行方式存在账号风险，使用前请阅读第十二节。

---

## 十、项目结构

```
ZZZMacLauncher/
├── README.md                     ← 本文件（完整教程）
├── install.sh / run.sh           ← 便捷入口（安装 / 启动）
├── docs/
│   ├── PERFORMANCE-REPORT.md     ← 性能实测报告与结论
│   ├── BENCHMARK.md              ← 可复现性能基准方法
│   ├── EXPERIMENTS.md            ← Wine 运行时/图形层 A/B 实验记录（含 DX12 负结果）
│   ├── GAME-UPDATE.md            ← 游戏版本手工更新指南（Yaagl 清单过期时）
│   ├── ANTI-CHEAT-WDF.md         ← 反作弊 WDF 兼容原理、风险与验证
│   ├── TROUBLESHOOTING.md        ← 常见问题排查
│   └── perf-data/                ← 实测 metalperftrace 数据样例
├── scripts/
│   ├── setup.sh                  ← 安装/更新（install.sh 实际调用）
│   ├── launch-zzz.sh             ← 启动器（--mode dxmt|d3dmetal）
│   ├── verify.sh                 ← 环境自检
│   ├── switch-runtime.sh         ← 切换运行时
│   ├── restore-wdf.sh            ← 重新注入 WDF 模块
│   ├── install-wdf.sh            ← 从仓库/dwproton/本地 Wine 获取 WDF
│   ├── uninstall.sh              ← 卸载（可 --purge / --restore-wine）
│   ├── lib/common.sh             ← 公共函数（路径探测等）
│   └── bench/                    ← 性能基准脚本
└── third_party/wdf/              ← WDF 模块（LGPL-2.1，来源与哈希见 NOTICE）
```

运行期目录（不入库，全部在 Yaagl 数据目录下）：

```
~/Library/Application Support/Yaagl ZZZ/
├── wine/            # 当前 Wine 运行时（脚本管理）
├── wineprefix/      # Wine 前缀（存档/设置）
├── wdf-fix/         # WDF 模块备份
└── perf-runtimes/   # 运行时快照（wine-11.0-dxmt 等）
```

---

## 十一、工作原理

```
《绝区零》Windows 客户端 (x86_64 PE)
        │
        ▼
Wine 11.0（Yaagl 版，含 DXMT）   ← WDF 兼容模块、msync、Vulkan 补丁
        │  Rosetta 2（x86_64 → arm64）
        ▼
   Metal / macOS 图形栈
```

| 组件 | 作用 |
|---|---|
| WDF 兼容模块 | 补齐 Wine 缺失的 Windows 内核驱动框架，让官方反作弊驱动能加载 |
| DXMT | 基于 Metal 的 D3D10/11 翻译层（D3D11→Metal），比 WineD3D 快很多 |
| msync | Wine 快速同步原语，降低 Apple Silicon 线程同步开销 |
| Vulkan 补丁 | 启动时临时移走游戏自带 `vulkan-1.dll`（与 Wine 冲突），退出自动还原 |
| 运行时快照 | 整体备份可用的 Wine 运行时，出问题一键回滚，不怕 Yaagl 覆盖 |

本项目**不修改**游戏本体文件、不注入游戏进程、不绕过游戏校验逻辑。
详见 [`docs/ANTI-CHEAT-WDF.md`](docs/ANTI-CHEAT-WDF.md)。

---

## 十二、隐私与安全

- 仓库内容不含任何个人路径、本机用户名、账号或密钥；
- 脚本运行时只操作 Yaagl 数据目录 / Wine 前缀 / 游戏目录的启动补丁（Vulkan DLL 临时移走），
  不收集、不上传任何数据；
- 文档统一使用 `$HOME`、`<用户名>` 等占位符；
- 使用非官方方式运行游戏可能违反游戏服务条款，存在账号风险，请自行评估；
- 本项目按现状提供，不提供任何担保。

---

## 十三、相关项目与鸣谢

### 核心依赖
- **[Yaagl（Yet Another Anime Game Launcher）](https://github.com/yaagl/yet-another-anime-game-launcher)**
  —— 负责《绝区零》Windows 客户端的下载、更新、Wine 运行时管理与启动器壳；
  本项目在它的运行产物之上做兼容修复与启动封装，没有 Yaagl 就没有这套方案。
- **[Wine](https://www.winehq.org/)** —— Windows API 兼容层（LGPL-2.1-or-later）。
- **[DXMT](https://github.com/3Shain/dxmt)** —— 基于 Metal 的 D3D10/11 翻译层，性能关键。
- **[Dawn Winery / dwproton](https://github.com/dawn-winery/dwproton-mirror)**
  —— 本项目注入的 WDF 兼容模块（`wdfldr.sys` / `wdf01000.sys`）来自其构建产物。

### 工具与参考
- **Apple `metalperftrace`**（macOS 26+ 自带）—— 可复现性能基准测量。
- **Apple Game Porting Toolkit / D3DMetal / MetalFX** —— DX12 实验所用（结论：反作弊不兼容，未采用）。
- **[hdiffpatch](https://github.com/sisong/hdiffpatch)** —— 游戏官方增量包差分合并所需。
- 社区中分享「Wine 下反作弊 WDF 兼容」「DX12+MetalFX 实验记录」的开发者与玩家。

### 特别感谢
- 感谢 **Yaagl** 项目作者与社区，让 Mac 用户能玩到这些 Windows 游戏；
- 感谢 Wine / DXMT / dwproton 的维护者与贡献者；
- 感谢所有公开分享 Wine 游戏兼容经验的玩家。

---

## 十四、许可证

- 项目代码：MIT（见 [`LICENSE`](LICENSE)）
- WDF 模块：Wine 项目构建产物，LGPL-2.1-or-later（见 [`third_party/wdf/NOTICE.md`](third_party/wdf/NOTICE.md)）
- 游戏本体、客户端文件、品牌与商标归 miHoYo / 上海米哈游影铁科技有限公司所有。
