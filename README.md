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
