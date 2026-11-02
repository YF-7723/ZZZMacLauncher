# 常见问题排查

> 先跑一次环境自检：`bash scripts/verify.sh`，多数问题它会直接告诉你原因和修复命令。

## 启动类

### Q1. 双击启动器后闪退，`driverError.log` 出现 `initDriver Failed: Error [4,1114,0]`

反作弊 WDF 模块没有生效（可能被 Yaagl 更新覆盖了）。

```bash
bash scripts/restore-wdf.sh
```

然后重新启动。若仍失败，检查：
- `~/Library/Application Support/Yaagl ZZZ/wine/lib/wine/x86_64-windows/wdfldr.sys` 是否存在；
- 当前 Wine 是否 11.0 DXMT 运行时（`wine --version`）；
- 是否运行了 `scripts/setup.sh`。

### Q2. 弹出「Wine Mono Installer / Wine Gecko Installer」

游戏不需要 .NET 或浏览器组件，直接点 **Cancel**。
`scripts/setup.sh` 已在 Wine 前缀里将 `mscoree` / `mshtml` 设为禁用，正常不会再弹。
若反复弹出，手动执行：

```bash
export WINEPREFIX="$HOME/Library/Application Support/Yaagl ZZZ/wineprefix"
"$HOME/Library/Application Support/Yaagl ZZZ/wine/bin/wine" reg add \
  'HKCU\Software\Wine\DllOverrides' /v mscoree /d '' /f
"$HOME/Library/Application Support/Yaagl ZZZ/wine/bin/wine" reg add \
  'HKCU\Software\Wine\DllOverrides' /v mshtml /d '' /f
```

### Q3. 启动很慢 / 黑屏一段时间

- 首次启动在初始化/升级 Wine 前缀，可能 1~2 分钟，属正常；
- 之后每次启动约 60~75 秒到标题界面（自动登录）；
- 若一直黑屏，看 `~/Library/Logs/ZZZ-launcher.log` 里的报错。

### Q4. 游戏提示「有新版本，请前往启动器更新」

**先看 Yaagl 是否有更新提示：**

- 有 → 打开 Yaagl **只点「更新」**（不要点开始游戏），更新完成后运行 `bash scripts/restore-wdf.sh`；
- 没有（Yaagl 显示「已是最新」但游戏仍提示更新）→ 说明 **Yaagl 内置版本清单过期**，
  需要按 [`docs/GAME-UPDATE.md`](GAME-UPDATE.md) 用官方增量包手工更新（含 hdiff 合并、
  deletefiles 处理、md5 校验等完整步骤）。

### Q5. 启动后窗口被其他窗口盖住/找不到

游戏以 Wine 窗口运行（非原生全屏），用 `Cmd+Tab` 或 Dock 切换；
不要最小化游戏窗口，会触发 macOS 遮挡节能导致帧数下降。

## 运行类

### Q6. 帧数低 / 卡顿

按顺序检查：

1. **关闭垂直同步**（游戏内 设置→画面），帧率上限 60；
2. 画质：阴影/角色/特效降为「中」，体积雾/AO/动态模糊/景深关闭；
3. 渲染精度 1.0 → 0.85（+10~15% 帧数）；
4. 关闭后台大程序：浏览器、DeepSeek Harness、Steam++、ToDesk、微信等；
5. 重启一次 Mac（尤其机器已连续运行多天、swap 占用高时）；
6. 确认插电、未开低电量模式。

### Q7. 内存不足/系统卡死

16GB 是硬限制。建议：
- 角色质量、特效质量降为「中」；
- 关闭浏览器等大内存程序；
- 不要同时开多个游戏/虚拟机；
- 玩之前重启一次 Mac。

### Q8. 帧数被锁 30 帧

垂直同步开启且游戏无法达到 60 帧时会锁 30 帧。关闭垂直同步即可解锁。

### Q9. Metal HUD 不显示

本项目启动器默认开启 `MTL_HUD_ENABLED=1`。若想看完整 HUD，可在启动器中加：

```bash
bash scripts/launch-zzz.sh --mode dxmt --hud 1
```

## 维护类

### Q10. Yaagl 更新后又出现闪退

```bash
bash scripts/setup.sh          # 重新注入 WDF、确认运行时快照
# 或
bash scripts/switch-runtime.sh dxmt
bash scripts/restore-wdf.sh
```

### Q11. 想恢复成安装本项目之前的状态

```bash
bash scripts/uninstall.sh --restore-wine
```

### Q12. 磁盘占用

- `perf-runtimes/` 快照约 2GB（Wine 运行时备份）；
- 不想要可 `bash scripts/uninstall.sh --purge`；
- 游戏本体约 78GB，在 `~/Games`。

## 反作弊崩溃类

### Q13. 进入游戏世界时弹「绝区零图标 + 感叹号 + 进度条」然后闪退

这是 HoYoProtect 反作弊报错，常见于：
- 使用了非默认运行时（例如 DX12/D3DMetal 实验模式）——本项目默认 **不启用**；
- WDF 模块被覆盖；
- 设备指纹/环境被判定异常。

处理：

```bash
bash scripts/switch-runtime.sh dxmt   # 回到稳定运行时
bash scripts/restore-wdf.sh
```

仍不行则重启 Mac 再试；避免反复触发，保护账号。

### Q14. 为什么不能用 DX12 + FSR 帧生成？

详见 `docs/EXPERIMENTS.md`：渲染层可用，但进世界时反作弊崩溃，已放弃。
