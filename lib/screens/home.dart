import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/show_result.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _isListening = false;

  void _startListening() {
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
    });
    displayResult(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _isListening ? _stopListening : _startListening,
              child: Container(
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
                  // border: Border.all(
                  //   color: Colors.lightBlue[100]!,
                  //   width: 20,
                  //   strokeAlign: BorderSide.strokeAlignOutside,
                  // ),
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
