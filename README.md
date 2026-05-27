# macOS 安卓文件管理器 (AndroidFile)

一款专为 macOS 设计的原生安卓文件管理工具，支持通过 USB 线连接手机后浏览、拷贝文件。

## 功能特性

- **双协议支持**: 同时支持 ADB (开发人员模式) 和 MTP (标准文件传输) 协议。
- **原生体验**: 使用 Swift 和 SwiftUI 构建，拥有类访达 (Finder) 的操作体验。
- **实时进度**: 支持大文件传输，并在界面上实时显示传输进度。
- **设备信息**: 自动识别连接的手机型号、连接方式及序列号。

## 快速开始

### 前置条件

1. **安装 ADB**: 建议通过 Homebrew 安装：
   ```bash
   brew install android-platform-tools
   ```
2. **安装 libmtp** (可选): 若需使用 MTP 功能：
   ```bash
   brew install libmtp
   ```

### 构建与运行

项目支持命令行构建：

1. **赋予脚本执行权限**:
   ```bash
   chmod +x build_app.sh
   ```
2. **构建应用包**:
   ```bash
   ./build_app.sh
   ```
3. **启动应用**:
   ```bash
   open AndroidFile.app
   ```

## 技术架构

- **前端**: SwiftUI (NavigationSplitView)
- **核心**: 统一的 `FileProvider` 抽象层
- **底层**: 
  - ADB: 调用 `adb` 命令行工具
  - MTP: 桥接 `libmtp` C 库

## 开发计划

详见 [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)。
