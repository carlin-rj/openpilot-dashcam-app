// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashcam_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashcamInfo _$DashcamInfoFromJson(Map<String, dynamic> json) => DashcamInfo(
  totalRoutes: (json['total_routes'] as num?)?.toInt() ?? 0,
  totalSegments: (json['total_segments'] as num?)?.toInt() ?? 0,
  totalSize: (json['total_size'] as num?)?.toInt() ?? 0,
  availableCameras:
      (json['available_cameras'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$CameraTypeEnumMap, e))
          .toList() ??
      const [],
  dateRange:
      (json['date_range'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$DashcamInfoToJson(DashcamInfo instance) =>
    <String, dynamic>{
      'total_routes': instance.totalRoutes,
      'total_segments': instance.totalSegments,
      'total_size': instance.totalSize,
      'available_cameras': instance.availableCameras
          .map((e) => _$CameraTypeEnumMap[e]!)
          .toList(),
      'date_range': instance.dateRange,
    };

const _$CameraTypeEnumMap = {
  CameraType.fcamera: 'fcamera',
  CameraType.dcamera: 'dcamera',
  CameraType.ecamera: 'ecamera',
  CameraType.qcamera: 'qcamera',
};

RouteInfo _$RouteInfoFromJson(Map<String, dynamic> json) => RouteInfo(
  routeName: json['route_name'] as String? ?? '',
  startTime: json['start_time'] as String? ?? '',
  endTime: json['end_time'] as String? ?? '',
  segmentCount: (json['segment_count'] as num?)?.toInt() ?? 0,
  totalSize: (json['total_size'] as num?)?.toInt() ?? 0,
  availableCameras:
      (json['available_cameras'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$CameraTypeEnumMap, e))
          .toList() ??
      const [],
);

Map<String, dynamic> _$RouteInfoToJson(RouteInfo instance) => <String, dynamic>{
  'route_name': instance.routeName,
  'start_time': instance.startTime,
  'end_time': instance.endTime,
  'segment_count': instance.segmentCount,
  'total_size': instance.totalSize,
  'available_cameras': instance.availableCameras
      .map((e) => _$CameraTypeEnumMap[e]!)
      .toList(),
};

RouteDetailInfo _$RouteDetailInfoFromJson(Map<String, dynamic> json) =>
    RouteDetailInfo(
      routeName: json['route_name'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      segmentCount: (json['segment_count'] as num?)?.toInt() ?? 0,
      totalSize: (json['total_size'] as num?)?.toInt() ?? 0,
      availableCameras:
          (json['available_cameras'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$CameraTypeEnumMap, e))
              .toList() ??
          const [],
      segments:
          (json['segments'] as List<dynamic>?)
              ?.map((e) => SegmentInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$RouteDetailInfoToJson(RouteDetailInfo instance) =>
    <String, dynamic>{
      'route_name': instance.routeName,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'segment_count': instance.segmentCount,
      'total_size': instance.totalSize,
      'available_cameras': instance.availableCameras
          .map((e) => _$CameraTypeEnumMap[e]!)
          .toList(),
      'segments': instance.segments,
    };

SegmentInfo _$SegmentInfoFromJson(Map<String, dynamic> json) => SegmentInfo(
  segmentId: json['segment_id'] as String? ?? '',
  routeName: json['route_name'] as String? ?? '',
  segmentNumber: (json['segment_num'] as num?)?.toInt() ?? 0,
  timestamp: json['timestamp'] as String? ?? '',
  duration: (json['duration'] as num?)?.toInt() ?? 0,
  size: (json['size'] as num?)?.toInt() ?? 0,
  cameras:
      (json['cameras'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry($enumDecode(_$CameraTypeEnumMap, k), e as String),
      ) ??
      const {},
  hasAudio: json['has_audio'] as bool? ?? false,
  videoInfo: json['video_info'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$SegmentInfoToJson(SegmentInfo instance) =>
    <String, dynamic>{
      'segment_id': instance.segmentId,
      'route_name': instance.routeName,
      'segment_num': instance.segmentNumber,
      'timestamp': instance.timestamp,
      'duration': instance.duration,
      'size': instance.size,
      'cameras': instance.cameras.map(
        (k, e) => MapEntry(_$CameraTypeEnumMap[k]!, e),
      ),
      'has_audio': instance.hasAudio,
      'video_info': instance.videoInfo,
    };

VideoInfo _$VideoInfoFromJson(Map<String, dynamic> json) => VideoInfo(
  segmentId: json['segment_id'] as String? ?? '',
  camera:
      $enumDecodeNullable(_$CameraTypeEnumMap, json['camera']) ??
      CameraType.fcamera,
  fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
  duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
  formatName: json['format_name'] as String? ?? '',
  hasVideo: json['has_video'] as bool? ?? false,
  hasAudio: json['has_audio'] as bool? ?? false,
  video: json['video'] == null
      ? null
      : VideoStreamInfo.fromJson(json['video'] as Map<String, dynamic>),
  audio: json['audio'] == null
      ? null
      : AudioStreamInfo.fromJson(json['audio'] as Map<String, dynamic>),
);

Map<String, dynamic> _$VideoInfoToJson(VideoInfo instance) => <String, dynamic>{
  'segment_id': instance.segmentId,
  'camera': _$CameraTypeEnumMap[instance.camera]!,
  'file_size': instance.fileSize,
  'duration': instance.duration,
  'format_name': instance.formatName,
  'has_video': instance.hasVideo,
  'has_audio': instance.hasAudio,
  'video': instance.video,
  'audio': instance.audio,
};

VideoStreamInfo _$VideoStreamInfoFromJson(Map<String, dynamic> json) =>
    VideoStreamInfo(
      codec: json['codec'] as String? ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      fps: (json['fps'] as num?)?.toDouble() ?? 0.0,
      bitrate: (json['bitrate'] as num?)?.toInt(),
    );

Map<String, dynamic> _$VideoStreamInfoToJson(VideoStreamInfo instance) =>
    <String, dynamic>{
      'codec': instance.codec,
      'width': instance.width,
      'height': instance.height,
      'fps': instance.fps,
      'bitrate': instance.bitrate,
    };

AudioStreamInfo _$AudioStreamInfoFromJson(Map<String, dynamic> json) =>
    AudioStreamInfo(
      codec: json['codec'] as String? ?? '',
      sampleRate: (json['sample_rate'] as num?)?.toInt() ?? 0,
      channels: (json['channels'] as num?)?.toInt() ?? 0,
      bitrate: (json['bitrate'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AudioStreamInfoToJson(AudioStreamInfo instance) =>
    <String, dynamic>{
      'codec': instance.codec,
      'sample_rate': instance.sampleRate,
      'channels': instance.channels,
      'bitrate': instance.bitrate,
    };

ApiResponse<T> _$ApiResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => ApiResponse<T>(
  success: json['success'] as bool,
  error: json['error'] as String?,
  data: _$nullableGenericFromJson(json['data'], fromJsonT),
  total: (json['total'] as num?)?.toInt(),
  page: (json['page'] as num?)?.toInt(),
  limit: (json['limit'] as num?)?.toInt(),
);

Map<String, dynamic> _$ApiResponseToJson<T>(
  ApiResponse<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{
  'success': instance.success,
  'error': instance.error,
  'data': _$nullableGenericToJson(instance.data, toJsonT),
  'total': instance.total,
  'page': instance.page,
  'limit': instance.limit,
};

T? _$nullableGenericFromJson<T>(
  Object? input,
  T Function(Object? json) fromJson,
) => input == null ? null : fromJson(input);

Object? _$nullableGenericToJson<T>(
  T? input,
  Object? Function(T value) toJson,
) => input == null ? null : toJson(input);
