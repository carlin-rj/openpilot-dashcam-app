import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/dashcam_provider.dart';
import '../services/server_discovery_service.dart';
import '../utils/theme.dart';

class QuickConnectDialog extends StatefulWidget {
  const QuickConnectDialog({super.key});

  @override
  State<QuickConnectDialog> createState() => _QuickConnectDialogState();
}

class _QuickConnectDialogState extends State<QuickConnectDialog> {
  final TextEditingController _urlController = TextEditingController();
  final ServerDiscoveryService _discoveryService = ServerDiscoveryService();
  
  bool _isConnecting = false;
  bool _isDiscovering = false;
  String? _connectionStatus;
  List<DiscoveredServer> _discoveredServers = [];

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _urlController.text = settings.serverUrl;
    
    // 自动开始发现服务器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _discoverServers();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _discoveryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('连接到服务器'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 手动输入
            _buildManualInput(),
            
            const SizedBox(height: AppDimensions.paddingLarge),
            
            // 自动发现
            _buildAutoDiscovery(),
            
            // 发现的服务器列表
            if (_discoveredServers.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.paddingMedium),
              _buildDiscoveredServers(),
            ],
            
            // 连接状态
            if (_connectionStatus != null) ...[
              const SizedBox(height: AppDimensions.paddingMedium),
              _buildConnectionStatus(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isConnecting ? null : _connectToServer,
          child: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('连接'),
        ),
      ],
    );
  }

  Widget _buildManualInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '手动输入服务器地址',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.100:8009',
            prefixIcon: Icon(Icons.link),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          onSubmitted: (_) => _connectToServer(),
        ),
      ],
    );
  }

  Widget _buildAutoDiscovery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '自动发现服务器',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _isDiscovering ? null : _discoverServers,
              icon: _isDiscovering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isDiscovering ? '搜索中...' : '重新搜索'),
            ),
          ],
        ),
        if (_isDiscovering)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildDiscoveredServers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '发现的服务器 (${_discoveredServers.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            itemCount: _discoveredServers.length,
            itemBuilder: (context, index) {
              final server = _discoveredServers[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.computer, size: 20),
                title: Text(
                  server.name,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.url,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (server.totalSegments > 0)
                      Text(
                        '${server.totalRoutes} 路线, ${server.totalSegments} 段',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  onPressed: () {
                    _urlController.text = server.url;
                    _connectToServer();
                  },
                ),
                onTap: () {
                  _urlController.text = server.url;
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    final isSuccess = _connectionStatus == '连接成功';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _connectionStatus!,
              style: TextStyle(
                color: isSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _discoverServers() async {
    setState(() {
      _isDiscovering = true;
      _discoveredServers.clear();
    });

    try {
      final servers = await _discoveryService.discoverServers();
      setState(() {
        _discoveredServers = servers;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
      }
    }
  }

  Future<void> _connectToServer() async {
    if (_urlController.text.trim().isEmpty) {
      setState(() {
        _connectionStatus = '请输入服务器地址';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionStatus = null;
    });

    try {
      final dashcamProvider = context.read<DashcamProvider>();
      final settings = context.read<SettingsProvider>();
      
      dashcamProvider.updateServerUrl(
        _urlController.text.trim(),
        timeoutSeconds: settings.connectionTimeout,
      );
      
      final isConnected = await dashcamProvider.testConnection();
      
      setState(() {
        _connectionStatus = isConnected ? '连接成功' : '连接失败';
      });

      if (isConnected) {
        await settings.setServerUrl(_urlController.text.trim());
        
        // 延迟一下让用户看到成功状态
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.pop(context, true); // 返回 true 表示连接成功
        }
      }
    } catch (e) {
      setState(() {
        _connectionStatus = '连接错误: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }
}
