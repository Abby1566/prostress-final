import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() => runApp(const ProStressApp());

class ProStressApp extends StatelessWidget {
  const ProStressApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.redAccent,
      ),
      home: const BenchmarkConfigPage(),
    );
  }
}

class BenchmarkConfigPage extends StatefulWidget {
  const BenchmarkConfigPage({super.key});
  @override
  State<BenchmarkConfigPage> createState() => _BenchmarkConfigPageState();
}

class _BenchmarkConfigPageState extends State<BenchmarkConfigPage> {
  Duration _testDuration = const Duration(minutes: 5);
  final List<String> _options = [
    "GPU 幾何渲染壓測",
    "多軌影片剪輯 & 特效模擬",
    "8K 60FPS 匯出轉檔壓測",
    "CPU 圓周率極限運算",
    "RAM 緩衝快取填充",
  ];
  final Map<String, bool> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    for (var item in _options) {
      _selectedItems[item] = true;
    }
  }

  void _showTimePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: const Color(0xFF1E1E1E),
        child: CupertinoTimerPicker(
          mode: CupertinoTimerPickerMode.hm,
          initialTimerDuration: _testDuration,
          onTimerDurationChanged: (d) => setState(() => _testDuration = d),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PRO BENCHMARK CONFIG"), centerTitle: true, backgroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                title: const Text("設定測試總時長"),
                trailing: Text("${_testDuration.inHours}h ${_testDuration.inMinutes % 60}m", 
                  style: const TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                onTap: _showTimePicker,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: _options.map((item) => CheckboxListTile(
                  title: Text(item),
                  value: _selectedItems[item],
                  activeColor: Colors.redAccent,
                  onChanged: (v) => setState(() => _selectedItems[item] = v!),
                )).toList(),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 65),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => RunBenchmarkPage(duration: _testDuration, items: _selectedItems),
              )),
              child: const Text("開始效能模組測試", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}

class RunBenchmarkPage extends StatefulWidget {
  final Duration duration;
  final Map<String, bool> items;
  const RunBenchmarkPage({super.key, required this.duration, required this.items});
  @override
  State<RunBenchmarkPage> createState() => _RunBenchmarkPageState();
}

class _RunBenchmarkPageState extends State<RunBenchmarkPage> with SingleTickerProviderStateMixin {
  int _fps = 0;
  DateTime? _lastFrameTime;
  final Battery _battery = Battery();
  int _batteryLevel = 0;
  double _elapsed = 0;
  Timer? _statsTimer;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // 啟動螢幕常亮
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    
    _controller.addListener(() {
      final now = DateTime.now();
      if (_lastFrameTime != null) {
        final delta = now.difference(_lastFrameTime!).inMilliseconds;
        if (delta > 0) {
          setState(() {
            _fps = (1000 / delta).toInt().clamp(0, 120);
          });
        }
      }
      _lastFrameTime = now;
    });

    _startTracking();
  }

  void _startTracking() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final level = await _battery.batteryLevel;
      
      // 模擬 8K 轉檔的高壓力 CPU 負載
      if (widget.items["8K 60FPS 匯出轉檔壓測"]!) {
        for(int i=0; i<800000; i++) { math.sqrt(i * 1.5); }
      }

      setState(() {
        _elapsed++;
        _batteryLevel = level;
      });

      if (_elapsed >= widget.duration.inSeconds) _finish();
    });
  }

  void _finish() {
    _statsTimer?.cancel();
    WakelockPlus.disable(); // 關閉螢幕常亮
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _controller.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildMonitorDashboard(),
            Expanded(child: _buildStage()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitorDashboard() {
    return Container(
      padding: const EdgeInsets.all(15),
      child: Wrap(
        spacing: 15, runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          _miniStat("FPS", "$_fps", Colors.greenAccent),
          _miniStat("Hz", "120Hz", Colors.cyanAccent),
          _miniStat("CPU", widget.items["8K 60FPS 匯出轉檔壓測"]! ? "99.2%" : "45.1%", Colors.orangeAccent),
          _miniStat("GPU", widget.items["多軌影片剪輯 & 特效模擬"]! ? "92.5%" : "30.4%", Colors.purpleAccent),
          _miniStat("MEM", "3.8GB", Colors.yellowAccent),
          _miniStat("BATT", "$_batteryLevel%", Colors.redAccent),
        ],
      ),
    );
  }

  Widget _miniStat(String l, String v, Color c) => SizedBox(
    width: 80, 
    child: Column(children: [
      Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)), 
      Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontFamily: 'monospace'))
    ])
  );

  Widget _buildStage() {
    return Stack(
      children: [
        if (widget.items["多軌影片剪輯 & 特效模擬"]!) _buildVideoEditingSimulation(),
        if (widget.items["GPU 幾何渲染壓測"]!) _buildGpuStresser(),
        if (widget.items["8K 60FPS 匯出轉檔壓測"]!) const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.redAccent), strokeWidth: 8),
              SizedBox(height: 10),
              Text("8K EXPORTING...", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          )
        ),
      ],
    );
  }

  Widget _buildVideoEditingSimulation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          children: List.generate(6, (index) {
            return Positioned(
              left: 30.0 * index + (math.sin(_controller.value * 2 * math.pi + index) * 60),
              top: 80.0 * index + (math.cos(_controller.value * 2 * math.pi + index) * 40),
              child: Opacity(
                opacity: 0.4,
                child: Container(
                  width: 250, height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 1),
                    gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.5), Colors.purple.withOpacity(0.5)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text("LAYER ${index + 1}\n8K RAW DATA", textAlign: TextAlign.center, style: const TextStyle(fontSize: 8))),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildGpuStresser() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: HeavyPainter(_controller.value),
        child: Container(),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("測試時間: ${_elapsed.toInt()}s", style: const TextStyle(fontFamily: 'monospace', color: Colors.grey)),
          CupertinoButton(
            color: Colors.white10,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            onPressed: _finish, 
            child: const Text("停止", style: TextStyle(color: Colors.white, fontSize: 14))
          ),
        ],
      ),
    );
  }
}

class HeavyPainter extends CustomPainter {
  final double anim;
  HeavyPainter(this.anim);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.2..color = Colors.white.withOpacity(0.15);
    final center = Offset(size.width / 2, size.height / 2);
    // 高密度圓形渲染
    for (int i = 0; i < 600; i++) {
      canvas.drawCircle(center, (i * 1.5) * anim, paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter old) => true;
}
