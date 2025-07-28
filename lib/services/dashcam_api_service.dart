
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:logger/logger.dart';

import '../models/dashcam_models.dart';

class DashcamApiService {
  static const String defaultBaseUrl = 'http://localhost:8010';

  final Dio _dio;
  final Logger _logger = Logger();
  late String _baseUrl;

  DashcamApiService({String? baseUrl}) : _dio = Dio() {
    _baseUrl = baseUrl ?? defaultBaseUrl;
    _setupDio();
  }

  /// 更新服务器 URL
  void updateServerUrl(String serverUrl, {int? timeoutSeconds}) {
    _baseUrl = serverUrl;
    _setupDio(timeoutSeconds: timeoutSeconds);
  }

  void _setupDio({int? timeoutSeconds}) {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = Duration(seconds: timeoutSeconds ?? 10);
    _dio.options.receiveTimeout = Duration(seconds: (timeoutSeconds ?? 10) * 3);
    _dio.options.sendTimeout = Duration(seconds: timeoutSeconds ?? 10);

    // 配置 HTTP 客户端以支持更宽松的网络访问
    if (_dio.httpClientAdapter is IOHttpClientAdapter) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        client.connectionTimeout = Duration(seconds: timeoutSeconds ?? 10);
        client.idleTimeout = Duration(seconds: 30);
        return client;
      };
    }

    // Add interceptors for logging
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) => _logger.d(obj),
      ),
    );
  }

  void updateBaseUrl(String newBaseUrl, {int? timeoutSeconds}) {
    _baseUrl = newBaseUrl;
    _dio.options.baseUrl = newBaseUrl;
    if (timeoutSeconds != null) {
      _dio.options.connectTimeout = Duration(seconds: timeoutSeconds);
      _dio.options.receiveTimeout = Duration(seconds: timeoutSeconds * 3);
    }
  }

  String get baseUrl => _baseUrl;

  /// 获取行车记录仪总体信息
  Future<DashcamInfo> getDashcamInfo() async {
    try {
      final response = await _dio.get('/api/info');
      return DashcamInfo.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('获取行车记录仪信息失败: ${e.message}');
      throw ApiException('获取行车记录仪信息失败: ${e.message}');
    }
  }

  /// 获取路线列表
  Future<List<RouteInfo>> getRoutes({
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _dio.get('/api/routes', queryParameters: queryParams);

      if (response.data is Map && response.data['routes'] != null) {
        final routesData = response.data['routes'] as List;
        return routesData.map((json) => RouteInfo.fromJson(json)).toList();
      } else if (response.data is List) {
        return (response.data as List).map((json) => RouteInfo.fromJson(json)).toList();
      } else {
        throw ApiException('无效的响应格式');
      }
    } on DioException catch (e) {
      _logger.e('获取路线列表失败: ${e.message}');
      throw ApiException('获取路线列表失败: ${e.message}');
    }
  }

  /// 获取路线详情
  Future<RouteDetailInfo> getRouteDetail(String routeName) async {
    try {
      final response = await _dio.get('/api/routes/$routeName');
      return RouteDetailInfo.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('获取路线详情失败: ${e.message}');
      throw ApiException('获取路线详情失败: ${e.message}');
    }
  }

  /// 获取视频段列表
  Future<List<SegmentInfo>> getSegments({
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
    String? camera,
    String? routeName,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (camera != null) queryParams['camera'] = camera;
      if (routeName != null) queryParams['route_name'] = routeName;

      final response = await _dio.get('/api/segments', queryParameters: queryParams);

      if (response.data is Map && response.data['segments'] != null) {
        final segmentsData = response.data['segments'] as List;
        return segmentsData.map((json) => SegmentInfo.fromJson(json)).toList();
      } else if (response.data is List) {
        return (response.data as List).map((json) => SegmentInfo.fromJson(json)).toList();
      } else {
        throw ApiException('无效的响应格式');
      }
    } on DioException catch (e) {
      _logger.e('获取视频段列表失败: ${e.message}');
      throw ApiException('获取视频段列表失败: ${e.message}');
    }
  }

  /// 获取视频段详情
  Future<SegmentInfo> getSegmentDetail(String segmentId) async {
    try {
      final response = await _dio.get('/api/segments/$segmentId');
      return SegmentInfo.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('获取视频段详情失败: ${e.message}');
      throw ApiException('获取视频段详情失败: ${e.message}');
    }
  }

  /// 获取视频信息
  Future<VideoInfo> getVideoInfo(String segmentId, String camera) async {
    try {
      final response = await _dio.get('/api/video/info/$segmentId/$camera');
      return VideoInfo.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('获取视频信息失败: ${e.message}');
      throw ApiException('获取视频信息失败: ${e.message}');
    }
  }

  /// 获取原生HEVC视频文件URL
  String getRawVideoUrl(String segmentId, String camera) {
    return '$_baseUrl/api/video/raw/$segmentId/$camera';
  }

  /// 获取HLS播放列表URL
  String getHlsPlaylistUrl(String segmentId, String camera) {
    return '$_baseUrl/api/hls/$segmentId/$camera/playlist.m3u8';
  }

  /// 获取转码视频流URL
  String getStreamVideoUrl(String segmentId, String camera) {
    return '$_baseUrl/api/video/$segmentId/$camera';
  }

  /// 测试服务器连接
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/api/info');
      return response.statusCode == 200;
    } catch (e) {
      _logger.w('服务器连接测试失败: $e');
      return false;
    }
  }

  /// 获取路线的所有视频段信息（包含video_info和缩略图）
  Future<Map<String, dynamic>> getRouteVideoSegments(String routeName) async {
    try {
      final response = await _dio.get('/api/routes/$routeName/video_segments');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _logger.e('获取路线视频段信息失败: ${e.message}');
      throw ApiException('获取路线视频段信息失败: ${e.message}');
    }
  }
}

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
