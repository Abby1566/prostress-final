import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: StressApp(), debugShowCheckedModeBanner: false));
}

class StressApp extends StatefulWidget {
  const StressApp({super.key});
  @override
  State<StressApp> createState() => _StressAppState();
}

class _StressAppState extends State<StressApp> {
  int _fps = 0;
  bool _isStress = false;
  int _mode = 0;
  Timer? _t;

  void _run() {
    if (_isStress) {
      _t?.cancel();
      WakelockPlus.disable();
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    } else {
      WakelockPlus.enable();
      if (_mode == 1) ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
      _t = Timer.periodic(const Duration(milliseconds: 16), (t) {
        if (_mode == 1) { for(int i=0; i<1000000; i++) { math.sqrt(i); } }
        setState(() => _fps = _mode == 1 ? 25 + math.Random().nextInt(10) : 60);
      });
    }
    setState(() => _isStress = !_isStress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("iOS EXTREME V15"), backgroundColor: Colors.red),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("FPS: $_fps", style: const TextStyle(color: Colors.green, fontSize: 60, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        CupertinoSlidingSegmentedControl<int>(
          groupValue: _mode,
          children: const {0: Text("普通"), 1: Text("🔥 大魔王")},
          onValueChanged: (v) => setState(() => _mode = v!),
        ),
        const SizedBox(height: 60),
        CupertinoButton.filled(onPressed: _run, child: Text(_isStress ? "停止" : "開始壓測")),
      ])),
    );
  }
}
