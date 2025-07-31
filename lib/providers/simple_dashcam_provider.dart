import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../services/dashcam_api_service.dart';
import '../models/dashcam_models.dart';

class SimpleDashcamProvider extends ChangeNotifier {
  final DashcamApiService _apiService = DashcamApiService();
  final Logger _logger = Logger();

  // State
  bool _isLoading = false;
  String? _error;
  DashcamInfo? _dashcamInfo;
  List<RouteInfo> _routes = [];
  List<SegmentInfo> _segments = [];

  // Pagination for routes
  int _routesCurrentPage = 1;
  int _routesPageSize = 10;
  bool _routesHasMoreData = true;

  // Simple route filter for segments
  String? _selectedRoute;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  DashcamInfo? get dashcamInfo => _dashcamInfo;
  List<RouteInfo> get routes => _routes;
  DashcamApiService get apiService => _apiService;
  List<SegmentInfo> get segments => _segments;
  bool get routesHasMoreData => _routesHasMoreData;

  /// 更新服务器配置
  void updateServerUrl(String serverUrl, {int? timeoutSeconds}) {
    _apiService.updateServerUrl(serverUrl, timeoutSeconds: timeoutSeconds);
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

  /// 设置路线过滤器并加载段列表
  void setRouteFilter(String routeName) {
    _selectedRoute = routeName;
  }

  /// 加载路线详情（包含所有段信息）
  Future<RouteDetailInfo> loadRouteDetail(String routeName) async {
    _setLoading(true);
    _clearError();

    try {
      final routeDetail = await _apiService.getRouteDetail(routeName);
      _segments = routeDetail.segments;
      _selectedRoute = routeName;

      _logger.i('路线详情加载成功，共 ${routeDetail.segments.length} 段');
      return routeDetail;
    } catch (e) {
      _setError('加载路线详情失败: $e');
      _logger.e('加载路线详情失败', error: e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// 加载视频段列表
  Future<void> loadSegments({bool refresh = false}) async {
    _setLoading(true);
    _clearError();

    try {
      final newSegments = await _apiService.getSegments(
        page: 1,
        limit: 100, // 加载更多段用于播放
        routeName: _selectedRoute,
      );

      _segments = newSegments;
      _logger.i('视频段列表加载成功，共 ${_segments.length} 条');
    } catch (e) {
      _setError('加载视频段列表失败: $e');
      _logger.e('加载视频段列表失败', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 设置错误信息
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// 清除错误信息
  void _clearError() {
    _error = null;
    notifyListeners();
  }

  Future<List<SegmentInfo>?> getRouteSegments(String routeName) async {
    try {
      final routeDetail = await _apiService.getRouteDetail(routeName);
      return routeDetail.segments;
    } catch (e) {
      _logger.e('获取路线段列表失败', error: e);
      return null;
    }
  }

  Future<void> deleteSegments(List<String> segmentIds) async {
    await _apiService.deleteSegments(segmentIds);
  }
}
