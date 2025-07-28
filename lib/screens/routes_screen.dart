import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/dashcam_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/dashcam_models.dart';
import '../utils/theme.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

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
    final provider = context.read<DashcamProvider>();
    final settings = context.read<AppSettingsProvider>();

    // Update server URL
    provider.updateServerUrl(settings.serverUrl);

    // Load initial data
    await Future.wait([
      provider.loadDashcamInfo(),
      provider.loadRoutes(),
    ]);
  }

  Future<void> _loadMoreRoutes() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await context.read<DashcamProvider>().loadMoreRoutes();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    final provider = context.read<DashcamProvider>();
    await Future.wait([
      provider.loadDashcamInfo(),
      provider.loadRoutes(refresh: true),
    ]);
  }

  void _showRouteOptions(RouteInfo route) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Text(
            '路线: ${route.routeName}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimensions.paddingMedium),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('播放路线'),
            onTap: () {
              Navigator.pop(context);
              _playRoute(route);
            },
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('查看段列表'),
            onTap: () {
              Navigator.pop(context);
              _viewRouteSegments(route);
            },
          ),
          ],
        ),
      ),
    );
  }

  void _playRoute(RouteInfo route) {
    // 跳转到路线的段列表，让用户选择要播放的段
    _viewRouteSegments(route);
  }

  void _viewRouteSegments(RouteInfo route) {
    context.push('/route/${route.routeName}/segments');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('路线列表'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          // Routes list
          Expanded(
            child: Consumer<DashcamProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.routes.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.error != null && provider.routes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: AppDimensions.paddingMedium),
                        Text(
                          '加载失败',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppDimensions.paddingSmall),
                        Text(
                          provider.error!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.paddingLarge),
                        ElevatedButton(
                          onPressed: _refreshData,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.routes.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.route_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: AppDimensions.paddingMedium),
                        Text(
                          '暂无路线数据',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                    itemCount: provider.routes.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= provider.routes.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppDimensions.paddingMedium),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final route = provider.routes[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(route.routeName),
                          subtitle: Text('${route.segmentCount} segments'),
                          onTap: () => _showRouteOptions(route),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
