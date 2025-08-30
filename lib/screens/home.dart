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

class _HomeState extends State<Home> with TickerProviderStateMixin {
  bool _isListening = false;
  double _currentAmplitude = 0.0;
  Timer? _amplitudeTimer;

  @override
  void initState() {
    super.initState();
    RecordUtility.initialize();
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    RecordUtility.dispose();
    super.dispose();
  }

  void _startListening() async {
    try {
      await RecordUtility.startRecording();
      setState(() {
        _isListening = true;
      });

      // Start periodic amplitude updates
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        setState(() {
          _currentAmplitude = RecordUtility.currentAmplitude;
          print('Border Width: ${10 + (_currentAmplitude * 15)} pixels');
        });
      });
    } catch (e) {
      // Handle any errors, maybe show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  void _stopListening() async {
    try {
      await RecordUtility.stopRecording();
      _amplitudeTimer?.cancel();
      setState(() {
        _isListening = false;
        _currentAmplitude = 0.0;
      });
      displayResult(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
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
                    width: _isListening ? 10 + (_currentAmplitude * 15) : 0,
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
