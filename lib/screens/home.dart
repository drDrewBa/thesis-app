import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/show_result.dart';
import '../utilities/record.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _isListening = false;
  StreamSubscription<double>? _amplitudeSubscription;
  double _currentAmplitude = 0.0;

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    super.dispose();
  }

  void _startListening() async {
    final hasPermission = await RecordUtility.checkPermission();
    if (hasPermission) {
      setState(() {
        _isListening = true;
      });
      await RecordUtility.startRecording();
      
      // Subscribe to amplitude updates
      _amplitudeSubscription = RecordUtility.amplitudeStream.listen((amplitude) {
        if (amplitude > 0) {  // We'll only log when there's actual sound
          print('Received amplitude in widget: $amplitude');
        }
        setState(() {
          _currentAmplitude = amplitude;
        });
      });
    } else {
      // Handle permission denied
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone permission denied')),
        );
      }
    }
  }

  void _stopListening() async {
    // Cancel amplitude subscription
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    setState(() {
      _isListening = false;
      _currentAmplitude = 0.0;
    });
    final path = await RecordUtility.stopRecording();
    if (path != null) {
      if (mounted) {
        displayResult(context);
      }
    }
  }

  // void _cancelListening() {
  //   setState(() {
  //     _isListening = false;
  //     RecordUtility.cancelRecording();
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _isListening ? _stopListening : _startListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.lightBlue[200]!,
                      Colors.lightBlue[300]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: Colors.lightBlue[100]!,
                    width: _isListening ? 10 + (_currentAmplitude * 20) : 0,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
                width: 172,
                height: 172,
                child: Icon(CupertinoIcons.mic_fill, size: 64, color: Colors.white),
              ),
            ),
            SizedBox(height: 56),
            Text(
              _isListening ? 'listening...' : 'tap to listen',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
