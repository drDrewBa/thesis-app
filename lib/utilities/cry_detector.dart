import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
// import 'audio_processing.dart';

class CryDetector {
  static const List<String> cryTypes = ['pain', 'burping', 'discomfort', 'hungry', 'tired'];
  
  late final Interpreter _detectionModel;
  late final Interpreter _classificationModel;
  bool _isInitialized = false;

  // Singleton pattern
  static final CryDetector _instance = CryDetector._internal();
  CryDetector._internal();
  factory CryDetector() => _instance;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load detection model
      final detectionModelFile = await _getModel('fan_detection_model.tflite');
      _detectionModel = await Interpreter.fromFile(detectionModelFile);

      // Load classification model
      final classificationModelFile = await _getModel('fan_classification_model.tflite');
      _classificationModel = await Interpreter.fromFile(classificationModelFile);

      _isInitialized = true;
    } catch (e) {
      print('Error initializing models: $e');
      rethrow;
    }
  }

  Future<File> _getModel(String modelName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDir.path}/$modelName';
    final modelFile = File(modelPath);

    if (!await modelFile.exists()) {
      final modelBytes = await rootBundle.load('assets/models/$modelName');
      await modelFile.writeAsBytes(modelBytes.buffer.asUint8List());
    }

    return modelFile;
  }

  Future<(bool, String?)> processMFCC(List<List<double>> mfccFeatures) async {
    if (!_isInitialized) {
      throw Exception('CryDetector not initialized');
    }

    try {
      // Prepare input tensor [1, 40, 200, 1]
      var input = List.generate(1, (_) =>
        List.generate(40, (i) =>
          List.generate(200, (j) =>
            List.generate(1, (_) => mfccFeatures[i][j])
          )
        )
      );

      // Detection model inference - expecting output shape [1, 2]
      var detectionOutput = List.generate(1, (_) => List.filled(2, 0.0));
      
      _detectionModel.run(input, detectionOutput);
      
      // Log detection results
      print('=== Detection Model Results ===');
      print('No Cry Probability: ${detectionOutput[0][0]}');
      print('Cry Probability: ${detectionOutput[0][1]}');
      print('Raw output: $detectionOutput');
      print('============================');

      // Check if it's a cry (class 1 probability > threshold)
      bool isCry = detectionOutput[0][1] > 0.5;
      
      if (!isCry) {
        return (false, null);
      }

      // If it's a cry, run classification
      var classificationOutput = List.generate(1, (_) => List.filled(5, 0.0));
      
      _classificationModel.run(input, classificationOutput);

      // Log classification results
      print('\n=== Classification Model Results ===');
      for (int i = 0; i < 5; i++) {
        print('${cryTypes[i]}: ${classificationOutput[0][i]}');
      }
      print('Raw output: $classificationOutput');
      print('================================\n');

      // Get the predicted cry type
      int maxIndex = 0;
      double maxProb = classificationOutput[0][0];
      for (int i = 1; i < 5; i++) {
        if (classificationOutput[0][i] > maxProb) {
          maxProb = classificationOutput[0][i];
          maxIndex = i;
        }
      }
      
      print('Selected cry type: ${cryTypes[maxIndex]} (confidence: $maxProb)');

      return (true, cryTypes[maxIndex]);
    } catch (e) {
      print('Error during inference: $e');
      return (false, null);
    }
  }

  void dispose() {
    if (_isInitialized) {
      _detectionModel.close();
      _classificationModel.close();
      _isInitialized = false;
    }
  }
}
