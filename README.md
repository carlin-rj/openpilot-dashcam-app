# OpenpilotCam

一个跨平台的 Flutter 应用程序，用于查看 OpenPilot 行车记录仪视频。支持 Windows、macOS、Android 和 iOS 平台，原生支持 HEVC 格式视频播放。

## 功能特性

### 🎥 视频播放
- 原生 HEVC 格式支持，无需服务器转码
- 高质量视频播放体验
- 多摄像头视角切换（前置、后置等）

### 📱 跨平台支持
- **Windows**: 桌面应用程序
- **macOS**: 桌面应用程序
- **Android**: 移动应用程序
- **iOS**: 移动应用程序

### 🌟 核心功能
- 路线列表浏览
- 连续路线播放
- 服务器自动发现和手动配置
- 深色/浅色主题自动切换

## 安装和使用

### 前置要求

1. **Flutter SDK**: 版本 3.8.0 或更高
2. **平台特定要求**:
   - **Windows**: Visual Studio 2022 或 Visual Studio Build Tools
   - **macOS**: Xcode 14 或更高
   - **Android**: Android Studio 和 Android SDK
   - **iOS**: Xcode 14 或更高

### 快速开始

#### 使用自动化脚本（推荐）
```bash
./setup.sh
```

#### 手动设置

1. **获取依赖**:
```bash
flutter pub get
```

2. **生成代码**:
```bash
flutter packages pub run build_runner build
```

3. **检查环境**:
```bash
flutter doctor
```

### 运行应用

#### 开发模式
```bash
# 查看可用设备
flutter devices

# 运行到指定平台
flutter run -d macos     # macOS
flutter run -d windows   # Windows
flutter run -d android   # Android
flutter run -d ios       # iOS
```

#### 构建发布版本
```bash
flutter build macos --release    # macOS
flutter build windows --release  # Windows
flutter build apk --release      # Android APK
flutter build ios --release      # iOS
```

## 配置

### 服务器设置
**手动配置**: 在设置中输入服务器地址（默认: `http://localhost:8009`）

## 项目结构

```
lib/
├── main.dart                           # 应用入口
├── models/                             # 数据模型
│   ├── dashcam_models.dart
│   └── dashcam_models.g.dart
├── providers/                          # 状态管理
│   ├── app_settings_provider.dart
│   ├── dashcam_provider.dart
│   └── simple_dashcam_provider.dart
├── screens/                            # 页面
│   ├── enhanced_route_player_screen.dart
│   ├── new_routes_list_screen.dart
│   ├── route_player_screen.dart
│   ├── routes_screen.dart
│   └── video_player_screen.dart
├── services/                           # API 服务
│   ├── dashcam_api_service.dart
│   └── server_discovery_service.dart
├── utils/                              # 工具类
│   └── theme.dart
└── widgets/                            # 自定义组件
    └── quick_connect_dialog.dart
```

## 技术栈

- **Flutter**: 跨平台UI框架
- **media_kit**: 高性能视频播放器，支持HEVC
- **Provider**: 状态管理
- **go_router**: 路由管理
- **dio**: HTTP客户端

## 故障排除

### 常见问题

1. **Flutter 命令未找到**
   - 确保 Flutter SDK 已正确安装并添加到 PATH

2. **依赖安装失败**
   - 运行 `flutter clean` 然后重新 `flutter pub get`

3. **无法连接服务器**
   - 检查服务器是否正在运行
   - 使用自动发现功能扫描网络
   - 手动输入正确的服务器地址

4. **视频播放失败**
   - 确认服务器支持 HEVC 格式
   - 检查网络连接稳定性

5. **构建失败**
   - 运行 `flutter doctor` 检查环境
   - 确保所有平台工具已正确安装

### 调试模式
```bash
flutter run --verbose
```

## 开发

### 代码生成

当修改模型类后，重新生成代码：
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### 添加新功能

1. 在相应的目录下创建新文件
2. 更新 Provider 状态管理
3. 添加必要的 API 调用
4. 更新 UI 组件

## 许可证

本项目遵循与 OpenPilot 相同的许可证。
