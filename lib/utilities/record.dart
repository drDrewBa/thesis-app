import 'realtime_audio_processor.dart';

class RecordUtility {
  static bool _isInitialized = false;


  static Future<void> initialize() async {
    if (!_isInitialized) {
      await RealtimeAudioProcessor.initialize();
      _isInitialized = true;
    }
  }

  static Future<void> startRecording() async {
    print('Starting real-time cry detection...');
    await RealtimeAudioProcessor.startProcessing();
  }

  static Future<void> stopRecording() async {
    print('Stopping real-time cry detection...');
    await RealtimeAudioProcessor.stopProcessing();
  }

  static double get currentAmplitude => RealtimeAudioProcessor.currentAmplitude;

  static Future<void> dispose() async {
    await RealtimeAudioProcessor.dispose();
    _isInitialized = false;
  }
}