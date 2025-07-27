import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

class ServerDiscoveryService {
  static const List<int> _commonPorts = [8009, 8080, 3000, 8000, 5000];
  static const int _discoveryTimeout = 3; // seconds
  
  final Logger _logger = Logger();
  final Dio _dio = Dio();

  ServerDiscoveryService() {
    _dio.options.connectTimeout = const Duration(seconds: _discoveryTimeout);
    _dio.options.receiveTimeout = const Duration(seconds: _discoveryTimeout);
  }

  /// 发现局域网中的 dashcam 服务器
  Future<List<DiscoveredServer>> discoverServers() async {
    final List<DiscoveredServer> servers = [];
    
    try {
      // 获取本机 IP 地址
      final interfaces = await NetworkInterface.list();
      final localIps = <String>[];
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            localIps.add(addr.address);
          }
        }
      }
      
      // 扫描每个网段
      for (final localIp in localIps) {
        final subnet = _getSubnet(localIp);
        if (subnet != null) {
          final subnetServers = await _scanSubnet(subnet);
          servers.addAll(subnetServers);
        }
      }
      
      // 去重
      final uniqueServers = <String, DiscoveredServer>{};
      for (final server in servers) {
        uniqueServers[server.url] = server;
      }
      
      return uniqueServers.values.toList();
    } catch (e) {
      _logger.e('服务器发现失败', error: e);
      return [];
    }
  }

  /// 扫描指定子网
  Future<List<DiscoveredServer>> _scanSubnet(String subnet) async {
    final List<DiscoveredServer> servers = [];
    final List<Future<DiscoveredServer?>> futures = [];
    
    // 扫描 IP 范围 (1-254)
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      
      // 扫描常用端口
      for (final port in _commonPorts) {
        futures.add(_checkServer(ip, port));
      }
    }
    
    // 等待所有扫描完成
    final results = await Future.wait(futures);
    
    for (final result in results) {
      if (result != null) {
        servers.add(result);
      }
    }
    
    return servers;
  }

  /// 检查指定 IP 和端口是否有 dashcam 服务器
  Future<DiscoveredServer?> _checkServer(String ip, int port) async {
    try {
      final url = 'http://$ip:$port';
      final response = await _dio.get('$url/api/info');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // 检查是否是 dashcam 服务器
        if (data.containsKey('total_routes') || 
            data.containsKey('total_segments')) {
          
          return DiscoveredServer(
            url: url,
            ip: ip,
            port: port,
            name: _generateServerName(ip, port, data),
            info: data,
            responseTime: DateTime.now().millisecondsSinceEpoch,
          );
        }
      }
    } catch (e) {
      // 忽略连接错误，这是正常的
    }
    
    return null;
  }

  /// 从 IP 地址获取子网前缀
  String? _getSubnet(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }
    return null;
  }

  /// 生成服务器名称
  String _generateServerName(String ip, int port, Map<String, dynamic> info) {
    final totalRoutes = info['total_routes'] ?? 0;
    final totalSegments = info['total_segments'] ?? 0;
    
    if (totalRoutes > 0 || totalSegments > 0) {
      return 'Dashcam Server ($ip:$port) - $totalSegments 段';
    } else {
      return 'Dashcam Server ($ip:$port)';
    }
  }

  /// 测试单个服务器连接
  Future<bool> testServer(String url) async {
    try {
      final response = await _dio.get('$url/api/info');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _dio.close();
  }
}

class DiscoveredServer {
  final String url;
  final String ip;
  final int port;
  final String name;
  final Map<String, dynamic> info;
  final int responseTime;

  const DiscoveredServer({
    required this.url,
    required this.ip,
    required this.port,
    required this.name,
    required this.info,
    required this.responseTime,
  });

  int get totalRoutes => info['total_routes'] ?? 0;
  int get totalSegments => info['total_segments'] ?? 0;
  List<String> get availableCameras => 
      (info['available_cameras'] as List<dynamic>?)?.cast<String>() ?? [];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredServer &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'DiscoveredServer(url: $url, name: $name)';
}
