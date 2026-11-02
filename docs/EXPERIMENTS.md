# 实验记录：Wine 运行时与图形层 A/B（DXMT vs D3DMetal DX12）

> 日期：2026-10-22 ~ 2026-10-23
> 机器：M1 Pro 8 核 / 14 核 GPU / 16GB / macOS 27.0.1
> 测量：`metalperftrace collect` + `overview --json`，标题界面停留 60 秒
> 注意：标题界面受游戏垂直同步影响被锁 ~30 帧，因此对比重点看**帧时间稳定性、GPU 时间、CPU 提交时间、内存**，而不是单纯的 FPS。

## 一、测试过的方案

| 编号 | Wine | 图形层 | 启动参数 | 预期 |
|---|---|---|---|---|
| A | 11.0（Yaagl 默认） | DXMT（D3D11） | 无 | 基线（玩家实际使用） |
| B | 11.8（上游） | DXMT（覆盖 DLL） | 无 | 更新 Wine 降低 CPU 开销 |
| C | 11.17（定制） | DXMT 覆盖 | 无 | 同上 + msync 调优 |
| D | 11.17（定制） | D3DMetal（D3D11） | 无 | Metal 原生 D3D11 路径 |
| E | 11.17（定制） | D3DMetal（D3D12） | `-use-d3d12` | 解锁 FSR 超分/帧生成 |
| F | 11.20 + GPTK 4.0b3 | D3DMetal（D3D12）+ MetalFX 桥接 | `-use-d3d12` | 社区最新：伪装 RTX 4060 + MetalFX 插帧 |

## 二、结果汇总

| 方案 | 能到标题 | 能进世界 | 标题 FPS | 帧时间 | GPU 时间 | 内存 | Metal 显存 | 结论 |
|---|---|---|---|---|---|---|---|---|
| A DXMT 11.0 | ✅ | ✅（反作弊正常） | 28.0~28.2 | 35.5~37.9ms | 7.8~15.9ms | 2.8GB | 0.55GB | **采用** |
| B DXMT 11.8 | 未测完 | — | — | — | — | — | — | 优先级低，未继续 |
| C DXMT 11.17 | 未测完 | — | — | — | — | — | — | 同上 |
| D D3DMetal DX11 | 预期可 | 未验证 | — | — | — | — | — | 无 FSR/FG 需求时无优势 |
| E D3DMetal DX12 | ✅ | ❌ 反作弊崩溃 | — | — | — | 5.2GB | 1.0GB | 不采用 |
| F 11.20 + MetalFX | ✅ | ❌ 反作弊崩溃 | 29.2 | 33.8ms | 15.1ms | 5.2GB | 1.0GB | 不采用（见第三节） |

## 三、方案 F（Wine 11.20 + D3DMetal + MetalFX）详细记录

这是唯一同时具备「DX12 + FSR 超分 + 帧生成」能力的方案。

### 3.1 它做了什么

社区运行时（dbc-hbin/wine-yaagl-d3dmetal，release `wine-11.20-gptk4.0b3-1`）的
`bin/wine` 包装脚本会：

```sh
export CX_ACTIVE_GRAPHICS_BACKEND=d3dmetal
export D3DM_MTL4=1
export D3DM_ENABLE_METALFX=1
export D3DM_SUPPORT_DXR=1
export WINEMSYNC=1
export D3DM_VENDOR_ID=0x10de
export D3DM_DEVICE_ID=0x2882
export D3DM_DEVICE_DESCRIPTION="NVIDIA GeForce RTX 4060"
# FSR 超分/帧生成 DLL 被重定向到内建实现（MetalFX 翻译）
export WINEDLLOVERRIDES=amd_fidelityfx_upscaler_dx12,amd_fidelityfx_framegeneration_dx12=b
```

游戏内日志可见：

```
Renderer: NVIDIA GeForce RTX 4060 (ID=0x2882)
[ffx] Upscaler Version: MetalFX (Yaagl FSR on GPTK4 beta3)
[ffx] FrameGen Version: Yaagl automatic frame generation (MetalFX or native FSR)
psowarmup: pipelineCachingSupported=1, D3D12_SHADER_CACHE_SUPPORT_AUTOMATIC_DISK_CACHE=8
```

即：伪装成 RTX 4060 解锁游戏的高级图形菜单，并把 FSR 的超分/帧生成调用
翻译到 **MetalFX**（含 MetalFX 帧插值）。

### 3.2 为什么最终放弃

- 标题界面完全正常（28~29 FPS，与 DXMT 相当），内存与显存占用明显更低
  （内存 5.2GB vs 7.7GB，Metal 显存 1.0GB vs 2.0GB），GPU 时间 15.1ms 也正常；
- **进入游戏世界加载时崩溃**：弹出「绝区零图标 + 感叹号 + 进度条」的
  HoYoProtect 反作弊报错框，随后闪退；
- 崩溃转储与日志显示异常发生在反作弊用户态组件 **`MHYPBase.dll`** 内部：

```
Z:\Users\...\MHYPBase.dll:MHYPBase.dll (00006FFFCD420000), size: 26796032, fileVersion: 1.0.1.1
0x00006FFFCECEDF18 (mhypbase)
0x00006FFFCECFE701 (mhypbase)
...
```

- 同时 SDK 日志出现设备指纹告警：

```
DeviceFPManager::CheckInvalidDeviceFpValue, invalid devicefp key is: MIHOYOSDK_GPU_NAME,
value is: NVIDIA GeForce RTX 4060
```

- Metal 驱动侧也有资源压力日志：`AGX: exceeded compiled variants footprint limit`
  （M1 的 Metal 编译变体预算被 RTXGI/光追着色器变体打到上限）。

### 3.3 尝试过的缓解措施

| 措施 | 结果 |
|---|---|
| 关闭 DXR 支持（`D3DM_SUPPORT_DXR=0`） | 反作弊仍然崩溃 |
| 清理伪造 GPU 指纹注册表残留 | 不影响崩溃 |
| 重试多次（PSO 缓存渐进） | 每次都在进世界时崩 |
| 回退 DXMT 11.0 | ✅ 完全稳定，验证可正常游玩 |

### 3.4 结论

在 HoYoProtect 启用且校验环境指纹的前提下，**D3DMetal/DX12 + 伪装 GPU 身份
无法与反作弊共存**。为保护账号，本项目不采用该方案，也不提供其自动安装脚本；
仅保留运行时快照供未来研究（`perf-runtimes/wine-11.20-d3dmetal/`，默认不启用）。

## 四、可复现命令

```bash
# 标题界面基准（稳定模式）
bash scripts/bench/bench_title.sh --mode dxmt --seconds 60 --label dxmt-baseline

# 查看 trace
metalperftrace overview bench-out/dxmt-baseline/trace/*.atrc
```

> 警告：`--mode d3dmetal` 仅用于研究目的，进入游戏世界会触发反作弊崩溃，
> 请不要在日常游玩时使用。
