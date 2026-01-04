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
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: Colors.blueAccent,
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
      appBar: AppBar(title: const Text("PRO SYSTEM CONFIG"), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildSectionHeader("測試參數"),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: ListTile(
                leading: const Icon(Icons.timer_outlined, color: Colors.blueAccent),
                title: const Text("設定測試總時長"),
                trailing: Text("${_testDuration.inHours}h ${_testDuration.inMinutes % 60}m", 
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                onTap: _showTimePicker,
              ),
            ),
            const SizedBox(height: 30),
            _buildSectionHeader("壓測模組開關"),
            Expanded(
              child: ListView(
                children: _options.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                  child: CheckboxListTile(
                    title: Text(item, style: const TextStyle(fontSize: 14)),
                    value: _selectedItems[item],
                    activeColor: Colors.blueAccent,
                    onChanged: (v) => setState(() => _selectedItems[item] = v!),
                  ),
                )).toList(),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 65),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 10,
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => RunBenchmarkPage(duration: _testDuration, items: _selectedItems),
              )),
              child: const Text("啟動測試系統", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)));
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
    WakelockPlus.enable();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _controller.addListener(() {
      final now = DateTime.now();
      if (_lastFrameTime != null) {
        final delta = now.difference(_lastFrameTime!).inMilliseconds;
        if (delta > 0) setState(() => _fps = (1000 / delta).toInt().clamp(0, 120));
      }
      _lastFrameTime = now;
    });
    _startTracking();
  }

  void _startTracking() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final level = await _battery.batteryLevel;
      if (widget.items["8K 60FPS 匯出轉檔壓測"]!) {
        for(int i=0; i<800000; i++) { math.sqrt(i * 1.5); }
      }
      setState(() { _elapsed++; _batteryLevel = level; });
      if (_elapsed >= widget.duration.inSeconds) _finish();
    });
  }

  void _finish() { _statsTimer?.cancel(); WakelockPlus.disable(); Navigator.pop(context); }

  @override
  void dispose() { _statsTimer?.cancel(); _controller.dispose(); WakelockPlus.disable(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildDashboard(),
            Expanded(child: _buildMainStage()),
            _buildBottomTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.3,
        children: [
          _dashboardCard("FPS", "$_fps", _fps > 100 ? Colors.greenAccent : Colors.orangeAccent),
          _dashboardCard("CPU", widget.items["8K 60FPS 匯出轉檔壓測"]! ? "99%" : "42%", Colors.blueAccent),
          _dashboardCard("MEM", "3.2 GB", Colors.purpleAccent),
          _dashboardCard("BATT", "$_batteryLevel%", Colors.redAccent),
          _dashboardCard("TEMP", "38°C", Colors.orange),
          _dashboardCard("Hz", "120", Colors.cyanAccent),
        ],
      ),
    );
  }

  Widget _dashboardCard(String l, String v, Color c) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(v, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildMainStage() {
    return Stack(
      children: [
        if (widget.items["GPU 幾何渲染壓測"]!) _buildGpuCanvas(),
        if (widget.items["多軌影片剪輯 & 特效模擬"]!) _buildVideoSim(),
        if (widget.items["8K 60FPS 匯出轉檔壓測"]!) Center(child: Text("8K TRANSCODING ACTIVE", style: TextStyle(color: Colors.redAccent.withOpacity(0.3), fontWeight: FontWeight.w900, fontSize: 30))),
        // 專業感掃描線特效
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.02), Colors.transparent, Colors.white.withOpacity(0.02)],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGpuCanvas() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(painter: TechPainter(_controller.value), child: Container()),
    );
  }

  Widget _buildVideoSim() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Stack(
        children: List.generate(4, (i) => Positioned(
          left: 50.0 + (i * 20) + math.sin(_controller.value * 5) * 20,
          top: 150.0 + (i * 60) + math.cos(_controller.value * 3) * 30,
          child: Container(
            width: 250, height: 140,
            decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)), color: Colors.cyanAccent.withOpacity(0.05)),
            child: const Center(child: Icon(Icons.videocam_outlined, color: Colors.cyanAccent)),
          ),
        )),
      ),
    );
  }

  Widget _buildBottomTimeline() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("RUNNING SESSION", style: TextStyle(color: Colors.grey, fontSize: 10)),
              Text("${_elapsed.toInt()} / ${widget.duration.inSeconds} s", style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
            ],
          ),
          CupertinoButton(
            color: Colors.redAccent.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 30),
            onPressed: _finish,
            child: const Text("STOP", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class TechPainter extends CustomPainter {
  final double anim;
  TechPainter(this.anim);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.5..color = Colors.blueAccent.withOpacity(0.2);
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 400; i++) {
      canvas.drawRect(Rect.fromCenter(center: center, width: i * 2.0 * anim, height: i * 1.5), paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter old) => true;
}
