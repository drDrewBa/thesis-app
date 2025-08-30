import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_processing.dart';
import 'cry_detector.dart';

class RealtimeAudioProcessor {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  static bool _isInitialized = false;
  static bool _isProcessing = false;
  static double _currentAmplitude = 0.0;
  static String? _recordingPath;
  static Timer? _processingTimer;
  static final CryDetector _cryDetector = CryDetector();
  
  // Audio buffer for real-time processing
  static final List<double> _audioBuffer = [];
  static const int _bufferSizeSeconds = 2; // Keep 2 seconds of audio
  static const int _bufferSize = AudioFeatureExtractor.sampleRate * _bufferSizeSeconds;
  static const int _processIntervalMs = 1000; // Process every 1 second
  static const int _samplesPerSecond = AudioFeatureExtractor.sampleRate;

  static Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        print('Initializing RealtimeAudioProcessor...');
        
        // Request permissions
        final micStatus = await Permission.microphone.request();
        if (micStatus != PermissionStatus.granted) {
          throw Exception('Microphone permission not granted');
        }

        // Initialize recorder
        await _recorder.openRecorder();
        
        // Initialize cry detector
        await _cryDetector.initialize();
        
        _isInitialized = true;
        print('RealtimeAudioProcessor initialized successfully');
      } catch (e) {
        print('Error initializing RealtimeAudioProcessor: $e');
        rethrow;
      }
    }
  }

  static Future<void> startProcessing() async {
    if (!_isInitialized) await initialize();
    
    if (_isProcessing) return;
    
    try {
      print('Starting real-time audio processing...');
      
      // Clear audio buffer
      _audioBuffer.clear();
      
      // Set up temporary recording file
      final appDir = await getApplicationDocumentsDirectory();
      _recordingPath = '${appDir.path}/temp_stream.wav';
      
      // Start recording
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: AudioFeatureExtractor.sampleRate,
        numChannels: 1,
        bitRate: 16 * AudioFeatureExtractor.sampleRate,
      );
      
      _isProcessing = true;
      
      // Set up amplitude monitoring for UI feedback and simulate audio collection
      _recorder.setSubscriptionDuration(const Duration(milliseconds: 50));
      _recorder.onProgress!.listen((event) {
        final decibels = event.decibels ?? 0;
        final duration = event.duration;
        _currentAmplitude = (decibels / 45).clamp(0.0, 1.0);
        
        if (decibels > -40) {
          print('Audio detected: ${decibels.toStringAsFixed(1)} dB');
        }
        
        // Simulate audio data collection based on amplitude and duration
        _simulateAudioData(decibels, duration);
      });
      
      // Start periodic processing timer
      _processingTimer = Timer.periodic(
        Duration(milliseconds: _processIntervalMs),
        (_) async {
          print('Timer triggered - processing audio buffer...');
          await _processAudioBuffer();
        },
      );
      
      print('Real-time processing started successfully');
    } catch (e) {
      print('Error starting real-time processing: $e');
      rethrow;
    }
  }

  static void _simulateAudioData(double decibels, Duration duration) {
    // Convert decibels to a simulated audio sample value
    // This is a simplified approach - in real implementation you'd need actual PCM data
    final normalizedAmplitude = (decibels + 60) / 60; // Normalize from [-60,0] to [0,1]
    final sampleValue = (normalizedAmplitude * 2 - 1).clamp(-1.0, 1.0); // Convert to [-1,1]
    
    // Calculate how many samples we should have collected since last update (50ms intervals)
    const samplesPerUpdate = AudioFeatureExtractor.sampleRate * 0.05; // 50ms worth of samples
    
    // Add samples to buffer
    for (int i = 0; i < samplesPerUpdate; i++) {
      // Add some variation to make it more realistic
      final variation = (i / samplesPerUpdate - 0.5) * 0.1;
      _audioBuffer.add((sampleValue + variation).clamp(-1.0, 1.0));
    }
    
    // Keep buffer size manageable (2 seconds max)
    while (_audioBuffer.length > _bufferSize) {
      _audioBuffer.removeAt(0);
    }
    

    
    if (_audioBuffer.length > _samplesPerSecond * 0.5) { // If we have at least 0.5 seconds
      print('Audio buffer size: ${_audioBuffer.length} samples (${(_audioBuffer.length / _samplesPerSecond).toStringAsFixed(2)}s)');
    }
  }

  static Future<void> _processAudioBuffer() async {
    print('Timer triggered - processing audio buffer...');
    
    if (!_isProcessing) {
      print('Early return - not processing');
      return;
    }
    
    print('Current audio buffer size: ${_audioBuffer.length} samples');
    
    if (_audioBuffer.length < _samplesPerSecond) {
      print('Not enough audio data yet: ${_audioBuffer.length} samples (need ${_samplesPerSecond})');
      return;
    }
    
    try {
      // Use the last 1 second of audio for processing
      final processingBuffer = _audioBuffer.length > _samplesPerSecond 
          ? _audioBuffer.sublist(_audioBuffer.length - _samplesPerSecond)
          : List<double>.from(_audioBuffer);
      
      print('Processing ${processingBuffer.length} audio samples...');
      print('Sample range: ${processingBuffer.map((s) => s.toStringAsFixed(3)).take(5).join(', ')}...');
      
      // Extract MFCC features from the audio buffer
      final mfccFeatures = AudioFeatureExtractor.extractMFCC(processingBuffer);
      print('Extracted MFCC features: ${mfccFeatures.length} x ${mfccFeatures[0].length}');
      
      // Run detection model
      final (isCry, cryType) = await _cryDetector.processMFCC(mfccFeatures);
      
      if (isCry) {
        print('🍼 CRY DETECTED: $cryType');
        // You can add callback here to notify the UI
      } else {
        print('👂 Listening... (no cry detected)');
      }
      
    } catch (e) {
      print('Error processing audio buffer: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  static Future<void> stopProcessing() async {
    if (!_isProcessing) return;
    
    try {
      print('Stopping real-time audio processing...');
      
      _isProcessing = false;
      
      // Stop timer
      _processingTimer?.cancel();
      _processingTimer = null;
      
      // Stop recording
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      
      // Clear buffer
      _audioBuffer.clear();
      
      // Clean up temporary file
      if (_recordingPath != null) {
        try {
          final file = File(_recordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Error cleaning up temp file: $e');
        }
        _recordingPath = null;
      }
      
      print('Real-time processing stopped');
    } catch (e) {
      print('Error stopping real-time processing: $e');
    }
  }

  static double get currentAmplitude => _currentAmplitude;
  static bool get isProcessing => _isProcessing;

  static Future<void> dispose() async {
    await stopProcessing();
    
    if (_isInitialized) {
      await _recorder.closeRecorder();
      _cryDetector.dispose();
      _isInitialized = false;
    }
  }
}
