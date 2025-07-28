import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  /// 检查并请求media_kit所需的权限
  static Future<bool> requestMediaKitPermissions() async {
    // 只在Android上需要权限
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      // 获取Android版本
      final androidInfo = await _getAndroidVersion();
      print('🔐 Android版本: $androidInfo');

      if (androidInfo >= 33) {
        // Android 13 (API 33) 或更高版本
        print('🔐 Android 13+: 请求视频和音频权限');
        return await _requestAndroid13Permissions();
      } else {
        // Android 12 (API 32) 或更低版本
        print('🔐 Android 12-: 请求存储权限');
        return await _requestLegacyStoragePermissions();
      }
    } catch (e) {
      print('❌ 权限检查失败: $e');
      return false;
    }
  }

  /// 获取Android版本
  static Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    
    try {
      // 使用platform channel获取Android版本
      const platform = MethodChannel('flutter.dev/android_version');
      final version = await platform.invokeMethod('getAndroidVersion');
      return version as int;
    } catch (e) {
      // 如果获取失败，假设是较新版本
      print('⚠️ 无法获取Android版本，假设为Android 13+: $e');
      return 33;
    }
  }

  /// Android 13+ 权限请求
  static Future<bool> _requestAndroid13Permissions() async {
    bool allGranted = true;

    // 请求视频权限
    if (await Permission.videos.isDenied || await Permission.videos.isPermanentlyDenied) {
      print('🔐 请求视频权限...');
      final videoState = await Permission.videos.request();
      if (!videoState.isGranted) {
        print('❌ 视频权限被拒绝');
        allGranted = false;
      } else {
        print('✅ 视频权限已授予');
      }
    } else {
      print('✅ 视频权限已存在');
    }

    // 请求音频权限
    if (await Permission.audio.isDenied || await Permission.audio.isPermanentlyDenied) {
      print('🔐 请求音频权限...');
      final audioState = await Permission.audio.request();
      if (!audioState.isGranted) {
        print('❌ 音频权限被拒绝');
        allGranted = false;
      } else {
        print('✅ 音频权限已授予');
      }
    } else {
      print('✅ 音频权限已存在');
    }

    return allGranted;
  }

  /// Android 12及以下版本的存储权限请求
  static Future<bool> _requestLegacyStoragePermissions() async {
    if (await Permission.storage.isDenied || await Permission.storage.isPermanentlyDenied) {
      print('🔐 请求存储权限...');
      final storageState = await Permission.storage.request();
      if (!storageState.isGranted) {
        print('❌ 存储权限被拒绝');
        return false;
      } else {
        print('✅ 存储权限已授予');
        return true;
      }
    } else {
      print('✅ 存储权限已存在');
      return true;
    }
  }

  /// 检查权限状态
  static Future<Map<String, bool>> checkPermissionStatus() async {
    if (!Platform.isAndroid) {
      return {'all': true};
    }

    final androidVersion = await _getAndroidVersion();
    
    if (androidVersion >= 33) {
      return {
        'videos': await Permission.videos.isGranted,
        'audio': await Permission.audio.isGranted,
        'all': await Permission.videos.isGranted && await Permission.audio.isGranted,
      };
    } else {
      return {
        'storage': await Permission.storage.isGranted,
        'all': await Permission.storage.isGranted,
      };
    }
  }

  /// 打开应用设置页面
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
