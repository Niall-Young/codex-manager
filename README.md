# Codex Manager

`Codex Manager` 是一个 macOS 菜单栏应用，用来管理本机多个 Codex / ChatGPT 账号配置。

它的核心目的不是“多开”或者“轮换”，而是把每个账号的本地 `CODEX_HOME` 隔离保存，并在你需要时安全切换当前正在使用的账号。

## 这是什么

这个应用适合下面这些场景：

- 你有多个 ChatGPT / Codex 账号，需要在同一台 Mac 上切换使用。
- 你不想手动复制 `~/.codex/auth.json`。
- 你希望每个账号都有独立的本地配置目录，避免互相污染。
- 你想在菜单栏里快速查看当前账号、剩余额度和本机使用估算。

它不会做这些事情：

- 不会自动轮换账号。
- 不会绕过 Codex 限制。
- 不会共享或导出你的敏感认证信息。

## 它是怎么工作的

应用会把每个受管理账号保存在独立目录中：

`~/Library/Application Support/Codex Manager/Profiles/<profile-id>/codex-home/`

当前系统正在使用的 Codex 认证文件仍然是：

`~/.codex/auth.json`

当你在应用里切换账号时，它会：

1. 先把当前账号的 `auth.json` 同步回它自己的独立目录。
2. 再把目标账号的 `auth.json` 原子写回 `~/.codex/auth.json`。
3. 如果桌面版 Codex 正在运行，会尝试自动重启，避免切换后状态不一致。

## 主要功能

- 菜单栏查看当前激活账号
- 添加并管理多个本地隔离账号
- 一键切换当前使用的 Codex 账号
- 读取 Codex app-server 返回的额度信息
- 显示本机 SQLite 估算的 token / 会话数量
- 打开数据目录，方便排查和备份

## 界面说明

主界面包含这些部分：

- 当前账号信息
- 剩余额度卡片
- 本机估算
- 已托管账号列表
- 导入当前账号
- 设置

### 剩余额度颜色

额度条会按剩余百分比变色：

- 大于 `50%`：绿色
- `30% - 50%`：蓝色
- `10% - 29%`：黄色
- 小于 `10%`：红色

### 本机估算是什么意思

本机估算来自这台 Mac 本地 Codex SQLite 数据，不等于官方剩余额度。

它更适合用来判断“这台机器最近用了多少”，不适合拿来替代官方配额判断。

## 如何使用

### 1. 启动应用

启动后，应用会常驻在 macOS 菜单栏中。

### 2. 导入当前账号

如果你当前 `~/.codex/auth.json` 已经登录好了某个账号，可以点击：

`导入当前`

应用会把当前账号保存为一个可管理 profile。

### 3. 添加新账号

点击右上角 `+`：

- 会弹出一个原生 sheet
- 点击 `登录`
- 按提示用 ChatGPT 账号完成登录
- 登录完成后，这个账号会被保存为新的隔离 profile

如果你勾选了：

`添加后立即切换`

则登录完成后会自动切换过去。

### 4. 切换账号

在账号列表里点击切换按钮即可。

如果 Codex 桌面版正在运行，应用会提示并尝试自动重启桌面端。

### 5. 查看或打开数据目录

在设置页里点击路径行，会直接在 Finder 中打开对应目录。

## 隐私和安全

- 敏感认证信息保存在本机，不上传到第三方服务。
- `profiles.json` 只保存非敏感元数据。
- 账号的 `auth.json` 保存在各自隔离目录中。
- 切换写入采用原子替换，尽量避免中途损坏。

## 构建与运行

项目使用：

- Swift 5.9
- Swift Package Manager
- macOS 13+

### 本地开发构建

```bash
swift build
```

### 运行自测

```bash
swift run CodexManagerSelfTest
```

### 直接运行调试版本

```bash
.build/debug/CodexManager
```

### 生成 `.app`

```bash
bash scripts/build-app.sh
```

生成后的位置：

`./.build/Codex Manager.app`

## 分发给朋友使用

项目已经包含图标生成和打包脚本。

### 一键打包

```bash
bash scripts/package-app.sh
```

打包后会生成：

- `./.build/Codex Manager.app`
- `./.build/Codex Manager.zip`

你可以直接把这个 zip 发给别人使用。

### 需要知道的一点

当前是本地 ad-hoc 签名，不是 Apple Developer ID notarization。

所以朋友第一次打开时，macOS 可能会提示来源未验证。通常可以：

1. 右键应用
2. 选择“打开”
3. 再确认一次

如果后续要正式对外发布，建议补：

- Developer ID 签名
- notarization

## 项目结构

- `Sources/CodexManagerApp`
  菜单栏 app、SwiftUI 界面、窗口与交互逻辑
- `Sources/CodexManagerCore`
  profile 存储、auth 文件切换、额度读取、路径与模型
- `Sources/CodexManagerSelfTest`
  不依赖 XCTest 的轻量自测
- `scripts/build-app.sh`
  生成 `.app`
- `scripts/package-app.sh`
  打包可分发 zip
- `scripts/generate-app-icon.swift`
  生成 app 图标

## 已知说明

- 菜单栏图标使用 SF Symbols。
- 应用图标会在打包时自动生成。
- `.build/` 是构建产物，不应提交到仓库。

## License

本项目源码公开，按 `PolyForm Noncommercial License 1.0.0` 授权。

你可以在非商业用途下使用、复制、修改和分发本项目。商业使用不在该许可证授权范围内，如需商业授权，请先联系作者。

完整条款见 [`LICENSE`](./LICENSE)。
