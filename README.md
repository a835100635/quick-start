# Quick Start

常驻在 macOS 屏幕右边缘的径向快捷启动器。

技术栈：

- Swift 5
- SwiftUI + AppKit
- macOS 15+
- 直接使用 `swiftc` 构建 `.app` 包，无需 Xcode 工程文件

## 使用方式

![Quick Start 使用效果：快捷方式从屏幕边缘展开，打开一个半圆，显示所有程序列表，然后点击其他位置关闭](Resources/global.gif)

![Quick Start 使用效果：快捷方式从屏幕边缘展开，打开一个半圆，显示所有程序列表，然后点击其他位置关闭](Resources/hover.gif)

- 将鼠标移至右侧中间的触发器，展开半圆快捷菜单。
- 点击圆心的齿轮图标，添加、删除或排序应用与文件夹，并调整菜单半径。
- 按 `⌥⌘Space`，在当前鼠标所在屏幕的中心展开完整圆形菜单。
- 在完整菜单中使用 `Esc` 关闭、方向键选择、`Enter` 启动。

启动器默认提供 Safari、终端、计算器和“应用程序”文件夹；均可在设置中移除。

## 构建与运行

需要安装 macOS Command Line Tools：

```sh
./build.sh           # Release 构建 → build/QuickStart.app
./build.sh debug     # Debug 构建
./build.sh run       # 构建并启动
```

### 签名与发布

本机安装了 Developer ID Application 证书时，`build.sh` 会自动选择该证书。
也可以显式指定证书，并阻止构建回退到不可发布的 ad-hoc 签名：

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Company (TEAMID)" \
REQUIRE_DEVELOPER_ID=1 ./build.sh release
./scripts/make-dmg.sh 1.0.0
```

分发给其他用户前还应完成 Apple 公证。先在钥匙串中创建 `notarytool` 配置，
再执行：

```sh
xcrun notarytool store-credentials quickstart
NOTARY_PROFILE=quickstart ./scripts/notarize.sh 1.0.0
```

## 目录结构

```text
Sources/
  Main.swift           应用入口与 AppKit 生命周期
  AppDelegate.swift    常驻应用与全局菜单
  LauncherItem.swift   快捷项数据与本地持久化
  LauncherPanel.swift  透明悬浮面板与鼠标追踪
  LauncherController.swift
                       面板状态、显示器与键盘事件
  LauncherViews.swift  边缘、半圆与整圆 SwiftUI 界面
  SettingsWindow.swift 快捷项管理窗口
  HotKeys.swift        Carbon 全局快捷键
Info.plist            App bundle 元数据
build.sh              不依赖 Xcode 的构建脚本
```
