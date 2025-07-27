import 'package:json_annotation/json_annotation.dart';

part 'dashcam_models.g.dart';

@JsonSerializable()
class DashcamInfo {
  @JsonKey(name: 'total_routes')
  final int totalRoutes;

  @JsonKey(name: 'total_segments')
  final int totalSegments;

  @JsonKey(name: 'total_size')
  final int totalSize;

  @JsonKey(name: 'available_cameras')
  final List<String> availableCameras;

  @JsonKey(name: 'date_range')
  final List<String> dateRange;

  const DashcamInfo({
    this.totalRoutes = 0,
    this.totalSegments = 0,
    this.totalSize = 0,
    this.availableCameras = const [],
    this.dateRange = const [],
  });

  factory DashcamInfo.fromJson(Map<String, dynamic> json) =>
      _$DashcamInfoFromJson(json);

  Map<String, dynamic> toJson() => _$DashcamInfoToJson(this);
}

@JsonSerializable()
class RouteInfo {
  @JsonKey(name: 'route_name')
  final String routeName;

  @JsonKey(name: 'start_time')
  final String startTime;

  @JsonKey(name: 'end_time')
  final String endTime;

  @JsonKey(name: 'segment_count')
  final int segmentCount;

  @JsonKey(name: 'total_size')
  final int totalSize;

  @JsonKey(name: 'available_cameras')
  final List<String> availableCameras;

  const RouteInfo({
    this.routeName = '',
    this.startTime = '',
    this.endTime = '',
    this.segmentCount = 0,
    this.totalSize = 0,
    this.availableCameras = const [],
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) =>
      _$RouteInfoFromJson(json);

  Map<String, dynamic> toJson() => _$RouteInfoToJson(this);
}

@JsonSerializable()
class RouteDetailInfo {
  @JsonKey(name: 'route_name')
  final String routeName;

  @JsonKey(name: 'start_time')
  final String startTime;

  @JsonKey(name: 'end_time')
  final String endTime;

  @JsonKey(name: 'segment_count')
  final int segmentCount;

  @JsonKey(name: 'total_size')
  final int totalSize;

  @JsonKey(name: 'available_cameras')
  final List<String> availableCameras;

  final List<SegmentInfo> segments;

  const RouteDetailInfo({
    this.routeName = '',
    this.startTime = '',
    this.endTime = '',
    this.segmentCount = 0,
    this.totalSize = 0,
    this.availableCameras = const [],
    this.segments = const [],
  });

  factory RouteDetailInfo.fromJson(Map<String, dynamic> json) =>
      _$RouteDetailInfoFromJson(json);

  Map<String, dynamic> toJson() => _$RouteDetailInfoToJson(this);
}

@JsonSerializable()
class SegmentInfo {
  @JsonKey(name: 'segment_id')
  final String segmentId;

  @JsonKey(name: 'route_name')
  final String routeName;

  @JsonKey(name: 'segment_num')
  final int segmentNumber;

  final String timestamp;
  final int duration;
  final int size;

  final Map<String, String> cameras;

  @JsonKey(name: 'has_audio')
  final bool hasAudio;

  @JsonKey(name: 'video_info')
  final Map<String, dynamic> videoInfo;

  const SegmentInfo({
    this.segmentId = '',
    this.routeName = '',
    this.segmentNumber = 0,
    this.timestamp = '',
    this.duration = 0,
    this.size = 0,
    this.cameras = const {},
    this.hasAudio = false,
    this.videoInfo = const {},
  });

  // 计算开始时间
  String get startTime => timestamp;

  // 计算结束时间
  String get endTime {
    try {
      final startDateTime = DateTime.parse(timestamp);
      final endDateTime = startDateTime.add(Duration(seconds: duration));
      return endDateTime.toIso8601String();
    } catch (e) {
      return timestamp;
    }
  }

  // 获取单个摄像头的文件大小（估算）
  Map<String, int> get fileSizes {
    final cameraCount = cameras.length;
    if (cameraCount == 0) return {};

    final sizePerCamera = size ~/ cameraCount;
    return Map.fromEntries(
      cameras.keys.map((camera) => MapEntry(camera, sizePerCamera))
    );
  }

  factory SegmentInfo.fromJson(Map<String, dynamic> json) =>
      _$SegmentInfoFromJson(json);

  Map<String, dynamic> toJson() => _$SegmentInfoToJson(this);
}

@JsonSerializable()
class VideoInfo {
  @JsonKey(name: 'segment_id')
  final String segmentId;

  final String camera;

  @JsonKey(name: 'file_size')
  final int fileSize;

  final double duration;

  @JsonKey(name: 'format_name')
  final String formatName;

  @JsonKey(name: 'has_video')
  final bool hasVideo;

  @JsonKey(name: 'has_audio')
  final bool hasAudio;

  final VideoStreamInfo? video;
  final AudioStreamInfo? audio;

  const VideoInfo({
    this.segmentId = '',
    this.camera = '',
    this.fileSize = 0,
    this.duration = 0.0,
    this.formatName = '',
    this.hasVideo = false,
    this.hasAudio = false,
    this.video,
    this.audio,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) =>
      _$VideoInfoFromJson(json);

  Map<String, dynamic> toJson() => _$VideoInfoToJson(this);
}

@JsonSerializable()
class VideoStreamInfo {
  final String codec;
  final int width;
  final int height;
  final double fps;
  final int? bitrate;

  const VideoStreamInfo({
    this.codec = '',
    this.width = 0,
    this.height = 0,
    this.fps = 0.0,
    this.bitrate,
  });

  factory VideoStreamInfo.fromJson(Map<String, dynamic> json) =>
      _$VideoStreamInfoFromJson(json);

  Map<String, dynamic> toJson() => _$VideoStreamInfoToJson(this);
}

@JsonSerializable()
class AudioStreamInfo {
  final String codec;

  @JsonKey(name: 'sample_rate')
  final int sampleRate;

  final int channels;
  final int? bitrate;

  const AudioStreamInfo({
    this.codec = '',
    this.sampleRate = 0,
    this.channels = 0,
    this.bitrate,
  });

  factory AudioStreamInfo.fromJson(Map<String, dynamic> json) =>
      _$AudioStreamInfoFromJson(json);

  Map<String, dynamic> toJson() => _$AudioStreamInfoToJson(this);
}

@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  final bool success;
  final String? error;
  final T? data;
  final int? total;
  final int? page;
  final int? limit;

  const ApiResponse({
    required this.success,
    this.error,
    this.data,
    this.total,
    this.page,
    this.limit,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$ApiResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);
}
