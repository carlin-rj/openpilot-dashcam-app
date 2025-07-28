import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const String _serverUrlKey = 'server_url';
  static const String _defaultServerUrl = 'http://localhost:8009';

  String _serverUrl = _defaultServerUrl;
  bool _isInitialized = false;

  String get serverUrl => _serverUrl;
  bool get isInitialized => _isInitialized;

  AppSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverUrl = prefs.getString(_serverUrlKey) ?? _defaultServerUrl;
      print('🔧 从SharedPreferences加载服务器URL: $_serverUrl');
    } catch (e) {
      // 如果加载失败，使用默认值
      _serverUrl = _defaultServerUrl;
      print('⚠️ 加载设置失败，使用默认URL: $_serverUrl');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setServerUrl(String url) async {
    if (_serverUrl != url) {
      print('🔧 保存新的服务器URL: $url (原URL: $_serverUrl)');
      _serverUrl = url;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_serverUrlKey, url);
        print('✅ 服务器URL已保存到SharedPreferences');
      } catch (e) {
        print('❌ 保存服务器URL失败: $e');
      }
    } else {
      print('🔧 服务器URL未变化，无需保存: $url');
    }
  }
}
