import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/simple_dashcam_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/dashcam_models.dart';

class NewRoutesListScreen extends StatefulWidget {
  const NewRoutesListScreen({super.key});

  @override
  State<NewRoutesListScreen> createState() => _NewRoutesListScreenState();
}

class _NewRoutesListScreenState extends State<NewRoutesListScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _isDeleting = false; // 添加这一行
  String _statusText = '正在连接...';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreRoutes();
    }
  }

  Future<void> _initializeData() async {
    final provider = context.read<SimpleDashcamProvider>();
    final settings = context.read<AppSettingsProvider>();

    setState(() {
      _statusText = '正在初始化...';
    });

    try {
      // 等待设置初始化完成
      while (!settings.isInitialized) {
        print('🔧 等待设置初始化完成...');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('🔧 设置初始化完成，当前保存的服务器URL: ${settings.serverUrl}');

      setState(() {
        _statusText = '正在连接服务器...';
      });

      // 使用正确的服务器URL
      provider.updateServerUrl(settings.serverUrl);

      await Future.wait([
        provider.loadDashcamInfo(),
        provider.loadRoutes(refresh: true),
      ]);

      setState(() {
        _statusText = '已连接 - ${provider.routes.length} 条路线';
      });
    } catch (e) {
      setState(() {
        _statusText = '连接失败';
      });
    }
  }

  Future<void> _loadMoreRoutes() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await context.read<SimpleDashcamProvider>().loadMoreRoutes();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _statusText = '正在刷新...';
    });

    final provider = context.read<SimpleDashcamProvider>();
    await Future.wait([
      provider.loadDashcamInfo(),
      provider.loadRoutes(refresh: true),
    ]);

    setState(() {
      _statusText = '已连接 - ${provider.routes.length} 条路线';
    });
  }

  void _playRoute(RouteInfo route) {
    context.push('/player/${route.routeName}');
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => _buildSettingsDialog(),
    );
  }

  Widget _buildSettingsDialog() {
    return Consumer<AppSettingsProvider>(
      builder: (context, settings, child) {
        final controller = TextEditingController(text: settings.serverUrl);

        return AlertDialog(
          title: const Text('服务器设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: 'http://localhost:8010',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                await settings.setServerUrl(controller.text.trim());
                final provider = context.read<SimpleDashcamProvider>();
                provider.updateServerUrl(controller.text.trim());
                Navigator.pop(context);
                _refreshData();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '行车记录仪 - 路线视图',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _showSettings,
                          icon: const Icon(
                            Icons.settings,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Statistics section
                      _buildStatisticsSection(),

                      // Routes list
                      Expanded(
                        child: Consumer<SimpleDashcamProvider>(
                          builder: (context, provider, child) {
                            if (provider.isLoading && provider.routes.isEmpty) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (provider.error != null && provider.routes.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        size: 64,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        '加载失败',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        provider.error!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton(
                                        onPressed: _refreshData,
                                        child: const Text('重试'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            if (provider.routes.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.route_outlined,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        '暂无路线数据',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return RefreshIndicator(
                              onRefresh: _refreshData,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: provider.routes.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= provider.routes.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  final route = provider.routes[index];
                                  return _buildRouteItem(route);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Consumer<SimpleDashcamProvider>(
      builder: (context, provider, child) {
        final dashcamInfo = provider.dashcamInfo;
        final totalRoutes = dashcamInfo?.totalRoutes ?? 0;
        final totalSegments = dashcamInfo?.totalSegments ?? 0;
        final totalSize = dashcamInfo?.totalSize ?? 0;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem('总路线数', '$totalRoutes'),
                  ),
                  Expanded(
                    child: _buildStatItem('总段数', '$totalSegments'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem('总大小', _formatFileSize(totalSize)),
                  ),
                  Expanded(
                    child: _buildStatItem('状态', provider.error == null ? '正常' : '异常'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _deleteSegments(RouteInfo route) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSegmentsDialog(route),
    );
  }

  Widget _buildSegmentsDialog(RouteInfo route) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('${route.routeName} - 段列表'),
          content: FutureBuilder<List<SegmentInfo>?>(
            future: context.read<SimpleDashcamProvider>().getRouteSegments(route.routeName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在加载段列表...'),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text('加载失败: ${snapshot.error}'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                );
              }

              final segments = snapshot.data;
              if (segments == null || segments.isEmpty) {
                return const Center(
                  child: Text('没有找到可删除的段'),
                );
              }

              // 在这里定义变量，使其在FutureBuilder的builder作用域内
              final selectedSegments = <String>{};
              bool isDeleting = false;

              return StatefulBuilder(
                builder: (context, setInnerState) => SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 添加全选和反选按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: isDeleting ? null : () {
                              setInnerState(() {
                                if (selectedSegments.length == segments.length) {
                                  selectedSegments.clear();
                                } else {
                                  selectedSegments.addAll(
                                    segments.map((s) => s.segmentId)
                                  );
                                }
                              });
                            },
                            child: Text(
                              selectedSegments.length == segments.length ? '取消全选' : '全选'
                            ),
                          ),
                          TextButton(
                            onPressed: isDeleting ? null : () {
                              setInnerState(() {
                                final allSegmentIds = segments.map((s) => s.segmentId).toSet();
                                final toSelect = allSegmentIds.difference(selectedSegments);
                                selectedSegments.clear();
                                selectedSegments.addAll(toSelect);
                              });
                            },
                            child: const Text('反选'),
                          ),
                        ],
                      ),
                      const Divider(),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: segments.length,
                          itemBuilder: (context, index) {
                            final segment = segments[index];
                            final totalSize = segment.size;
                            
                            return CheckboxListTile(
                              value: selectedSegments.contains(segment.segmentId),
                              onChanged: isDeleting ? null : (bool? value) {
                                setInnerState(() {
                                  if (value == true) {
                                    selectedSegments.add(segment.segmentId);
                                  } else {
                                    selectedSegments.remove(segment.segmentId);
                                  }
                                });
                              },
                              title: Text('段ID: ${segment.segmentId}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('时间: ${_formatTimeRange(segment.startTime, segment.endTime)}'),
                                  Text('大小: ${_formatFileSize(totalSize)}'),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (isDeleting)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('正在删除...'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            Builder(
              builder: (context) {
                // 这里需要访问FutureBuilder的snapshot，但它在这个作用域外
                // 需要重新获取数据或重构代码结构
                return Consumer<SimpleDashcamProvider>(
                  builder: (context, provider, _) {
                    return FutureBuilder<List<SegmentInfo>?>(
                      future: provider.getRouteSegments(route.routeName),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                          return const SizedBox();
                        }
                        
                        return StatefulBuilder(
                          builder: (context, setActionState) {
                            bool isDeleting = false;
                            final selectedSegments = <String>{};
                            
                            return ElevatedButton(
                              onPressed: isDeleting || selectedSegments.isEmpty
                                  ? null
                                  : () async {
                                      setActionState(() => isDeleting = true);
                                      try {
                                        await provider.deleteSegments(selectedSegments.toList());
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('删除成功')),
                                          );
                                          _refreshData();
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          setActionState(() => isDeleting = false);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('删除失败: $e')),
                                          );
                                        }
                                      }
                                    },
                              child: isDeleting
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('删除中...'),
                                      ],
                                    )
                                  : const Text('删除所选'),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  // 修改路线列表项的构建方法，添加删除按钮
  Widget _buildRouteItem(RouteInfo route) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playRoute(route),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Route icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366f1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.route,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                // Route info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.routeName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366f1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTimeRange(route.startTime, route.endTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '总共${route.segmentCount} 段',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _formatFileSize(route.totalSize),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Play button and settings
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366f1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => _playRoute(route),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: _isDeleting ? null : () => _deleteSegments(route),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeRange(String startTime, String endTime) {
    try {
      final start = DateTime.parse(startTime);
      final end = DateTime.parse(endTime);
      return '${start.year}/${start.month}/${start.day} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:${start.second.toString().padLeft(2, '0')} - ${end.year}/${end.month}/${end.day} ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}:${end.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return '$startTime - $endTime';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
