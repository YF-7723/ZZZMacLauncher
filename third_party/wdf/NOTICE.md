# WDF 兼容模块来源说明

本目录下的两个文件是 **Wine 项目的构建产物**，用于让 Windows 内核驱动
（绝区零的 HoYoProtect 反作弊驱动 `HoYoKProtect.sys`）在 Wine 下能够成功加载：

| 文件 | 大小 | SHA-256 |
|---|---|---|
| `wdfldr.sys` | 77,305 字节 | `a5e2323779e9fe3548a6ae4ee49176afb8ef99d7614dfb0d093eebc58ab4050c` |
| `wdf01000.sys` | 66,695 字节 | `00fda3dd1f61704c366f47300d82b6eb845cc6f900028dacbf6d856e259fa49a` |

## 来源

提取自 **Dawn Winery / dwproton 11.0-15**（一个基于 Wine 的兼容层构建，
其 PE 模块中包含 WDFLDR/WDF01000 的内建实现）：

- 源码仓库镜像：<https://github.com/dawn-winery/dwproton-mirror>
- 发布包（11.0-15）：
  <https://github.com/dawn-winery/dwproton-mirror/releases/tag/dwproton-11.0-15>
- SHA-512（发布包）：
  `ec8985d14b6492df3459f93a3d90278814d9be2fe618e1ccd76f72f732c797e639d7f33fdf801be28585d0855e73bdda27858552ce709ba05cf3f60a17d2e817`

提取方法（可复现）：

```bash
curl -L -o dwproton.tar.xz \
  https://github.com/dawn-winery/dwproton-mirror/releases/download/dwproton-11.0-15/dwproton-11.0-15-x86_64.tar.xz
shasum -a 512 dwproton.tar.xz   # 应与上面 SHA-512 一致
tar -xJf dwproton.tar.xz
find . -name 'wdfldr.sys' -o -name 'wdf01000.sys'
# 一般在 */lib/wine/x86_64-windows/ 下
```

也可以从任意包含这两个模块的 Wine 构建中提取：`scripts/install-wdf.sh --from-wine <wine根目录>`。

## 许可证

Wine 的 PE 模块以 **LGPL-2.1-or-later** 分发。本目录附带
`LICENSE.LGPL-2.1`。这些文件不属于本项目的 MIT 许可证范围。

## 它做了什么 / 没做什么

- 做的：补齐 Wine 缺失的 Windows 内核驱动框架（WDF）组件，使官方反作弊驱动
  能够完成 `ZwLoadDriver` 初始化，游戏得以启动。
- 没做的：不修改游戏文件、不注入游戏进程、不绕过反作弊校验逻辑。
  等价于「给 Wine 补上 Windows 本该有的系统组件」。
- 风险：仍属于非官方运行方式，可能与游戏服务条款存在冲突，使用风险自负。
