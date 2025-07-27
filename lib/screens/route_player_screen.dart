import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../providers/simple_dashcam_provider.dart';
import '../models/dashcam_models.dart';

class RoutePlayerScreen extends StatefulWidget {
  final String routeName;

  const RoutePlayerScreen({
    super.key,
    required this.routeName,
  });

  @override
  State<RoutePlayerScreen> createState() => _RoutePlayerScreenState();
}

class _RoutePlayerScreenState extends State<RoutePlayerScreen> {
  late final Player _player;
  VideoController? _controller;
  List<SegmentInfo> _segments = [];
  int _currentSegmentIndex = 0;
  String _currentCamera = 'fcamera';
  bool _isControlsVisible = true;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _player = Player();
    _controller = VideoController(_player);
    _loadRouteSegments();
  }

  @override
  void dispose() {
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadRouteSegments() async {
    try {
      final provider = context.read<SimpleDashcamProvider>();
      provider.setRouteFilter(widget.routeName);
      await provider.loadSegments(refresh: true);

      setState(() {
        _segments = provider.segments;
        _isLoading = false;
      });

      if (_segments.isNotEmpty) {
        _playSegment(0);
      }
    } catch (e) {
      setState(() {
        _error = '加载路线失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _playSegment(int index) async {
    if (index < 0 || index >= _segments.length) return;

    setState(() {
      _currentSegmentIndex = index;
      _isLoading = true;
      _error = null;
    });

    final segment = _segments[index];
    final videoUrl = 'http://localhost:8009/api/video/raw/${segment.segmentId}/$_currentCamera';

    try {
      // 使用 Media Kit 播放视频
      await _player.open(Media(videoUrl));
      await _player.play();

      // 监听播放完成事件
      _player.stream.completed.listen((completed) {
        if (completed) {
          _playNextSegment();
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '播放失败: $e';
        _isLoading = false;
      });
    }
  }

  void _playNextSegment() {
    if (_currentSegmentIndex < _segments.length - 1) {
      _playSegment(_currentSegmentIndex + 1);
    }
  }

  void _playPreviousSegment() {
    if (_currentSegmentIndex > 0) {
      _playSegment(_currentSegmentIndex - 1);
    }
  }

  void _switchCamera(String camera) {
    if (_currentCamera != camera) {
      setState(() {
        _currentCamera = camera;
      });
      _playSegment(_currentSegmentIndex);
    }
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
  }

  void _togglePlayPause() {
    if (_player.state.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video player background
            Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFF6366f1),
              child: Center(
                child: _buildVideoPlayer(),
              ),
            ),

            // Top header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _isControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildTopHeader(),
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _isControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildBottomControls(),
              ),
            ),

            // Center play controls
            Center(
              child: AnimatedOpacity(
                opacity: _isControlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildCenterControls(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                '加载中...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _playSegment(_currentSegmentIndex),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Video(
        controller: _controller!,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              widget.routeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous segment
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: IconButton(
              onPressed: _currentSegmentIndex > 0 ? _playPreviousSegment : null,
              icon: const Icon(
                Icons.skip_previous,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Play/Pause
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(40),
            ),
            child: IconButton(
              onPressed: _togglePlayPause,
              icon: StreamBuilder<bool>(
                stream: _player.stream.playing,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Next segment
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: IconButton(
              onPressed: _currentSegmentIndex < _segments.length - 1 ? _playNextSegment : null,
              icon: const Icon(
                Icons.skip_next,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Refresh
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: IconButton(
              onPressed: () => _playSegment(_currentSegmentIndex),
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            Container(
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              child: StreamBuilder<Duration>(
                stream: _player.stream.position,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = _player.state.duration ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;

                  return LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  );
                },
              ),
            ),

            // Segment info
            if (_segments.isNotEmpty)
              Text(
                '段 ${_currentSegmentIndex + 1}/${_segments.length} - ${_formatDateTime(_segments[_currentSegmentIndex].timestamp)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

            const SizedBox(height: 16),

            // Camera selection
            if (_segments.isNotEmpty && _segments[_currentSegmentIndex].cameras.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _segments[_currentSegmentIndex].cameras.keys.map((camera) {
                  final isSelected = camera == _currentCamera;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: ElevatedButton(
                      onPressed: () => _switchCamera(camera),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? const Color(0xFF6366f1) : Colors.grey[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        camera == 'fcamera' ? '前置' : '低质量',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }
}
