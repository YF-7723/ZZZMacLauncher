#!/usr/bin/env python3
"""解析 metalperftrace overview --json 输出，打印一屏关键指标。

用法:
    parse_metalperftrace.py <trace文件.atrc 或 含 .atrc 的目录>
"""
import glob
import json
import os
import subprocess
import sys


def find_trace(path):
    if os.path.isdir(path):
        files = sorted(glob.glob(os.path.join(path, "**", "*.atrc"), recursive=True))
        return files[0] if files else None
    return path


def overview(trace):
    try:
        out = subprocess.check_output(
            ["metalperftrace", "overview", "--json", trace],
            stderr=subprocess.DEVNULL,
        )
        return json.loads(out)
    except Exception:
        return None


def pick_layer(data):
    fallback = None
    for proc in data or []:
        for layer in proc.get("Layers") or []:
            name = (layer.get("Configuration") or {}).get("Name") or ""
            if "CAMetalLayer" in name or "WineMetal" in name or "MetalView" in name:
                return proc, layer
            stats = layer.get("Total Session Stats") or {}
            if fallback is None and stats.get("Presented Frame Stats"):
                fallback = (proc, layer)
    return fallback


def num(value, default=None):
    if isinstance(value, (int, float)):
        return value
    return default


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    trace = find_trace(sys.argv[1])
    if not trace:
        print("未找到 .atrc 文件")
        sys.exit(1)

    data = overview(trace)
    picked = pick_layer(data)
    if not picked:
        print("trace 中未找到渲染层")
        sys.exit(1)
    proc, layer = picked

    stats = layer.get("Total Session Stats") or {}
    frames = stats.get("Presented Frame Stats") or {}
    interval = stats.get("Frame-On-Glass Interval Stats") or {}
    gpu = frames.get("On-GPU Walltime Stats") or {}
    cpu = frames.get("End-to-end Walltime Stats (CPU)") or {}
    resource = proc.get("Resource Usage") or {}

    def f(value, digits=2):
        return f"{value:.{digits}f}" if isinstance(value, (int, float)) else "?"

    print(f"trace      : {os.path.basename(trace)}")
    print(f"FPS        : {f(num(frames.get('FPS')), 1)}")
    print(f"帧数       : {frames.get('Frame Count')}")
    print(f"帧时间     : {f(num(interval.get('Average (ms)')))} ms "
          f"(±{f(num(interval.get('StdDev (ms)')))} ms, max {f(num(interval.get('Max (ms)')))} ms)")
    print(f"GPU 时间   : {f(num(gpu.get('Average (ms)')))} ms")
    print(f"CPU 提交   : {f(num(cpu.get('Average (ms)')))} ms")
    print(f"内存       : {f(num(resource.get('Physical Footprint (MiB)')), 0)} MiB")
    print(f"Metal 显存 : {f(num(resource.get('Metal Device Allocated Size (MiB)')), 0)} MiB")
    shader = (frames.get("Shader Compiler") or {}).get("Total Shader Compilation Time")
    if shader:
        print(f"着色器编译 : {f(shader, 1)} s")


if __name__ == "__main__":
    main()
