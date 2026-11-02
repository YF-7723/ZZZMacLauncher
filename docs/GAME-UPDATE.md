# 游戏版本更新指南（当 Yaagl 的版本清单过期时）

> 背景：Yaagl 内置的"最新版本"清单来自其发布版本。如果游戏更新了但 Yaagl 版本还没跟上，
> Yaagl 会认为「已是最新」，而游戏客户端会提示「有新版本，请前往启动器更新」并在点击后闪退。
> 本文记录 2026-10-22 从 **3.2.0 手工更新到 3.3.0** 的完整流程，可复用于后续版本。

---

## 一、先判断是哪种情况

| 现象 | 判断 | 处理 |
|---|---|---|
| Yaagl 显示「可更新」并正常下载 | Yaagl 清单是新的 | 直接用 Yaagl 更新即可（见第五节） |
| Yaagl 显示「已是最新」，但游戏提示「有新版本」后闪退 | **Yaagl 清单过期** | 按本文手工更新（第二~四节） |
| 游戏本身版本已是最新，只是资源包缺失 | 资源问题 | 在游戏内下载资源（或等待下载完成） |

检查当前版本：

```bash
GAME="${ZZZ_GAME_DIR:-$HOME/Games}"
grep game_version "$GAME/config.ini"
cat "$GAME/version_info"
```

正常时应一致，例如：

```
game_version=3.3.0
CNPRODWin3.3.0
```

---

## 二、官方增量包的结构

官方启动器更新时下载的是一个**增量包 zip**（例如 3.2.0 → 3.3.0），内部包含：

| 内容 | 作用 |
|---|---|
| 普通文件（游戏资源/代码/配置） | 新版本文件，直接覆盖 |
| `deletefiles.txt` | **需要删除**的旧文件清单（CRLF 换行，需去掉 `\r`） |
| `hdifffiles.txt` | 需要**差分合并**的文件清单（33 个左右） |
| `*.hdiff` 差分文件 | 配合旧文件生成新文件（hdiffpatch 格式） |
| 语言包/语音包（如 `audio_zh-cn`） | 可选；若旧语音文件不存在，hdiff 会失败，可跳过让游戏内自动下载 |
| 若包含 `config.ini` / `version_info` | 更新后版本标识 |

> 注意：只使用**官方**增量包。不要使用第三方修改过内容的补丁包（会破坏校验/反作弊环境）。

### 获取官方增量包的两种方式

1. **推荐：官方启动器更新**（把游戏装到临时目录或另一台 Windows 机器，让它更新到最新，
   从启动器下载缓存里取出增量包 zip）；
2. **官方更新接口**：miHoYo 启动器通过 `hyp-connect` 接口获取每个版本的增量包地址与
   md5 清单（`getGamePackages` 系列接口，返回每个包的 `name` / `md5` / `size` /
   `segments` 下载分片）。用官方接口拿到 3.2.0→3.3.0 的包信息后，按其提供的 md5
   校验下载完整性。不同版本接口参数可能变化，以官方启动器当前行为为准。

> 校验原则：每个下载文件的 md5 必须与官方清单一致，否则不要继续打补丁。

---

## 三、打补丁步骤（以 3.2.0 → 3.3.0 为例）

以下命令中的 `$GAME` 为游戏目录（默认 `~/Games`），`$PKG` 为解压后的增量包目录。

### 1. 备份（强烈建议）

```bash
GAME="$HOME/Games"
cp "$GAME/config.ini" /tmp/config.ini.bak
# 至少备份配置与版本文件；如空间允许，可对整个游戏目录做 APFS 克隆备份
```

### 2. 解压增量包

```bash
mkdir -p "$PKG"
unzip -q /path/to/3.2.0_3.3.0.zip -d "$PKG"
```

### 3. 删除旧文件（deletefiles.txt）

该文件是 CRLF 换行，需要先处理：

```bash
tr -d '\r' < "$PKG/deletefiles.txt" > /tmp/deletefiles.lst
# 预览一遍再删（确认路径都在游戏目录内）
head -5 /tmp/deletefiles.lst
while IFS= read -r f; do
  [ -n "$f" ] && rm -f "$GAME/$f"
done < /tmp/deletefiles.lst
```

### 4. 差分合并（hdifffiles.txt + *.hdiff）

需要 `hdiffpatch` 工具（macOS 可用 `brew install hdiffpatch`，或使用
[hdiffpatch](https://github.com/sisong/hdiffpatch) 的 `hpatchz`）。

一般约定：`X.hdiff` 表示把旧文件 `X` 合并成新文件 `X`。

```bash
tr -d '\r' < "$PKG/hdifffiles.txt" > /tmp/hdifffiles.lst
while IFS= read -r f; do
  [ -n "$f" ] || continue
  rel="${f%.hdiff}"                 # 去掉 .hdiff 后缀得到目标相对路径
  old="$GAME/$rel"
  patch="$PKG/$f"
  [ -f "$old" ] || { echo "缺少旧文件，跳过: $rel"; continue; }
  hpatchz -f "$old" "$patch" "$old.new" && mv -f "$old.new" "$old"
done < /tmp/hdifffiles.lst
```

> 语音包（如 `zh-cn` 的 `audio_*.hdiff`）若旧文件不存在会失败：
> 此时跳过即可，进入游戏后在设置里切换/下载语音资源（本次即如此处理，游戏自动下载完成）。

### 5. 覆盖普通文件

```bash
# 用 rsync 保留目录结构、跳过已处理过的补丁文件
rsync -a --exclude='deletefiles.txt' --exclude='hdifffiles.txt' --exclude='*.hdiff' \
  "$PKG/" "$GAME/"
```

### 6. 校验 md5

官方清单里有每个文件的 md5。至少抽查关键文件；有条件建议全量校验：

```bash
# 示例：逐行校验清单（格式：md5  相对路径）
cd "$GAME"
md5 -r "ZenlessZoneZero.exe" "ZenlessZoneZero_Data/globalgamemanagers" | head
# 或写个小脚本对清单全量比对
```

本次实际结果：**抽样 15 个文件，md5 15/15 全部通过**。

### 7. 版本标识

确认（若增量包未包含则手工写入）：

```bash
# 内容应为当前版本，如 3.3.0
grep game_version "$GAME/config.ini"
# 内容应为 CNPRODWin3.3.0
cat "$GAME/version_info"
```

### 8. 启动验证

```bash
bash scripts/restore-wdf.sh          # 更新/改动后保险起见重新注入 WDF 兼容模块
# 用本项目启动器启动
bash run.sh
```

验证标准：
- 不再弹「有新版本，请前往启动器更新」；
- 能正常登录、进入游戏世界；
- 游戏内 `设置 → 关于`/版本信息显示 3.3.0。

---

## 四、本次 3.2.0 → 3.3.0 实际记录（2026-10-22）

| 项目 | 结果 |
|---|---|
| 增量包内容 | 1194 个普通文件 + `deletefiles.txt` 680 条 + `hdifffiles.txt` 33 个 + 中文语音 hdiff 包 |
| 语音包 | 初始提取因旧语音文件不存在而失败 → 清理 `Full/Cn` 残留、改由游戏内自动下载（Persistent/Audio 2.1GB → 4.53GB 下载完成） |
| md5 校验 | 抽样 15/15 通过 |
| 更新后版本 | `config.ini game_version=3.3.0`、`version_info=CNPRODWin3.3.0` |
| 结果 | 可正常登录、进入世界、游玩「贝果计划」 |

遇到的坑：

1. `deletefiles.txt` 是 CRLF，直接按行处理会带 `\r` 导致删不到文件；
2. 语音包 hdiff 需要旧语音文件，缺失时不要强打，交给游戏内下载；
3. 更新后第一次启动可能重新校验资源，较慢属正常；
4. 如果 Yaagl 重装/升级了 Wine 运行时，记得运行 `scripts/restore-wdf.sh`。

---

## 五、如果 Yaagl 的版本清单是新的（正常情况）

1. 打开 Yaagl，点「更新」，等它下载完成；
2. 不要点「开始游戏」（避免它按旧配置启动）；
3. 更新完成后运行：

```bash
bash scripts/restore-wdf.sh
bash run.sh
```

---

## 六、安全提示

- 只使用**官方**增量包；不要使用第三方修改包，避免破坏文件校验与反作弊环境；
- 打补丁前备份 `config.ini`、`version_info`，以及（空间允许时）整个游戏目录；
- 更新过程不要启动游戏；
- 若更新后出现闪退，先检查 md5 校验是否全部通过、`version_info` 是否一致；
- 版本不匹配时游戏会直接拒绝登录，不会静默运行。
