# 可复现性能基准（metalperftrace）

macOS 26 及以上自带 `/usr/bin/metalperftrace`，可以直接读取 Metal 层的帧统计，
**无需截图、无需辅助功能权限**，特别适合在 Wine 环境下量化性能。

## 一、快速开始

```bash
# 自动流程：启动游戏 -> 等标题界面 -> 采集 60 秒 -> 输出报告
bash scripts/bench/bench_title.sh --mode dxmt --seconds 60 --label dxmt-baseline

# 输出：
#   bench-out/dxmt-baseline/launch.log    启动日志
#   bench-out/dxmt-baseline/trace/*.atrc  Metal trace
#   bench-out/dxmt-baseline/overview.txt  metalperftrace overview
```

## 二、手动测量

```bash
# 1) 先用启动器启动游戏，等进入标题界面

# 2) 采集最近 60 秒
metalperftrace collect --last 60s /tmp/zzz-trace

# 3) 查看汇总
metalperftrace overview /tmp/zzz-trace/MetalPerfTrace_*.atrc

# 4) JSON 输出（便于脚本解析）
metalperftrace overview --json /tmp/zzz-trace/MetalPerfTrace_*.atrc

# 5) 解析关键指标（一行一屏）
python3 scripts/bench/parse_metalperftrace.py /tmp/zzz-trace
```

## 三、关键指标解读

| 指标 | 含义 | 说明 |
|---|---|---|
| `Presented Frame Stats.FPS` | 呈现帧率 | 受垂直同步影响；关闭垂直同步才能反映真实上限 |
| `Frame-On-Glass Interval Stats` | 帧时间（avg/std/min/max） | **标准差越大越卡顿**，是比平均帧率更重要的指标 |
| `On-GPU Walltime Stats` | GPU 实际渲染耗时 | 若远小于帧时间，说明瓶颈不在 GPU |
| `End-to-end Walltime Stats (CPU)` | CPU 从开始编码到提交呈现 | Wine 转译开销主要看这里 |
| `Resource Usage.Physical Footprint` | 进程内存 | 16GB 机器要重点关注 |
| `Resource Usage.Metal Device Allocated Size` | Metal 显存 | |
| `Shader Compiler.Total Shader Compilation Time` | 着色器编译耗时 | DX12 模式首次启动会很长；DXMT/D3D11 通常为 0 |

## 四、本机基线（M1 Pro / 16GB / macOS 27）

标题界面，垂直同步开启（锁 ~30 帧）：

| 项目 | DXMT（Wine 11.0） | D3DMetal DX12（Wine 11.20，实验） |
|---|---|---|
| FPS | 28.0~28.2 | 29.2 |
| 帧时间 avg | 35.5~37.9 ms | 33.8 ms |
| 帧时间 std | 20.8~38.8 ms | 6.5 ms（缓存后） |
| GPU 时间 | 7.8~15.9 ms | 15.1 ms |
| CPU 提交 | 5.88 ms | 33.7 ms |
| 内存 | 2.8 GB | 5.2 GB |
| Metal 显存 | 0.55 GB | 1.0 GB |
| 着色器编译 | 0 | 64~98 s（首次） |

游戏内（玩家实测，高画质）：主城 30~40 帧、战斗 <30 帧；内存 ~10GB、Metal 显存 ~3GB、
GPU 时间 ~10ms。→ 瓶颈在 CPU 转译与内存，不在 GPU。

## 五、对比与回归

```bash
# 两次 trace 直接对比（metalperftrace 自带）
metalperftrace compare trace1.atrc trace2.atrc
```

修改设置/运行时后，建议至少重复 3 次取中位数，并保持：
- 同一场景（标题界面或同一主城位置）
- 同一垂直同步/帧率上限设置
- 后台程序一致（关闭浏览器、聊天软件等）

## 六、注意事项

- `metalperftrace collect --last N` 需要系统在 **最近 N 秒**内已有该进程的 Metal 活动，
  所以要先让游戏运行起来再采集；
- Wine 进程的渲染层名字可能是 `CAMetalLayer: WineMetalView` 或 `WineMetalLayer: WineMetalView`，
  解析脚本已同时兼容这两种命名；
- 若 trace 中找不到渲染层，检查游戏是否真的在渲染（窗口是否被遮挡/最小化）；
- 后台运行 DeepSeek Harness、浏览器、Steam++ 等会明显影响结果，对比时请保持一致。
