import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:intl/intl.dart';

import '../providers/simple_dashcam_provider.dart';
import '../models/dashcam_models.dart';

class EnhancedRoutePlayerScreen extends StatefulWidget {
  final String routeName;

  const EnhancedRoutePlayerScreen({
    super.key,
    required this.routeName,
  });

  @override
  State<EnhancedRoutePlayerScreen> createState() => _EnhancedRoutePlayerScreenState();
}

class _EnhancedRoutePlayerScreenState extends State<EnhancedRoutePlayerScreen> {
  late final Player _player;
  VideoController? _controller;
  RouteDetailInfo? _routeDetail;
  Map<String, dynamic>? _videoSegmentsData; // 新的视频段数据
  int _currentSegmentIndex = 0;
  CameraType _currentCamera = CameraType.fcamera;
  bool _isControlsVisible = true;
  bool _isLoading = true;
  String? _error;

  // 虚拟总时长相关
  Duration _virtualTotalDuration = Duration.zero; // 虚拟总时长
  Duration _currentSegmentPosition = Duration.zero; // 当前段内位置
  Duration _globalPosition = Duration.zero; // 全局播放位置
  List<Duration> _segmentStartTimes = []; // 每段的开始时间
  List<Duration> _segmentDurations = []; // 每段的实际时长

  bool _isPlaying = false;
  bool _isSeekingToPosition = false; // 是否正在跳转到指定位置
  bool _isDragging = false; // 是否正在拖动进度条
  bool _wasPlayingBeforeDrag = false; // 拖动前的播放状态
  Duration _dragPosition = Duration.zero; // 拖动时的临时位置
  bool _autoPlay = true; // 自动播放模式

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _player = Player();
    _controller = VideoController(_player);
    _setupPlayerListeners();
    _loadRouteDetail();
  }

  @override
  void dispose() {
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _setupPlayerListeners() {
    // 监听播放状态
    _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    // 监听播放位置
    _player.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _currentSegmentPosition = position;
          _updateVirtualGlobalPosition();
        });
      }
    });

    // 监听播放完成，根据自动播放设置决定是否切换下一段
    _player.stream.completed.listen((completed) {
      if (completed && mounted && !_isSeekingToPosition) {
        if (_autoPlay) {
          print('🎬 当前段播放完成，自动切换到下一段');
          _playNextSegment();
        } else {
          print('🎬 当前段播放完成，自动播放已关闭');
        }
      }
    });
  }

  Future<void> _loadRouteDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final provider = context.read<SimpleDashcamProvider>();

      // 加载基本路线信息
      final routeDetail = await provider.loadRouteDetail(widget.routeName);

      // 加载详细的视频段信息
      final videoSegmentsData = await provider.apiService.getRouteVideoSegments(widget.routeName);

      setState(() {
        _routeDetail = routeDetail;
        _videoSegmentsData = videoSegmentsData;
        _calculateVirtualTotalDuration();
      });

      if (routeDetail.segments.isNotEmpty) {
        await _playSegment(0);
      }
    } catch (e) {
      setState(() {
        _error = '加载路线详情失败: $e';
        _isLoading = false;
      });
    }
  }

  void _calculateVirtualTotalDuration() {
    if (_videoSegmentsData == null) {
      print('❌ _videoSegmentsData 为空');
      return;
    }

    print('📊 开始计算虚拟总时长...');
    print('📊 视频段数据: ${_videoSegmentsData!['total_segments']} 段');

    _segmentStartTimes.clear();
    _segmentDurations.clear();
    Duration currentTime = Duration.zero;

    final segments = _videoSegmentsData!['segments'] as List;

    for (int i = 0; i < segments.length; i++) {
      _segmentStartTimes.add(currentTime);

      final segment = segments[i];
      final cameras = segment['cameras'] as Map<String, dynamic>;

      // 优先使用qcamera的时长，因为HEVC可能获取不到正确时长
      double segmentDuration = 0.0; // 默认值

      // 如果qcamera没有有效时长，再尝试当前摄像头
      if (cameras.containsKey(_currentCamera.value)) {
        final cameraInfo = cameras[_currentCamera.value];
        final videoInfo = cameraInfo['video_info'];
        if (videoInfo != null && videoInfo['duration'] != null) {
          final duration = (videoInfo['duration'] as num).toDouble();
          if (duration > 0) {
            segmentDuration = duration;
            print('✅ 段 $i 使用 $_currentCamera 时长: ${segmentDuration}s');
          }
        }
      }

      final duration = Duration(milliseconds: (segmentDuration * 1000).round());
      _segmentDurations.add(duration);
      currentTime += duration;

      print('📊 段 $i: ${_formatDuration(duration)}, 累计: ${_formatDuration(currentTime)}');
    }

    _virtualTotalDuration = currentTime;
    print('✅ 虚拟总时长计算完成: ${_formatDuration(_virtualTotalDuration)}');
    print('📊 段开始时间: ${_segmentStartTimes.map((t) => _formatDuration(t)).toList()}');

    // 测试段索引计算
    _testSegmentIndexCalculation();
  }

  /// 测试段索引计算是否正确
  void _testSegmentIndexCalculation() {
    print('🧪 测试段索引计算:');

    // 测试关键时间点
    final testTimes = [
      0.0,      // 第0段开始
      5.0,      // 第0段中间
      10.0,     // 第0段结束/第1段开始
      15.0,     // 第1段中间
      20.0,     // 第1段结束/第2段开始
      25.0,     // 第2段中间
      30.0,     // 第2段结束
    ];

    for (final testTime in testTimes) {
      final result = _findTargetSegmentAndTime(testTime);
      if (result != null) {
        print('🧪 时间${testTime.toStringAsFixed(1)}s -> 段${result['segmentIndex']}, 段内${result['segmentTime'].toStringAsFixed(3)}s');
      } else {
        print('🧪 时间${testTime.toStringAsFixed(1)}s -> 未找到段');
      }
    }
    print('🧪 测试完成');
  }

  void _calculateSegmentTimes() {
    if (_routeDetail == null) return;

    _segmentStartTimes.clear();
    _segmentDurations.clear();
    Duration currentTime = Duration.zero;

    for (int i = 0; i < _routeDetail!.segments.length; i++) {
      _segmentStartTimes.add(currentTime);

      // 使用 video_info 中的真实时长，如果没有则使用默认值
      double segmentDuration = _routeDetail!.segments[i].duration.toDouble();
      if (_routeDetail!.segments[i].videoInfo.isNotEmpty &&
          _routeDetail!.segments[i].videoInfo.containsKey(_currentCamera.value)) {
        final videoInfo = _routeDetail!.segments[i].videoInfo[_currentCamera.value];
        if (videoInfo is Map && videoInfo.containsKey('duration')) {
          segmentDuration = (videoInfo['duration'] as num).toDouble();
        }
      }

      final duration = Duration(milliseconds: (segmentDuration * 1000).round());
      _segmentDurations.add(duration);
      currentTime += duration;
    }

    _virtualTotalDuration = currentTime;
  }

  void _updateVirtualGlobalPosition() {
    // 总进度 = Σ(前N段时长) + 当前段播放位置
    if (_segmentStartTimes.isNotEmpty && _currentSegmentIndex < _segmentStartTimes.length) {
      final segmentStartTime = _segmentStartTimes[_currentSegmentIndex];

      // 确保当前段位置不超过该段的时长
      final maxSegmentPosition = _currentSegmentIndex < _segmentDurations.length
          ? _segmentDurations[_currentSegmentIndex]
          : Duration(seconds: 60);

      final clampedSegmentPosition = Duration(
        milliseconds: _currentSegmentPosition.inMilliseconds.clamp(0, maxSegmentPosition.inMilliseconds)
      );

      _globalPosition = segmentStartTime + clampedSegmentPosition;

      // 确保全局位置不超过虚拟总时长
      _globalPosition = Duration(
        milliseconds: _globalPosition.inMilliseconds.clamp(0, _virtualTotalDuration.inMilliseconds)
      );
    } else {
      _globalPosition = Duration.zero;
    }
  }

  Future<void> _playNextSegment() async {
    if (_routeDetail != null && _currentSegmentIndex < _routeDetail!.segments.length - 1) {
      final nextIndex = _currentSegmentIndex + 1;
      print('🎬 切换到下一段: $nextIndex');
      await _playSegment(nextIndex);
    } else {
      print('🎬 已经是最后一段，无法切换到下一段');
    }
  }

  /// 跳转到指定的虚拟全局时间位置（时:分:秒）
  Future<void> seekToTime(int hours, int minutes, int seconds) async {
    final targetTime = Duration(hours: hours, minutes: minutes, seconds: seconds);
    await _seekToVirtualGlobalPosition(targetTime);
  }

  /// 根据全局时间（秒）找到目标段和段内时间
  Map<String, dynamic>? _findTargetSegmentAndTime(double globalSeconds) {
    if (_segmentDurations.isEmpty) return null;

    print('🔍 查找目标段: 全局时间 ${globalSeconds.toStringAsFixed(3)}s');
    print('🔍 段数量: ${_segmentDurations.length}');

    double accumulatedSeconds = 0.0;

    for (int i = 0; i < _segmentDurations.length; i++) {
      final segmentSeconds = _segmentDurations[i].inMilliseconds / 1000.0;
      final segmentStartTime = accumulatedSeconds;
      final segmentEndTime = accumulatedSeconds + segmentSeconds;

      print('🔍 段 $i: ${segmentStartTime.toStringAsFixed(3)}s - ${segmentEndTime.toStringAsFixed(3)}s (时长: ${segmentSeconds.toStringAsFixed(3)}s)');

      // 检查目标时间是否在当前段内
      // 对于最后一段，允许等于结束时间
      final isInSegment = (i == _segmentDurations.length - 1)
          ? (globalSeconds >= segmentStartTime && globalSeconds <= segmentEndTime)
          : (globalSeconds >= segmentStartTime && globalSeconds < segmentEndTime);

      if (isInSegment) {
        final segmentTime = globalSeconds - segmentStartTime;
        // 确保段内时间不超过段的实际时长
        final clampedSegmentTime = segmentTime.clamp(0.0, segmentSeconds);

        print('✅ 找到目标段 $i: 全局${globalSeconds.toStringAsFixed(3)}s -> 段内${clampedSegmentTime.toStringAsFixed(3)}s');
        print('✅ 段范围: ${segmentStartTime.toStringAsFixed(3)}s - ${segmentEndTime.toStringAsFixed(3)}s');

        return {
          'segmentIndex': i,
          'segmentTime': clampedSegmentTime,
          'segmentDuration': segmentSeconds,
        };
      }

      accumulatedSeconds += segmentSeconds;
    }

    // 如果超出范围，返回最后一段的末尾
    final lastSegmentIndex = _segmentDurations.length - 1;
    final lastSegmentSeconds = _segmentDurations[lastSegmentIndex].inMilliseconds / 1000.0;

    return {
      'segmentIndex': lastSegmentIndex,
      'segmentTime': lastSegmentSeconds,
      'segmentDuration': lastSegmentSeconds,
    };
  }

  /// 跳转到指定段的指定时间
  Future<void> _seekToSpecificSegmentAndTime(int targetSegmentIndex, double segmentTimeSeconds) async {
    if (targetSegmentIndex < 0 || targetSegmentIndex >= _segmentDurations.length) {
      print('❌ 目标段索引无效: $targetSegmentIndex');
      return;
    }

    final segmentTime = Duration(milliseconds: (segmentTimeSeconds * 1000).round());
    final maxSegmentTime = _segmentDurations[targetSegmentIndex];
    final clampedSegmentTime = Duration(
      milliseconds: segmentTime.inMilliseconds.clamp(0, maxSegmentTime.inMilliseconds)
    );

    print('🎯 跳转到段 $targetSegmentIndex, 时间: ${_formatDuration(clampedSegmentTime)}');

    _isSeekingToPosition = true;

    try {
      if (targetSegmentIndex != _currentSegmentIndex) {
        print('🔄 切换段并跳转: $targetSegmentIndex');
        await _playSegment(targetSegmentIndex, seekToPosition: clampedSegmentTime, autoPlay: false);
      } else {
        print('⏭️ 同段内跳转到时间: ${_formatDuration(clampedSegmentTime)}');
        await _player.seek(clampedSegmentTime);
        setState(() {
          _currentSegmentPosition = clampedSegmentTime;
        });
        _updateVirtualGlobalPosition();
      }

    } catch (e) {
      print('❌ 跳转失败: $e');
    } finally {
      _isSeekingToPosition = false;
    }
  }

  /// 跳转到指定的虚拟全局时间位置（保留旧方法作为备用）
  Future<void> _seekToVirtualGlobalPosition(Duration targetTime) async {
    if (_virtualTotalDuration == Duration.zero) return;

    // 限制目标时间在有效范围内
    targetTime = Duration(
      milliseconds: targetTime.inMilliseconds.clamp(0, _virtualTotalDuration.inMilliseconds)
    );

    print('🎯 跳转到虚拟位置: ${_formatDuration(targetTime)} / ${_formatDuration(_virtualTotalDuration)}');

    // 反向定位：遍历视频段累加时长，找到目标段
    int targetSegmentIndex = 0;
    Duration segmentStartTime = Duration.zero;
    Duration accumulatedTime = Duration.zero;

    for (int i = 0; i < _segmentDurations.length; i++) {
      final segmentEndTime = accumulatedTime + _segmentDurations[i];

      if (targetTime >= accumulatedTime && targetTime <= segmentEndTime) {
        targetSegmentIndex = i;
        segmentStartTime = accumulatedTime;
        break;
      }
      accumulatedTime += _segmentDurations[i];
    }

    // 如果目标时间等于总时长，定位到最后一段的末尾
    if (targetTime >= _virtualTotalDuration) {
      targetSegmentIndex = _segmentDurations.length - 1;
      segmentStartTime = _segmentStartTimes.last;
    }

    final segmentPosition = targetTime - segmentStartTime;

    // 确保段内位置不超过该段的时长
    final maxSegmentPosition = targetSegmentIndex < _segmentDurations.length
        ? _segmentDurations[targetSegmentIndex]
        : Duration(seconds: 60);
    final clampedSegmentPosition = Duration(
      milliseconds: segmentPosition.inMilliseconds.clamp(0, maxSegmentPosition.inMilliseconds)
    );

    print('🎯 目标段: $targetSegmentIndex, 段内位置: ${_formatDuration(clampedSegmentPosition)}');

    _isSeekingToPosition = true;

    try {
      if (targetSegmentIndex != _currentSegmentIndex) {
        // 切换到目标段并直接跳转到指定位置
        print('🔄 切换到段 $targetSegmentIndex 并跳转到位置: ${_formatDuration(clampedSegmentPosition)}');
        await _playSegment(targetSegmentIndex, seekToPosition: clampedSegmentPosition, autoPlay: false);
      } else {
        // 同段内跳转
        print('⏭️ 同段内跳转到位置: ${_formatDuration(clampedSegmentPosition)}');
        await _player.seek(clampedSegmentPosition);
        setState(() {
          _currentSegmentPosition = clampedSegmentPosition;
        });
        _updateVirtualGlobalPosition();
      }

    } catch (e) {
      print('❌ 跳转失败: $e');
    } finally {
      _isSeekingToPosition = false;
    }
  }

  Future<void> _playSegment(int index, {Duration? seekToPosition, bool autoPlay = true}) async {
    if (_routeDetail == null || index < 0 || index >= _routeDetail!.segments.length) return;

    setState(() {
      _currentSegmentIndex = index;
      _isLoading = true;
      _error = null;
      _currentSegmentPosition = seekToPosition ?? Duration.zero; // 设置段内位置
    });

    final segment = _routeDetail!.segments[index];
    final provider = context.read<SimpleDashcamProvider>();
    final videoUrl = provider.apiService.getRawVideoUrl(segment.segmentId, _currentCamera.value);

    print('🎬 使用摄像头: $_currentCamera, URL: $videoUrl');
    if (seekToPosition != null) {
      print('🎯 将跳转到段内位置: ${_formatDuration(seekToPosition)}');
    }

    try {
      await _player.open(Media(videoUrl));

      // 如果指定了跳转位置，先跳转再播放
      if (seekToPosition != null) {
        print('⏭️ 跳转到指定位置: ${_formatDuration(seekToPosition)}');
        await _player.seek(seekToPosition);
        await Future.delayed(const Duration(milliseconds: 100)); // 等待跳转完成
      }

      // 根据autoPlay参数决定是否自动播放
      if (autoPlay) {
        await _player.play();
      }

      setState(() {
        _isLoading = false;
      });

      // 更新全局位置
      _updateVirtualGlobalPosition();

      print('✅ 成功切换到段 $index${seekToPosition != null ? "，位置: ${_formatDuration(seekToPosition)}" : ""}');
    } catch (e) {
      setState(() {
        _error = '播放失败: $e';
        _isLoading = false;
      });
      print('❌ 播放段 $index 失败: $e');
    }
  }



  void _playPreviousSegment() {
    if (_currentSegmentIndex > 0) {
      _playSegment(_currentSegmentIndex - 1);
    }
  }

  void _togglePlayPause() {
    try {
      if (_isPlaying) {
        _player.pause();
        print('⏸️ 暂停播放');
      } else {
        _player.play();
        print('▶️ 开始播放');
      }
    } catch (e) {
      print('❌ 播放/暂停操作失败: $e');
      setState(() {
        _error = '播放器错误，请重试';
      });
    }
  }

  void _toggleAutoPlay() {
    setState(() {
      _autoPlay = !_autoPlay;
    });
    print('🔄 自动播放: ${_autoPlay ? "开启" : "关闭"}');
  }

  void _switchCamera(CameraType camera) {
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

            // 移除中心控制按钮，改为在进度条下方显示
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
        controls: NoVideoControls, // 完全隐藏默认控制栏
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

  /// 构建播放控制按钮（在进度条下方）
  Widget _buildPlaybackControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 上一段
          _buildControlButton(
            icon: Icons.skip_previous,
            onPressed: _currentSegmentIndex > 0 ? _playPreviousSegment : null,
            tooltip: '上一段',
          ),

          // 播放/暂停
          _buildControlButton(
            icon: _isPlaying ? Icons.pause : Icons.play_arrow,
            onPressed: _togglePlayPause,
            tooltip: _isPlaying ? '暂停' : '播放',
            isLarge: true,
          ),

          // 下一段
          _buildControlButton(
            icon: Icons.skip_next,
            onPressed: _routeDetail != null && _currentSegmentIndex < _routeDetail!.segments.length - 1
                ? _playNextSegment
                : null,
            tooltip: '下一段',
          ),

          // 自动播放
          _buildControlButton(
            icon: _autoPlay ? Icons.repeat : Icons.repeat_outlined,
            onPressed: _toggleAutoPlay,
            tooltip: _autoPlay ? '关闭自动播放' : '开启自动播放',
            isActive: _autoPlay,
          ),

          // 刷新
          _buildControlButton(
            icon: Icons.refresh,
            onPressed: () => _playSegment(_currentSegmentIndex),
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  /// 构建单个控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isLarge = false,
    bool isActive = false,
  }) {
    final size = isLarge ? 50.0 : 40.0;
    final iconSize = isLarge ? 28.0 : 20.0;

    return Tooltip(
      message: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.blue.withOpacity(0.8)
              : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(size / 2),
          border: isActive
              ? Border.all(color: Colors.blue, width: 2)
              : null,
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
          ),
          padding: EdgeInsets.zero,
        ),
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
            // Segment progress bar
            if (_routeDetail != null)
              _buildSegmentProgressBar(),

            const SizedBox(height: 12),

            // 播放控制按钮（在进度条下方）
            if (_routeDetail != null)
              _buildPlaybackControls(),

            const SizedBox(height: 16),

            // 时间信息和跳转
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 当前时间 / 虚拟总时长
                StreamBuilder<Duration>(
                  stream: _player.stream.position,
                  builder: (context, snapshot) {
                    _updateVirtualGlobalPosition();
                    // 根据状态决定显示的时间
                    final displayTime = _isDragging ? _dragPosition : _globalPosition;
                    return Text(
                      '${_formatDuration(displayTime)} / ${_formatDuration(_virtualTotalDuration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),

                // 时间跳转按钮
//                 ElevatedButton.icon(
//                   onPressed: () => _showTimeSeekDialog(),
//                   icon: const Icon(Icons.access_time, size: 18),
//                   label: const Text('跳转'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue[600],
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                   ),
//                 ),
              ],
            ),

            const SizedBox(height: 8),

            // Segment info
            if (_routeDetail != null && _routeDetail!.segments.isNotEmpty)
              Text(
                '段 ${_currentSegmentIndex + 1}/${_routeDetail!.segments.length} - ${_formatDateTime(_routeDetail!.segments[_currentSegmentIndex].timestamp)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),

            const SizedBox(height: 16),

            // Camera selection
            if (_routeDetail != null && _routeDetail!.availableCameras.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _routeDetail!.availableCameras.map((camera) {
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
                        camera.displayName,
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

  Widget _buildSegmentProgressBar() {
    print('🎯 构建进度条: _videoSegmentsData=${_videoSegmentsData != null}, _virtualTotalDuration=${_virtualTotalDuration.inMilliseconds}ms');

    if (_videoSegmentsData == null || _virtualTotalDuration == Duration.zero) {
      return Container(
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.7), // 改为红色便于调试
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '加载中...',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                'Data: ${_videoSegmentsData != null}, Duration: ${_virtualTotalDuration.inMilliseconds}ms',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 开始时间标记行（进度条上方）
          _buildStartTimeMarkers(),

          // 动态时间提示（仅在拖动时显示）
          if (_isDragging) _buildDynamicTimeHint(),

          const SizedBox(height: 4),

          // 主进度条 - 显示总播放进度
          Container(
            height: 60,
            child: StreamBuilder<Duration>(
              stream: _player.stream.position,
              builder: (context, snapshot) {
                _updateVirtualGlobalPosition();
                final progress = _virtualTotalDuration.inMilliseconds > 0
                    ? _globalPosition.inMilliseconds / _virtualTotalDuration.inMilliseconds
                    : 0.0;

                // 根据状态决定显示的位置
                final displayPosition = _isDragging ? _dragPosition : _globalPosition;
                final displayProgress = _virtualTotalDuration.inMilliseconds > 0
                    ? displayPosition.inMilliseconds / _virtualTotalDuration.inMilliseconds
                    : 0.0;

                // 详细调试信息（每秒打印一次）
                if (DateTime.now().millisecondsSinceEpoch % 1000 < 100) {
                  final statusText = _isDragging ? '拖动中' : (_isSeekingToPosition ? '跳转中' : '播放中');
                  final currentSegmentSeconds = _currentSegmentPosition.inMilliseconds / 1000.0;
                  final globalSeconds = _globalPosition.inMilliseconds / 1000.0;
                  final displaySeconds = displayPosition.inMilliseconds / 1000.0;

                  print('📊 进度条详细状态:');
                  print('   状态: $statusText');
                  print('   当前段: $_currentSegmentIndex');
                  print('   段内时间: ${currentSegmentSeconds.toStringAsFixed(3)}s');
                  print('   实际全局时间: ${globalSeconds.toStringAsFixed(3)}s');
                  print('   显示全局时间: ${displaySeconds.toStringAsFixed(3)}s');
                  print('   实际进度: ${(progress * 100).toStringAsFixed(2)}%');
                  print('   显示进度: ${(displayProgress * 100).toStringAsFixed(2)}%');
                  if (_isDragging) {
                    final dragSeconds = _dragPosition.inMilliseconds / 1000.0;
                    print('   拖动目标: ${dragSeconds.toStringAsFixed(3)}s');

                    // 实时显示拖动目标的段计算
                    final dragResult = _findTargetSegmentAndTime(dragSeconds);
                    if (dragResult != null) {
                      print('   拖动目标段: ${dragResult['segmentIndex']}, 段内: ${dragResult['segmentTime'].toStringAsFixed(3)}s');
                    }
                  }
                }

                return GestureDetector(
                  onTapDown: (details) => _onProgressBarTap(details),
                  onPanStart: (details) => _onProgressBarDragStart(details),
                  onPanUpdate: (details) => _onProgressBarDragUpdate(details),
                  onPanEnd: (details) => _onProgressBarDragEnd(details),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        // 背景 - 显示每段视频的缩略图
                        Row(
                          children: [
                            for (int i = 0; i < _segmentDurations.length; i++)
                              Expanded(
                                flex: _segmentDurations[i].inMilliseconds,
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: _getSegmentColor(i),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: _buildSegmentThumbnail(i),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // 播放进度覆盖层
                        FractionallySizedBox(
                          widthFactor: displayProgress.clamp(0.0, 1.0),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.8),
                                  Colors.blue.withOpacity(0.6),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),

                        // 拖动时的时间提示
                        if (_isDragging)
                          Positioned(
                            left: (displayProgress.clamp(0.0, 1.0) * (MediaQuery.of(context).size.width - 32)) - 40,
                            top: -35,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatDuration(_dragPosition),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  // 显示目标段信息
                                  Builder(
                                    builder: (context) {
                                      final dragSeconds = _dragPosition.inMilliseconds / 1000.0;
                                      final result = _findTargetSegmentAndTime(dragSeconds);
                                      if (result != null) {
                                        final segmentIndex = result['segmentIndex'] as int;
                                        return Text(
                                          '段${segmentIndex + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Loading状态提示
                        if (_isSeekingToPosition && !_isDragging)
                          Positioned(
                            left: (displayProgress.clamp(0.0, 1.0) * (MediaQuery.of(context).size.width - 32)) - 20,
                            top: -25,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Loading...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // 播放位置指示器
                        Positioned(
                          left: (displayProgress.clamp(0.0, 1.0) * (MediaQuery.of(context).size.width - 32)) - 8,
                          top: 0,
                          child: Container(
                            width: 16,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _isDragging
                                  ? Colors.orange
                                  : _isSeekingToPosition
                                      ? Colors.purple
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 4),

          // 结束时间标记行（进度条下方）
//           _buildEndTimeMarkers(),

          const SizedBox(height: 8),

          // 段信息显示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '段 ${_currentSegmentIndex + 1}/${_routeDetail!.segments.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDateTime(_routeDetail!.segments[_currentSegmentIndex].timestamp),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建动态时间提示（拖动时显示）
  Widget _buildDynamicTimeHint() {
    if (!_isDragging) return const SizedBox.shrink();

    // 计算拖动位置对应的segment和时间
    final dragSeconds = _dragPosition.inMilliseconds / 1000.0;
    final result = _findTargetSegmentAndTime(dragSeconds);

    if (result == null) return const SizedBox.shrink();

    final segmentIndex = result['segmentIndex'] as int;
    final segment = _routeDetail!.segments[segmentIndex];
    final segmentTime = result['segmentTime'] as double;

    // 计算实际时间
    final baseTime = DateTime.parse(segment.timestamp);
    final actualTime = baseTime.add(Duration(milliseconds: (segmentTime * 1000).round()));

    return Container(
      height: 30,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '段${segmentIndex + 1} - ${DateFormat('MM-dd HH:mm:ss').format(actualTime)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 构建开始时间标记行（进度条上方）
  Widget _buildStartTimeMarkers() {
    if (_routeDetail == null || _routeDetail!.segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 25,
      child: Stack(
        children: _buildStartTimeMarkerWidgets(),
      ),
    );
  }

  /// 构建结束时间标记行（进度条下方）
  Widget _buildEndTimeMarkers() {
    if (_routeDetail == null || _routeDetail!.segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 25,
      child: Stack(
        children: _buildEndTimeMarkerWidgets(),
      ),
    );
  }

  /// 构建开始时间标记组件列表
  List<Widget> _buildStartTimeMarkerWidgets() {
    List<Widget> markers = [];

    final segmentCount = _routeDetail!.segments.length;
    print('🔄 _buildStartTimeMarkerWidgets 被调用，segments数量: $segmentCount');

    // 智能显示策略：6个以内全显示，超过6个才采样
    final maxMarkers = 6;
    final needSampling = segmentCount > maxMarkers;
    final step = needSampling ? (segmentCount / maxMarkers).ceil() : 1;

    if (needSampling) {
      print('📱 移动端优化：segments过多($segmentCount个)，每${step}个显示一个时间标记');
    } else {
      print('📱 segments数量适中($segmentCount个)，全部显示时间标记');
    }

    // 显示时间标记
    for (int i = 0; i < segmentCount; i += step) {
      if (i < _segmentStartTimes.length) {
        final segment = _routeDetail!.segments[i];
        final startTime = _segmentStartTimes[i];

        // 开始时间就是segment的timestamp
        final actualStartTime = DateTime.parse(segment.timestamp);

        // 计算开始位置在进度条中的比例
        final startPosition = _virtualTotalDuration.inMilliseconds > 0
            ? startTime.inMilliseconds / _virtualTotalDuration.inMilliseconds
            : 0.0;

        final progressBarWidth = MediaQuery.of(context).size.width - 32; // 减去margin

        print('🟢 Segment $i 开始时间: ${DateFormat('MM-dd HH:mm:ss').format(actualStartTime)} at ${(startPosition * 100).toStringAsFixed(2)}%');

        // 添加开始时间标记（绿色，向上显示）
        markers.add(
          Positioned(
            left: startPosition * progressBarWidth,
            bottom: 0, // 贴底部，向上显示
            child: _buildTimeMarker(actualStartTime, isStart: true, isAbove: true),
          ),
        );
      }
    }

    return markers;
  }

  /// 构建结束时间标记组件列表
  List<Widget> _buildEndTimeMarkerWidgets() {
    List<Widget> markers = [];

    final segmentCount = _routeDetail!.segments.length;
    print('🔄 _buildEndTimeMarkerWidgets 被调用，segments数量: $segmentCount');

    // 智能显示策略：6个以内全显示，超过6个才采样
    final maxMarkers = 6;
    final needSampling = segmentCount > maxMarkers;
    final step = needSampling ? (segmentCount / maxMarkers).ceil() : 1;

    // 确定要显示的segment索引
    final indicesToShow = <int>[];

    if (needSampling) {
      // 需要采样：显示关键的结束时间点
      for (int i = step - 1; i < segmentCount; i += step) {
        indicesToShow.add(i);
      }
      // 确保最后一个segment的结束时间总是显示
      if (!indicesToShow.contains(segmentCount - 1)) {
        indicesToShow.add(segmentCount - 1);
      }
      print('📱 结束时间采样显示: ${indicesToShow.map((i) => i + 1).toList()}');
    } else {
      // 不需要采样：显示所有结束时间
      for (int i = 0; i < segmentCount; i++) {
        indicesToShow.add(i);
      }
      print('📱 显示所有结束时间: ${indicesToShow.length}个');
    }

    for (int i in indicesToShow) {
      if (i < _segmentStartTimes.length) {
        final segment = _routeDetail!.segments[i];

        // 结束时间是开始时间加上segment的duration
        final actualEndTime = DateTime.parse(segment.timestamp).add(Duration(seconds: segment.duration));

        // 计算结束位置在进度条中的比例
        // 结束位置应该是当前段开始时间 + 当前段的实际播放时长
        final startTime = _segmentStartTimes[i];
        final segmentDuration = _segmentDurations[i]; // 使用实际的segment duration
        final endTimeInVirtual = Duration(milliseconds: startTime.inMilliseconds + segmentDuration.inMilliseconds);

        final endPosition = _virtualTotalDuration.inMilliseconds > 0
            ? endTimeInVirtual.inMilliseconds / _virtualTotalDuration.inMilliseconds
            : 0.0;

        final progressBarWidth = MediaQuery.of(context).size.width - 32; // 减去margin

        print('🔴 Segment $i 结束时间: ${DateFormat('MM-dd HH:mm:ss').format(actualEndTime)} at ${(endPosition * 100).toStringAsFixed(2)}%');
        print('   虚拟开始: ${startTime.inMilliseconds}ms, 段时长: ${segmentDuration.inMilliseconds}ms, 虚拟结束: ${endTimeInVirtual.inMilliseconds}ms');

        // 添加结束时间标记（红色，向下显示）
        if (i == _routeDetail!.segments.length - 1) {
          // 最后一段的结束时间标记，使用right定位确保可见
          markers.add(
            Positioned(
              right: 0,
              top: 0, // 贴顶部，向下显示
              child: _buildTimeMarker(actualEndTime, isStart: false, isAbove: false),
            ),
          );
        } else {
          markers.add(
            Positioned(
              left: endPosition * progressBarWidth,
              top: 0, // 贴顶部，向下显示
              child: _buildTimeMarker(actualEndTime, isStart: false, isAbove: false),
            ),
          );
        }
      }
    }

    return markers;
  }

  /// 构建单个时间标记
  Widget _buildTimeMarker(DateTime time, {required bool isStart, required bool isAbove}) {
    final timeStr = DateFormat('MM-dd HH:mm:ss').format(time);
    final typeStr = isStart ? '开始(绿)' : '结束(红)';
    final positionStr = isAbove ? '上方' : '下方';
    print('   🎯 创建时间标记: $typeStr - $timeStr - $positionStr');

    // 根据位置决定组件顺序
    final children = <Widget>[
      // 时间文本
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isStart ? Colors.green : Colors.red,
            width: 1,
          ),
        ),
        child: Text(
          timeStr,
          style: TextStyle(
            fontSize: 9, // 稍微减小字体以适应新布局
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: isStart ? Colors.green : Colors.red,
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ),
      // 时间刻度线
      Container(
        width: 2,
        height: 8, // 减小高度以适应新布局
        color: isStart ? Colors.green : Colors.red,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: isAbove ? children.reversed.toList() : children,
    );
  }

  Widget _buildSegmentThumbnail(int index) {
    if (_videoSegmentsData == null) {
      return Container(
        color: _getSegmentColor(index),
        child: const Icon(
          Icons.video_library,
          color: Colors.white,
          size: 20,
        ),
      );
    }

    final segments = _videoSegmentsData!['segments'] as List;
    if (index >= segments.length) {
      return Container(
        color: _getSegmentColor(index),
        child: const Icon(
          Icons.video_library,
          color: Colors.white,
          size: 20,
        ),
      );
    }

    final segment = segments[index];
    final cameras = segment['cameras'] as Map<String, dynamic>;

    if (cameras.containsKey(_currentCamera.value)) {
      final cameraInfo = cameras[_currentCamera.value];
      final thumbnailUrl = cameraInfo['thumbnail'];

      if (thumbnailUrl != null) {
        return Image.network(
          'http://localhost:8009$thumbnailUrl',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: _getSegmentColor(index),
              child: const Icon(
                Icons.video_library,
                color: Colors.white,
                size: 20,
              ),
            );
          },
        );
      }
    }

    return Container(
      color: _getSegmentColor(index),
      child: const Icon(
        Icons.video_library,
        color: Colors.white,
        size: 20,
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  void _showTimeSeekDialog() {
    final hoursController = TextEditingController();
    final minutesController = TextEditingController();
    final secondsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳转到指定时间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('总时长: ${_formatDuration(_virtualTotalDuration)}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hoursController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '时',
                      hintText: '0',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(':'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '分',
                      hintText: '0',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(':'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: secondsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '秒',
                      hintText: '0',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final hours = int.tryParse(hoursController.text) ?? 0;
              final minutes = int.tryParse(minutesController.text) ?? 0;
              final seconds = int.tryParse(secondsController.text) ?? 0;

              Navigator.of(context).pop();
              seekToTime(hours, minutes, seconds);
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  /// 进度条点击处理
  void _onProgressBarTap(TapDownDetails details) {
    print('🎯 进度条点击');
    _handleProgressBarInteraction(details.localPosition, isClick: true);
  }

  /// 开始拖动进度条
  void _onProgressBarDragStart(DragStartDetails details) {
    print('🎯 开始拖动进度条');
    _handleProgressBarInteraction(details.localPosition, isDragStart: true);
  }

  /// 拖动进度条中
  void _onProgressBarDragUpdate(DragUpdateDetails details) {
    if (_isDragging) {
      _handleProgressBarInteraction(details.localPosition, isDragUpdate: true);
    }
  }

  /// 结束拖动进度条
  void _onProgressBarDragEnd(DragEndDetails details) {
    print('🎯 结束拖动进度条');
    // DragEndDetails 没有 localPosition，使用当前拖动位置
    _endDragging(_dragPosition);
  }

  /// 统一的进度条交互处理方法
  void _handleProgressBarInteraction(
    Offset localPosition, {
    bool isClick = false,
    bool isDragStart = false,
    bool isDragUpdate = false,
  }) {
    if (_virtualTotalDuration == Duration.zero || _segmentDurations.isEmpty) {
      print('❌ 虚拟总时长为0或段时长为空，无法处理进度条交互');
      return;
    }

    // 获取进度条的宽度（减去边距）
    final progressBarWidth = MediaQuery.of(context).size.width - 32;
    if (progressBarWidth <= 0) {
      print('❌ 进度条宽度无效: $progressBarWidth');
      return;
    }

    // 计算位置比例
    final position = (localPosition.dx / progressBarWidth).clamp(0.0, 1.0);
    final targetGlobalSeconds = (_virtualTotalDuration.inMilliseconds * position) / 1000.0;
    final targetGlobalTime = Duration(milliseconds: (targetGlobalSeconds * 1000).round());

    print('🎯 进度条交互: 位置${(position * 100).toStringAsFixed(1)}%, 目标时间${_formatDuration(targetGlobalTime)}');

    if (isDragStart) {
      _startDragging(targetGlobalTime);
    } else if (isDragUpdate) {
      _updateDragPosition(targetGlobalTime);
    } else if (isClick) {
      _handleClick(targetGlobalTime);
    }
  }

  /// 跳转到全局时间（带加载等待）
  Future<void> _seekToGlobalTimeWithLoading(Duration globalTime) async {
    final targetGlobalSeconds = globalTime.inMilliseconds / 1000.0;
    final result = _findTargetSegmentAndTime(targetGlobalSeconds);

    if (result == null) {
      print('❌ 无法找到目标段');
      return;
    }

    final targetSegmentIndex = result['segmentIndex'] as int;
    final targetSegmentTime = result['segmentTime'] as double;
    final segmentDuration = Duration(milliseconds: (targetSegmentTime * 1000).round());

    print('🎯 跳转分析: 段$targetSegmentIndex, 段内时间${_formatDuration(segmentDuration)}');

    try {
      // 如果需要切换段
      if (targetSegmentIndex != _currentSegmentIndex) {
        print('🔄 需要切换段: 当前段$_currentSegmentIndex -> 目标段$targetSegmentIndex');

        // 切换段并直接跳转到指定位置，不自动播放
        await _playSegment(targetSegmentIndex, seekToPosition: segmentDuration, autoPlay: false);

        // 等待视频加载完成
        print('⏳ 等待视频加载...');
        await Future.delayed(const Duration(milliseconds: 500));

        // 检查是否加载成功
        int retryCount = 0;
        while (_isLoading && retryCount < 10) {
          await Future.delayed(const Duration(milliseconds: 100));
          retryCount++;
          print('⏳ 等待加载完成... ($retryCount/10)');
        }

        if (_isLoading) {
          print('⚠️ 视频加载超时，但继续尝试跳转');
        } else {
          print('✅ 视频加载完成');
        }

        // 验证段切换是否成功
        if (_currentSegmentIndex != targetSegmentIndex) {
          print('❌ 段切换失败: 期望段$targetSegmentIndex, 实际段$_currentSegmentIndex');
          return;
        } else {
          print('✅ 段切换成功: 当前段$_currentSegmentIndex');
        }
      } else {
        // 同一段内跳转
        print('⏭️ 同段内跳转到时间: ${_formatDuration(segmentDuration)} (${segmentDuration.inMilliseconds}ms)');

        try {
          await _player.seek(segmentDuration);

          // 等待跳转完成
          await Future.delayed(const Duration(milliseconds: 200));

          // 更新状态
          setState(() {
            _currentSegmentPosition = segmentDuration;
          });
          _updateVirtualGlobalPosition();
        } catch (e) {
          print('❌ 同段内跳转失败: $e');
        }
      }

      print('✅ 跳转操作完成');
    } catch (e) {
      print('❌ 跳转失败: $e');
    }
  }

  /// 开始拖动
  void _startDragging(Duration targetTime) {
    setState(() {
      _isDragging = true;
      _wasPlayingBeforeDrag = _isPlaying;
      _dragPosition = targetTime;
    });

    // 立即暂停播放
    if (_isPlaying) {
      _player.pause();
      print('⏸️ 拖动开始，暂停播放');
    }
  }

  /// 更新拖动位置
  void _updateDragPosition(Duration targetTime) {
    if (!_isDragging) return;

    setState(() {
      _dragPosition = targetTime;
    });

    final dragSeconds = targetTime.inMilliseconds / 1000.0;
    final dragProgress = _virtualTotalDuration.inMilliseconds > 0
        ? targetTime.inMilliseconds / _virtualTotalDuration.inMilliseconds
        : 0.0;

    print('🎯 拖动更新: ${dragSeconds.toStringAsFixed(3)}s, 进度${(dragProgress * 100).toStringAsFixed(1)}%');
  }

  /// 结束拖动
  void _endDragging(Duration targetTime) async {
    if (!_isDragging) {
      print('⚠️ 拖动已结束，忽略重复调用');
      return;
    }

    print('🎯 拖动结束，开始跳转到: ${_formatDuration(targetTime)}');

    setState(() {
      _isDragging = false;
      _isSeekingToPosition = true;
    });

    try {
      // 执行跳转
      await _seekToGlobalTimeWithLoading(targetTime);

      print('✅ 拖动跳转完成');

      // 恢复播放状态
      if (_wasPlayingBeforeDrag) {
        try {
          await _player.play();
          print('▶️ 拖动完成，恢复播放');
        } catch (e) {
          print('❌ 恢复播放失败: $e');
        }
      }

    } catch (e) {
      print('❌ 拖动跳转失败: $e');
    } finally {
      // 确保状态被重置
      if (mounted) {
        setState(() {
          _isSeekingToPosition = false;
        });
      }
    }
  }

  /// 处理点击
  void _handleClick(Duration targetTime) async {
    print('🎯 点击跳转到: ${_formatDuration(targetTime)}');

    // 暂停播放
    final wasPlaying = _isPlaying;
    if (_isPlaying) {
      try {
        _player.pause();
        print('⏸️ 点击时暂停播放');
      } catch (e) {
        print('⚠️ 暂停播放失败: $e');
      }
    }

    setState(() {
      _isSeekingToPosition = true;
    });

    try {
      // 执行跳转
      await _seekToGlobalTimeWithLoading(targetTime);
      print('✅ 点击跳转完成');

      // 恢复播放状态
      if (wasPlaying) {
        try {
          await _player.play();
          print('▶️ 点击跳转完成，恢复播放');
        } catch (e) {
          print('❌ 恢复播放失败: $e');
        }
      }

    } catch (e) {
      print('❌ 点击跳转失败: $e');
    } finally {
      // 确保状态被重置
      if (mounted) {
        setState(() {
          _isSeekingToPosition = false;
        });
      }
    }
  }

  Color _getSegmentColor(int index) {
    if (index < _currentSegmentIndex) {
      return Colors.green[400]!; // 已播放 - 绿色
    } else if (index == _currentSegmentIndex) {
      return Colors.orange[400]!; // 当前播放 - 橙色
    } else {
      return Colors.grey[600]!; // 未播放 - 灰色
    }
  }

  int _getSegmentDurationMs(int index) {
    if (_routeDetail == null || index >= _routeDetail!.segments.length) {
      return 1000; // 默认1秒
    }

    final segment = _routeDetail!.segments[index];

    // 使用 video_info 中的真实时长，如果没有则使用默认值
    double segmentDuration = segment.duration.toDouble();
    if (segment.videoInfo.isNotEmpty &&
        segment.videoInfo.containsKey(_currentCamera.value)) {
      final videoInfo = segment.videoInfo[_currentCamera.value];
      if (videoInfo is Map && videoInfo.containsKey('duration')) {
        segmentDuration = (videoInfo['duration'] as num).toDouble();
      }
    }

    return (segmentDuration * 1000).round(); // 转换为毫秒
  }
}
