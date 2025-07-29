import 'package:flutter_test/flutter_test.dart';
import '../lib/models/dashcam_models.dart';

void main() {
  group('CameraType Enum Tests', () {
    test('should have correct values', () {
      expect(CameraType.fcamera.value, 'fcamera');
      expect(CameraType.dcamera.value, 'dcamera');
      expect(CameraType.ecamera.value, 'ecamera');
      expect(CameraType.qcamera.value, 'qcamera');
    });

    test('should have correct display names', () {
      expect(CameraType.fcamera.displayName, '前置摄像头');
      expect(CameraType.dcamera.displayName, '驾驶员摄像头');
      expect(CameraType.ecamera.displayName, '侧面摄像头');
      expect(CameraType.qcamera.displayName, '后置摄像头');
    });

    test('should create from string correctly', () {
      expect(CameraType.fromString('fcamera'), CameraType.fcamera);
      expect(CameraType.fromString('dcamera'), CameraType.dcamera);
      expect(CameraType.fromString('ecamera'), CameraType.ecamera);
      expect(CameraType.fromString('qcamera'), CameraType.qcamera);
      expect(CameraType.fromString('invalid'), null);
    });

    test('should serialize to JSON correctly', () {
      final dashcamInfo = DashcamInfo(
        totalRoutes: 10,
        totalSegments: 100,
        totalSize: 1000000,
        availableCameras: [CameraType.fcamera, CameraType.dcamera],
        dateRange: ['2024-01-01', '2024-01-31'],
      );

      final json = dashcamInfo.toJson();
      expect(json['available_cameras'], ['fcamera', 'dcamera']);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'total_routes': 10,
        'total_segments': 100,
        'total_size': 1000000,
        'available_cameras': ['fcamera', 'dcamera'],
        'date_range': ['2024-01-01', '2024-01-31'],
      };

      final dashcamInfo = DashcamInfo.fromJson(json);
      expect(dashcamInfo.availableCameras.length, 2);
      expect(dashcamInfo.availableCameras[0], CameraType.fcamera);
      expect(dashcamInfo.availableCameras[1], CameraType.dcamera);
    });
  });
}
