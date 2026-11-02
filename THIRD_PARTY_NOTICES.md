# 第三方组件与声明

本项目自身代码（`scripts/`、文档）以 MIT 许可证发布，见 `LICENSE`。
以下第三方组件的许可证与归属独立于 MIT：

## 1. WDF 兼容模块（`third_party/wdf/`）

| 项目 | 说明 |
|---|---|
| 文件 | `wdfldr.sys`、`wdf01000.sys` |
| 来源 | Dawn Winery / dwproton 11.0-15（基于 Wine） |
| 许可证 | LGPL-2.1-or-later |
| 许可文本 | `third_party/wdf/LICENSE.LGPL-2.1` |
| 源码 | <https://github.com/dawn-winery/dwproton-mirror> |
| 详情 | `third_party/wdf/NOTICE.md` |

## 2. Yaagl ZZZ（未随仓库分发）

- 项目：<https://github.com/yaagl/yet-another-anime-game-launcher>
- 用途：下载/更新《绝区零》Windows 客户端、提供 Wine 运行时与启动器壳。
- 本项目不包含 Yaagl 的任何文件，仅在运行时读取其数据目录。

## 3. Wine / DXMT（未随仓库分发）

- Wine：<https://www.winehq.org/>（LGPL-2.1-or-later）
- DXMT：<https://github.com/3Shain/dxmt>（MIT）
- 本项目不包含 Wine 运行时（体积 2GB+），由 Yaagl 下载安装后由 `scripts/setup.sh` 快照保存。

## 4. metalperftrace

- macOS 系统自带工具（macOS 26+），仅用于性能测量，不随仓库分发。

## 5. 《绝区零》游戏

- 游戏本体、客户端文件、品牌与商标归 miHoYo / 上海米哈游影铁科技有限公司所有。
- 本项目不包含、不修改游戏本体文件。
