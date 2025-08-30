import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordUtility {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  static bool _isInitialized = false;
  static double _currentAmplitude = 0.0;

  static Future<void> initialize() async {
    if (!_isInitialized) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      await _recorder.openRecorder();
      _isInitialized = true;
    }
  }

  static Future<void> startRecording() async {
    if (!_isInitialized) await initialize();
    
    await _recorder.startRecorder(
      toFile: 'temp.aac',
      codec: Codec.aacADTS,
    );

    // Start amplitude updates
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 50));
    _recorder.onProgress!.listen((event) {
      final decibels = event.decibels ?? 0;
      print('Raw Decibel Level: $decibels dB');
      
      // Convert decibels to a 0-1 range for the UI
      // Typical range we're seeing is 0-45 dB
      _currentAmplitude = (decibels / 45).clamp(0.0, 1.0);
      print('Normalized Amplitude: $_currentAmplitude');
    });
  }

  static Future<void> stopRecording() async {
    await _recorder.stopRecorder();
  }

  static double get currentAmplitude => _currentAmplitude;

  static Future<void> dispose() async {
    await _recorder.closeRecorder();
    _isInitialized = false;
  }
}