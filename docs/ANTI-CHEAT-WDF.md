# 反作弊 WDF 兼容：原理、来源与风险

## 一、为什么需要它

《绝区零》PC 端启动时会加载反作弊（HoYoProtect）。在 Windows 上它的加载流程是：

```
游戏客户端 → HoYoProtect 用户态组件（MHYPBase.dll）
          → ZwLoadDriver("HoYoKProtect.sys")     ← 加载内核驱动
          → 驱动依赖 Windows 驱动框架 WDF（WDFLDR.SYS / WDF01000.SYS）
```

Wine 默认**没有实现** WDF（Windows Driver Framework）的两个框架模块，于是：

```
err:ntoskrnl:ZwLoadDriver failed to create driver L"\\Registry\\Machine\\System\\CurrentControlSet\\Services\\HoYoKProtect"
Library WDFLDR.SYS not found
initDriver Failed: Error [4,1114,0]
```

游戏要么直接闪退，要么弹「绝区零图标 + 感叹号 + 进度条」的报错框。

## 二、解决办法

把 Wine 构建中**已经实现 WDF 的 PE 模块**（`wdfldr.sys`、`wdf01000.sys`）放进 Wine 运行时的
`lib/wine/x86_64-windows/` 目录，让 `ZwLoadDriver` 能解析到依赖模块。

- 本项目使用的模块来自 **Dawn Winery / dwproton 11.0-15**（一个包含 WDF 实现的 Wine 兼容层构建）；
- 文件哈希：
  - `wdfldr.sys` sha256 `a5e2323779e9fe3548a6ae4ee49176afb8ef99d7614dfb0d093eebc58ab4050c`
  - `wdf01000.sys` sha256 `00fda3dd1f61704c366f47300d82b6eb845cc6f900028dacbf6d856e259fa49a`
- 许可证：LGPL-2.1-or-later（Wine），详见 `third_party/wdf/NOTICE.md`；
- 也可以从任意包含这两个模块的 Wine 构建自行提取：`scripts/install-wdf.sh --from-wine <wine根目录>`。

注入位置：

```
~/Library/Application Support/Yaagl ZZZ/wine/lib/wine/x86_64-windows/
├── wdfldr.sys
└── wdf01000.sys
```

以及运行时快照与 `wdf-fix/` 备份。

## 三、它做了什么 / 没做什么

| 做了 | 没做 |
|---|---|
| 补齐 Wine 缺失的 Windows 内核驱动框架 | 不修改游戏本体任何文件 |
| 让官方反作弊驱动能完成 `ZwLoadDriver` 初始化 | 不注入游戏进程、不 hook 游戏 |
| 让游戏在 Wine 下能够启动并登录 | 不绕过反作弊的校验逻辑（校验仍由官方组件执行） |

等价类比：在 Wine 里补上 Windows 本来就有的系统组件，而不是攻击反作弊。

## 四、风险提示（必读）

1. **ToS 风险**：使用非官方运行方式可能违反游戏服务条款，官方可能视为异常环境。
   本项目只解决「缺组件导致无法启动」，但**不保证账号安全**，使用者自行承担风险。
2. **稳定性风险**：反作弊驱动的某些深层检查仍可能失败，表现为随机闪退/报错；
   出现后运行 `scripts/restore-wdf.sh` 并重启游戏。
3. **失效风险**：游戏更新后反作弊可能升级（新驱动/新校验），WDF 注入可能再次失效；
   届时先尝试更新 Wine 运行时，或等待社区方案。
4. **不要**把该运行时与其他修改游戏文件的工具混用；不要用修改内存/注入类工具。

## 五、验证是否生效

1. 正常启动到登录/标题界面 → WDF 初始化成功；
2. 检查游戏目录 `driverError.log`：若 mtime 停留在旧时间、内容没有新增 `initDriver Failed`，说明正常；
3. 若出现 `WDFLDR.SYS not found` 或 `initDriver Failed`：
   ```bash
   bash scripts/restore-wdf.sh
   ```
4. 若 Yaagl 更新/重装了 Wine（`wine/` 目录被替换），WDF 模块会丢失，必须重新注入。

## 六、历史记录

| 日期 | 事件 |
|---|---|
| 2026-10-22 | 首次通过注入 dwproton 11.0-15 的 WDF 模块解决反作弊闪退，游戏可正常登录/游玩 |
| 2026-10-22 | 游戏 3.2 → 3.3 手动增量更新后，WDF 仍生效 |
| 2026-10-23 | 验证 DX12/D3DMetal 方案时反作弊在进世界时崩溃（见 EXPERIMENTS.md），回退 DXMT 后恢复稳定 |
