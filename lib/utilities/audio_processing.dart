import 'dart:math' as math;
import 'package:fftea/fftea.dart';

class AudioFeatureExtractor {
  static const int sampleRate = 16000; // Standard sample rate for speech processing
  static const double preEmphasisCoeff = 0.97;
  static const int frameLength = 400; // 25ms * 16000Hz = 400 samples
  static const int frameStep = 160;   // 10ms * 16000Hz = 160 samples
  static const int nMelFilters = 40;  // Number of Mel filters
  static const int nMfccCoeffs = 40;  // Number of MFCC coefficients to keep
  static const int targetTimeSteps = 200; // Target number of time steps

  // Pre-emphasis filter
  static List<double> preEmphasis(List<double> signal) {
    List<double> emphasizedSignal = List<double>.filled(signal.length, 0);
    emphasizedSignal[0] = signal[0];
    for (int i = 1; i < signal.length; i++) {
      emphasizedSignal[i] = signal[i] - preEmphasisCoeff * signal[i - 1];
    }
    return emphasizedSignal;
  }

  // Frame the signal into overlapping frames
  static List<List<double>> framing(List<double> signal) {
    int numFrames = ((signal.length - frameLength) ~/ frameStep) + 1;
    List<List<double>> frames = List.generate(
      numFrames,
      (frameIndex) => List<double>.generate(
        frameLength,
        (i) => signal[frameIndex * frameStep + i],
      ),
    );
    return frames;
  }

  // Apply Hamming window to each frame
  static List<double> hammingWindow(List<double> frame) {
    return List<double>.generate(frame.length, (i) {
      double multiplier = 0.54 - 0.46 * math.cos(2 * math.pi * i / (frame.length - 1));
      return frame[i] * multiplier;
    });
  }

  // Convert frequency to Mel scale
  static double freqToMel(double freq) {
    return 2595 * (math.log(1 + freq / 700) / math.ln10);
  }

  // Convert Mel scale to frequency
  static double melToFreq(double mel) {
    return 700 * (math.pow(10, mel / 2595) - 1);
  }

  // Create Mel filterbank
  static List<List<double>> createMelFilterbank() {
    double lowFreqMel = freqToMel(0);
    double highFreqMel = freqToMel(sampleRate / 2);
    List<double> melPoints = List<double>.generate(nMelFilters + 2, (i) {
      return lowFreqMel + (highFreqMel - lowFreqMel) / (nMelFilters + 1) * i;
    });
    
    List<double> freqPoints = melPoints.map(melToFreq).toList();
    List<int> bins = freqPoints.map((f) => ((frameLength + 1) * f / sampleRate).round()).toList();
    
    List<List<double>> filterbank = List.generate(
      nMelFilters,
      (i) => List<double>.filled((frameLength ~/ 2) + 1, 0.0),
    );

    for (int i = 0; i < nMelFilters; i++) {
      for (int j = bins[i]; j < bins[i + 1]; j++) {
        filterbank[i][j] = (j - bins[i]) / (bins[i + 1] - bins[i]);
      }
      for (int j = bins[i + 1]; j < bins[i + 2]; j++) {
        filterbank[i][j] = (bins[i + 2] - j) / (bins[i + 2] - bins[i + 1]);
      }
    }

    return filterbank;
  }

  // Apply DCT to get MFCCs
  static List<double> dct(List<double> input) {
    int N = input.length;
    List<double> output = List<double>.filled(nMfccCoeffs, 0);
    
    for (int k = 0; k < nMfccCoeffs; k++) {
      double sum = 0;
      for (int n = 0; n < N; n++) {
        sum += input[n] * math.cos(math.pi * k * (2 * n + 1) / (2 * N));
      }
      output[k] = sum * math.sqrt(2.0 / N);
    }
    
    return output;
  }

  // Pad or truncate the MFCC features to match the target shape [40, 200]
  static List<List<double>> padOrTruncate(List<List<double>> mfccs) {
    if (mfccs.length > targetTimeSteps) {
      return mfccs.sublist(0, targetTimeSteps);
    } else {
      while (mfccs.length < targetTimeSteps) {
        mfccs.add(List<double>.filled(nMfccCoeffs, 0));
      }
      return mfccs;
    }
  }

  // Main function to extract MFCC features
  static List<List<double>> extractMFCC(List<double> signal) {
    print('Input signal length: ${signal.length}');
    
    // Pre-emphasis
    List<double> emphasizedSignal = preEmphasis(signal);
    print('After pre-emphasis length: ${emphasizedSignal.length}');
    
    // Framing
    List<List<double>> frames = framing(emphasizedSignal);
    print('Number of frames: ${frames.length}, Frame length: ${frames[0].length}');
    
    // Apply Hamming window to each frame
    frames = frames.map((frame) => hammingWindow(frame)).toList();
    
    // Create FFT object
    final fft = FFT(frameLength);
    
    // Create Mel filterbank
    final melFilterbank = createMelFilterbank();
    print('Mel filterbank size: ${melFilterbank.length} x ${melFilterbank[0].length}');
    
    // Process each frame
    List<List<double>> mfccs = [];
    
    for (var frame in frames) {
      // Apply FFT
      var spectrum = fft.realFft(frame);
      
      // Calculate power spectrum
      var powerSpectrum = List<double>.generate(
        (frameLength ~/ 2) + 1,
        (i) {
          var real = spectrum[i].x;
          var imag = spectrum[i].y;
          return real * real + imag * imag;
        },
      );
      
      // Apply Mel filterbank
      var melEnergies = List<double>.filled(nMelFilters, 0);
      for (int i = 0; i < nMelFilters; i++) {
        for (int j = 0; j < powerSpectrum.length; j++) {
          melEnergies[i] += powerSpectrum[j] * melFilterbank[i][j];
        }
        // Apply log
        melEnergies[i] = math.log(melEnergies[i] + 1e-10);
      }
      
      // Apply DCT
      var mfcc = dct(melEnergies);
      mfccs.add(mfcc);
    }
    
    // Pad or truncate to target shape
    final paddedMfccs = padOrTruncate(mfccs);
    
    // Transpose from [time_steps, mfcc_coeffs] to [mfcc_coeffs, time_steps]
    return transpose(paddedMfccs);
  }

  // Transpose a 2D list from [rows, cols] to [cols, rows]
  static List<List<double>> transpose(List<List<double>> matrix) {
    if (matrix.isEmpty || matrix[0].isEmpty) return matrix;
    
    final rows = matrix.length;
    final cols = matrix[0].length;
    
    return List.generate(cols, (col) =>
      List.generate(rows, (row) => matrix[row][col])
    );
  }
}
