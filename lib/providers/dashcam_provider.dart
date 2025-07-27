import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../models/dashcam_models.dart';
import '../services/dashcam_api_service.dart';

class DashcamProvider extends ChangeNotifier {
  final DashcamApiService _apiService = DashcamApiService();
  final Logger _logger = Logger();

  // State
  DashcamInfo? _dashcamInfo;
  List<RouteInfo> _routes = [];
  List<SegmentInfo> _segments = [];
  bool _isLoading = false;
  String? _error;

  // Pagination for segments
  int _segmentsCurrentPage = 1;
  int _segmentsPageSize = 20;
  bool _segmentsHasMoreData = true;

  // Pagination for routes
  int _routesCurrentPage = 1;
  int _routesPageSize = 10;
  bool _routesHasMoreData = true;

  // Filters
  String? _selectedCamera;
  String? _selectedRoute;
  DateTime? _startDate;
  DateTime? _endDate;

  // Getters
  DashcamInfo? get dashcamInfo => _dashcamInfo;
  List<RouteInfo> get routes => _routes;
  List<SegmentInfo> get segments => _segments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  // Segments pagination getters
  int get segmentsCurrentPage => _segmentsCurrentPage;
  int get segmentsPageSize => _segmentsPageSize;
  bool get segmentsHasMoreData => _segmentsHasMoreData;

  // Routes pagination getters
  int get routesCurrentPage => _routesCurrentPage;
  int get routesPageSize => _routesPageSize;
  bool get routesHasMoreData => _routesHasMoreData;
  String? get selectedCamera => _selectedCamera;
  String? get selectedRoute => _selectedRoute;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  String get serverUrl => _apiService.baseUrl;

  void updateServerUrl(String newUrl, {int? timeoutSeconds}) {
    _apiService.updateBaseUrl(newUrl, timeoutSeconds: timeoutSeconds);
    notifyListeners();
  }

  Future<bool> testConnection() async {
    return await _apiService.testConnection();
  }

  /// 加载行车记录仪信息
  Future<void> loadDashcamInfo() async {
    _setLoading(true);
    _clearError();

    try {
      _dashcamInfo = await _apiService.getDashcamInfo();
      _logger.i('行车记录仪信息加载成功');
    } catch (e) {
      _setError('加载行车记录仪信息失败: $e');
      _logger.e('加载行车记录仪信息失败', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// 加载路线列表
  Future<void> loadRoutes({bool refresh = false}) async {
    if (refresh) {
      _routes.clear();
      _routesCurrentPage = 1;
      _routesHasMoreData = true;
    }

    if (!_routesHasMoreData && !refresh) return;

    _setLoading(true);
    _clearError();

    try {
      final newRoutes = await _apiService.getRoutes(
        page: _routesCurrentPage,
        limit: _routesPageSize,
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
      );

      if (refresh) {
        _routes = newRoutes;
      } else {
        _routes.addAll(newRoutes);
      }

      _routesHasMoreData = newRoutes.length == _routesPageSize;
      if (_routesHasMoreData) _routesCurrentPage++;

      _logger.i('路线列表加载成功，共 ${_routes.length} 条');
    } catch (e) {
      _setError('加载路线列表失败: $e');
      _logger.e('加载路线列表失败', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// 加载更多路线
  Future<void> loadMoreRoutes() async {
    await loadRoutes(refresh: false);
  }

  /// 加载更多视频段
  Future<void> loadMoreSegments() async {
    await loadSegments(refresh: false);
  }

  /// 加载视频段列表
  Future<void> loadSegments({bool refresh = false}) async {
    if (refresh) {
      _segments.clear();
      _segmentsCurrentPage = 1;
      _segmentsHasMoreData = true;
    }

    if (!_segmentsHasMoreData && !refresh) return;

    _setLoading(true);
    _clearError();

    try {
      final newSegments = await _apiService.getSegments(
        page: _segmentsCurrentPage,
        limit: _segmentsPageSize,
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
        camera: _selectedCamera,
        routeName: _selectedRoute,
      );

      if (refresh) {
        _segments = newSegments;
      } else {
        _segments.addAll(newSegments);
      }

      _segmentsHasMoreData = newSegments.length == _segmentsPageSize;
      if (_segmentsHasMoreData) _segmentsCurrentPage++;

      _logger.i('视频段列表加载成功，共 ${_segments.length} 条');
    } catch (e) {
      _setError('加载视频段列表失败: $e');
      _logger.e('加载视频段列表失败', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// 获取视频段详情
  Future<SegmentInfo?> getSegmentDetail(String segmentId) async {
    try {
      return await _apiService.getSegmentDetail(segmentId);
    } catch (e) {
      _logger.e('获取视频段详情失败', error: e);
      return null;
    }
  }

  /// 获取视频信息
  Future<VideoInfo?> getVideoInfo(String segmentId, String camera) async {
    try {
      return await _apiService.getVideoInfo(segmentId, camera);
    } catch (e) {
      _logger.e('获取视频信息失败', error: e);
      return null;
    }
  }

  /// 获取原生HEVC视频URL
  String getRawVideoUrl(String segmentId, String camera) {
    return _apiService.getRawVideoUrl(segmentId, camera);
  }

  /// 获取HLS播放列表URL
  String getHlsPlaylistUrl(String segmentId, String camera) {
    return _apiService.getHlsPlaylistUrl(segmentId, camera);
  }

  /// 设置过滤器
  void setFilters({
    String? camera,
    String? route,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    bool changed = false;

    if (_selectedCamera != camera) {
      _selectedCamera = camera;
      changed = true;
    }

    if (_selectedRoute != route) {
      _selectedRoute = route;
      changed = true;
    }

    if (_startDate != startDate) {
      _startDate = startDate;
      changed = true;
    }

    if (_endDate != endDate) {
      _endDate = endDate;
      changed = true;
    }

    if (changed) {
      notifyListeners();
      // 重新加载数据
      loadSegments(refresh: true);
    }
  }

  /// 设置路线过滤器
  void setRouteFilter(String routeName) {
    setFilters(route: routeName);
  }

  /// 清除过滤器
  void clearFilters() {
    setFilters(camera: null, route: null, startDate: null, endDate: null);
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
