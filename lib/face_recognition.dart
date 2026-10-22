import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Produces the 192-dimensional MobileFaceNet vector expected by BaKhi API.
class FaceRecognition {
  static Interpreter? _interpreter;
  static final ImagePicker _picker = ImagePicker();

  static Future<List<double>> captureEmbedding() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 95,
      maxWidth: 1600,
    );
    if (photo == null) throw Exception('Bạn chưa chụp ảnh khuôn mặt.');

    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true,
      ),
    );
    try {
      final faces = await detector.processImage(
        InputImage.fromFilePath(photo.path),
      );
      if (faces.length != 1) {
        throw Exception(
          faces.isEmpty
              ? 'Không tìm thấy khuôn mặt. Hãy chụp lại nơi đủ sáng.'
              : 'Ảnh chỉ được có một khuôn mặt.',
        );
      }
      final decoded = img.decodeImage(await File(photo.path).readAsBytes());
      if (decoded == null) throw Exception('Không đọc được ảnh vừa chụp.');
      final oriented = img.bakeOrientation(decoded);
      final box = faces.single.boundingBox;
      // ML Kit reports image coordinates; clamp defensively before cropping.
      final left = box.left.round().clamp(0, oriented.width - 1).toInt();
      final top = box.top.round().clamp(0, oriented.height - 1).toInt();
      final right = box.right.round().clamp(left + 1, oriented.width).toInt();
      final bottom = box.bottom.round().clamp(top + 1, oriented.height).toInt();
      final face = img.copyCrop(
        oriented,
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
      );
      final resized = img.copyResize(face, width: 112, height: 112);

      _interpreter ??= await Interpreter.fromAsset(
        'assets/models/mobilefacenet.tflite',
        options: InterpreterOptions()..threads = 2,
      );
      final input = List.generate(
        1,
        (_) => List.generate(
          112,
          (y) => List.generate(112, (x) {
            final p = resized.getPixel(x, y);
            return [
              (p.r.toDouble() - 127.5) / 128.0,
              (p.g.toDouble() - 127.5) / 128.0,
              (p.b.toDouble() - 127.5) / 128.0,
            ];
          }),
        ),
      );
      final output = List.generate(1, (_) => List<double>.filled(192, 0));
      _interpreter!.run(input, output);
      if (output.single.length != 192) {
        throw Exception(
          'Mô hình khuôn mặt không tương thích với API (cần 192 số).',
        );
      }
      return output.single;
    } finally {
      await detector.close();
    }
  }

  static Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}
