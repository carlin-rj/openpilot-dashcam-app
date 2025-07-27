import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const String _serverUrlKey = 'server_url';
  static const String _defaultServerUrl = 'http://localhost:8009';

  String _serverUrl = _defaultServerUrl;

  String get serverUrl => _serverUrl;

  AppSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverUrl = prefs.getString(_serverUrlKey) ?? _defaultServerUrl;
      notifyListeners();
    } catch (e) {
      // 如果加载失败，使用默认值
      _serverUrl = _defaultServerUrl;
    }
  }

  Future<void> setServerUrl(String url) async {
    if (_serverUrl != url) {
      _serverUrl = url;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_serverUrlKey, url);
      } catch (e) {
        // 保存失败，但不影响当前使用
      }
    }
  }
}
