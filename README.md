# OpenPilot Dashcam Viewer Flutter App

这是一个跨平台的 Flutter 应用程序，用于查看 OpenPilot 行车记录仪视频。支持 Windows、macOS、Android 和 iOS 四个平台，并且能够直接播放 HEVC 格式视频，减轻服务器转码压力。

## 功能特性

### 🎥 原生 HEVC 支持
- 直接播放 HEVC 格式视频，无需服务器转码
- 降低服务器性能要求
- 更好的视频质量和播放性能

### 📱 跨平台支持
- **Windows**: 桌面应用程序
- **macOS**: 桌面应用程序
- **Android**: 移动应用程序
- **iOS**: 移动应用程序

### 🌟 核心功能
- 视频段浏览和搜索
- 多摄像头视角切换
- 日期范围筛选
- 摄像头类型筛选
- 全屏播放支持
- 自动播放设置
- 深色/浅色主题切换

## 安装和使用

### 前置要求

1. **Flutter SDK**: 版本 3.0.0 或更高
2. **Dart SDK**: 版本 3.0.0 或更高
3. **平台特定要求**:
   - **Windows**: Visual Studio 2022 或 Visual Studio Build Tools
   - **macOS**: Xcode 14 或更高
   - **Android**: Android Studio 和 Android SDK
   - **iOS**: Xcode 14 或更高

### 安装 Flutter

#### macOS (使用 Homebrew)
```bash
brew install --cask flutter
```

#### 手动安装
1. 从 [Flutter 官网](https://flutter.dev/docs/get-started/install) 下载 Flutter SDK
2. 解压到合适的目录
3. 将 Flutter bin 目录添加到 PATH 环境变量

### 项目设置

1. **进入项目目录**:
```bash
cd system/dashcam_server/app
```

2. **获取依赖**:
```bash
flutter pub get
```

3. **生成代码**:
```bash
flutter packages pub run build_runner build
```

4. **检查环境**:
```bash
flutter doctor
```

### 运行应用

#### 开发模式

**桌面平台 (macOS)**:
```bash
flutter run -d macos
```

**桌面平台 (Windows)**:
```bash
flutter run -d windows
```

**移动平台 (Android)**:
```bash
flutter run -d android
```

**移动平台 (iOS)**:
```bash
flutter run -d ios
```

#### 构建发布版本

**macOS**:
```bash
flutter build macos --release
```

**Windows**:
```bash
flutter build windows --release
```

**Android APK**:
```bash
flutter build apk --release
```

**iOS**:
```bash
flutter build ios --release
```

## 配置

### 服务器设置

1. 启动应用后，进入设置页面
2. 配置服务器地址（默认: `http://localhost:8009`）
3. 点击"测试连接"确保连接正常

### 视频播放设置

- **优先使用 HEVC**: 启用后优先播放原生 HEVC 格式
- **自动播放**: 打开视频时自动开始播放
- **视频质量**: 选择播放质量（自动/高/中/低）

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   ├── dashcam_models.dart
│   └── dashcam_models.g.dart
├── providers/                # 状态管理
│   ├── dashcam_provider.dart
│   └── settings_provider.dart
├── screens/                  # 页面
│   ├── home_screen.dart
│   ├── video_player_screen.dart
│   └── settings_screen.dart
├── services/                 # API 服务
│   └── dashcam_api_service.dart
├── utils/                    # 工具类
│   └── theme.dart
└── widgets/                  # 自定义组件
    ├── segment_card.dart
    ├── filter_bar.dart
    └── connection_status.dart
```

## API 接口

应用使用以下 API 端点：

- `GET /api/info` - 获取系统信息
- `GET /api/routes` - 获取路线列表
- `GET /api/segments` - 获取视频段列表
- `GET /api/video/raw/{segment_id}/{camera}` - 获取原生 HEVC 视频
- `GET /api/video/info/{segment_id}/{camera}` - 获取视频信息
- `GET /api/hls/{segment_id}/{camera}/playlist.m3u8` - HLS 播放列表（备用）

## 故障排除

### 常见问题

1. **Flutter 命令未找到**
   - 确保 Flutter SDK 已正确安装并添加到 PATH

2. **依赖安装失败**
   - 运行 `flutter clean` 然后重新 `flutter pub get`

3. **视频播放失败**
   - 检查服务器连接
   - 确认服务器支持 HEVC 格式
   - 尝试切换到 HLS 模式

4. **构建失败**
   - 运行 `flutter doctor` 检查环境
   - 确保所有平台工具已正确安装

### 调试模式

启用调试日志：
```bash
flutter run --verbose
```

## 开发

### 添加新功能

1. 在相应的目录下创建新文件
2. 更新 Provider 状态管理
3. 添加必要的 API 调用
4. 更新 UI 组件

### 代码生成

当修改模型类后，重新生成代码：
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

## 许可证

本项目遵循与 OpenPilot 相同的许可证。
