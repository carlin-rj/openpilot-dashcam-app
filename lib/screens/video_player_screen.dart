import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:universal_platform/universal_platform.dart';

import '../providers/dashcam_provider.dart';
import '../providers/settings_provider.dart';
import '../models/dashcam_models.dart';
import '../utils/theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String segmentId;
  final String camera;

  const VideoPlayerScreen({
    super.key,
    required this.segmentId,
    required this.camera,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  
  SegmentInfo? _segment;
  VideoInfo? _videoInfo;
  bool _isLoading = true;
  bool _isFullscreen = false;
  bool _showControls = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadVideoData();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _initializePlayer() {
    _player = Player();
    _controller = VideoController(_player);
  }

  Future<void> _loadVideoData() async {
    try {
      final provider = context.read<DashcamProvider>();
      final settings = context.read<SettingsProvider>();
      
      // Get segment info
      _segment = await provider.getSegmentDetail(widget.segmentId);
      
      // Get video info
      _videoInfo = await provider.getVideoInfo(widget.segmentId, widget.camera);
      
      if (_segment == null) {
        setState(() {
          _error = '视频段不存在';
          _isLoading = false;
        });
        return;
      }

      // Choose video URL based on settings
      String videoUrl;
      if (settings.preferHevc && _videoInfo?.video?.codec == 'hevc') {
        // Use raw HEVC if supported
        videoUrl = provider.getRawVideoUrl(widget.segmentId, widget.camera);
      } else {
        // Use HLS stream
        videoUrl = provider.getHlsPlaylistUrl(widget.segmentId, widget.camera);
      }

      // Load video
      await _player.open(Media(videoUrl));
      
      // Auto play if enabled
      if (settings.autoPlay) {
        await _player.play();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载视频失败: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (UniversalPlatform.isMobile) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (UniversalPlatform.isMobile) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return _buildFullscreenPlayer();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.camera.toUpperCase()} - ${widget.segmentId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
      body: Column(
        children: [
          // Video player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildVideoPlayer(),
          ),
          
          // Video info
          if (_videoInfo != null) _buildVideoInfo(),
          
          // Segment info
          if (_segment != null) _buildSegmentInfo(),
        ],
      ),
    );
  }

  Widget _buildFullscreenPlayer() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(child: _buildVideoPlayer()),
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: _toggleFullscreen,
                        ),
                        Expanded(
                          child: Text(
                            '${widget.camera.toUpperCase()} - ${widget.segmentId}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadVideoData();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Video(
        controller: _controller,
        controls: AdaptiveVideoControls,
      ),
    );
  }

  Widget _buildVideoInfo() {
    final info = _videoInfo!;
    
    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '视频信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            _buildInfoRow('文件大小', _formatFileSize(info.fileSize)),
            _buildInfoRow('时长', _formatDuration(info.duration)),
            _buildInfoRow('格式', info.formatName),
            if (info.video != null) ...[
              _buildInfoRow('视频编码', info.video!.codec.toUpperCase()),
              _buildInfoRow('分辨率', '${info.video!.width}x${info.video!.height}'),
              _buildInfoRow('帧率', '${info.video!.fps.toStringAsFixed(1)} fps'),
              if (info.video!.bitrate != null)
                _buildInfoRow('比特率', '${(info.video!.bitrate! / 1000).toStringAsFixed(0)} kbps'),
            ],
            if (info.audio != null) ...[
              _buildInfoRow('音频编码', info.audio!.codec.toUpperCase()),
              _buildInfoRow('采样率', '${info.audio!.sampleRate} Hz'),
              _buildInfoRow('声道', '${info.audio!.channels}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentInfo() {
    final segment = _segment!;
    
    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '段信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            _buildInfoRow('路线', segment.routeName),
            _buildInfoRow('段号', segment.segmentNumber.toString()),
            _buildInfoRow('开始时间', _formatDateTime(segment.startTime)),
            _buildInfoRow('结束时间', _formatDateTime(segment.endTime)),
            _buildInfoRow('音频', segment.hasAudio ? '有' : '无'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }
}
