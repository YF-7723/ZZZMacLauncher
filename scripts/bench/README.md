# 性能基准脚本

## bench_title.sh

自动完成：启动游戏 → 等待标题界面 → 采集 N 秒 Metal 数据 → 输出报告。

```bash
bash scripts/bench/bench_title.sh --mode dxmt --seconds 60 --label before
bash scripts/bench/bench_title.sh --mode dxmt --seconds 60 --label after-settings
```

输出目录 `bench-out/<label>/`：

| 文件 | 说明 |
|---|---|
| `launch.log` | 启动器日志 |
| `trace/*.atrc` | metalperftrace 采集数据，可用 `metalperftrace overview` 查看 |
| `overview.txt` | 文本汇总 |

## parse_metalperftrace.py

解析 `.atrc` 或包含 `.atrc` 的目录，输出 FPS、帧时间、GPU 时间、CPU 提交、内存、显存。

```bash
python3 scripts/bench/parse_metalperftrace.py bench-out/before/trace
```

## 对比

```bash
metalperftrace compare bench-out/before/trace/*.atrc bench-out/after/trace/*.atrc
```

## 注意事项

- 需要 macOS 26+（自带 `metalperftrace`）；
- 对比不同设置时，保持场景、垂直同步、帧率上限、后台程序一致；
- 建议重复 3 次取中位数；
- 标题界面被垂直同步锁 ~30 帧，重点看帧时间标准差/GPU 时间/内存，而不是 FPS。
