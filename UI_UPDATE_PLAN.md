# macOS 安卓文件管理器计划更新 - 添加设备信息 UI

## 目标
通过显示当前的连接方法、连接详情和手机信息来增强用户界面。

## 任务
1. 更新 `FileBrowserView.swift`，在顶部包含一个 `DeviceInfoHeader`。
2. 该页眉应显示：
   - 设备型号 (`device.model`)
   - 连接类型 (`device.connectionType`)
   - 设备序列号 (`device.serial`)
3. 使用与现有 macOS 设计一致的样式（SF Symbols，次级标签）。
4. 重新构建应用程序以验证视觉变化。
