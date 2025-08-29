import 'dart:async';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class RecordUtility {
  static final AudioRecorder _audioRecorder = AudioRecorder();
  static String? _filePath;
  static bool _isRecording = false;
  static StreamController<double>? _amplitudeController;
  static Timer? _amplitudeTimer;

  static Stream<double> get amplitudeStream => 
      _amplitudeController?.stream ?? const Stream.empty();

  static Future<void> startRecording() async {
    try {
      if (!_isRecording) {
        if (await _audioRecorder.hasPermission()) {
          // Get the application documents directory
          final directory = await getApplicationDocumentsDirectory();
          // Create a unique filename with timestamp
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          _filePath = path.join(directory.path, 'audio_$timestamp.m4a');

          // Initialize amplitude stream
          _amplitudeController = StreamController<double>.broadcast();
          
          // Start recording
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            ),
            path: _filePath!,
          );
          _isRecording = true;

          // Start monitoring amplitude
          _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
            if (_isRecording && _amplitudeController != null && !_amplitudeController!.isClosed) {
              final amplitude = await _audioRecorder.getAmplitude();
              // Only log non-zero amplitudes
              if (amplitude.current > -30) {  // -30dB is our baseline
                print('Raw amplitude: ${amplitude.current}');
                print('Normalized amplitude: ${(amplitude.current + 30) / 30}');
              }
              final normalized = (amplitude.current + 30) / 30;
              final clampedValue = normalized.clamp(0.0, 1.0);
              _amplitudeController!.add(clampedValue);
            }
          });
        }
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  static Future<String?> stopRecording() async {
    try {
      if (_isRecording) {
        // Stop amplitude monitoring
        _amplitudeTimer?.cancel();
        await _amplitudeController?.close();
        _amplitudeTimer = null;
        _amplitudeController = null;

        final path = await _audioRecorder.stop();
        _isRecording = false;
        return path;
      }
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        // Stop amplitude monitoring
        _amplitudeTimer?.cancel();
        await _amplitudeController?.close();
        _amplitudeTimer = null;
        _amplitudeController = null;

        await _audioRecorder.stop();
        _isRecording = false;
        // You might want to delete the file here TODO: delete the file
      }
    } catch (e) {
      print('Error canceling recording: $e');
      _isRecording = false;
    }
  }

  static Future<bool> checkPermission() async {
    return await _audioRecorder.hasPermission();
  }
}