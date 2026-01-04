import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const ProStressApp());

class ProStressApp extends StatelessWidget {
  const ProStressApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF010101)),
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
    "Cinebench 物理像素渲染",
    "大型 3D 遊戲引擎模擬 (鳴潮等級)",
    "Disk I/O 儲存讀寫極限測試",
    "SoC 極限浮點運算 (PI/SQRT)",
    "RAM 4K 數據壓力測試",
  ];
  final Map<String, bool> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    for (var item in _options) _selectedItems[item] = true;
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
      appBar: AppBar(title: const Text("PRO SYSTEM ANALYZER"), centerTitle: true, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
              child: ListTile(
                title: const Text("測試總時長"),
                trailing: Text("${_testDuration.inHours}h ${_testDuration.inMinutes % 60}m", 
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                onTap: _showTimePicker,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: _options.map((item) => CheckboxListTile(
                  title: Text(item, style: const TextStyle(fontSize: 14)),
                  value: _selectedItems[item],
                  activeColor: Colors.orangeAccent,
                  onChanged: (v) => setState(() => _selectedItems[item] = v!),
                )).toList(),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                minimumSize: const Size(double.infinity, 70),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => RunBenchmarkPage(duration: _testDuration, items: _selectedItems),
              )),
              child: const Text("啟動全模塊壓測", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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

class _RunBenchmarkPageState extends State<RunBenchmarkPage> with TickerProviderStateMixin {
  int _fps = 0;
  DateTime? _lastFrameTime;
  final Battery _battery = Battery();
  int _batteryLevel = 0;
  double _elapsed = 0;
  Timer? _systemTimer;
  late AnimationController _gameController;
  late AnimationController _renderController;
  bool _showGraphs = true;

  List<FlSpot> _fpsHistory = [];
  List<FlSpot> _ioHistorySpots = [];
  double _currentIoSpeed = 0.0;
  double _peakIoSpeed = 0.0;
  int _totalDataProcessed = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _gameController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _renderController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    
    _gameController.addListener(() {
      final now = DateTime.now();
      if (_lastFrameTime != null) {
        final delta = now.difference(_lastFrameTime!).inMilliseconds;
        if (delta > 0) {
          setState(() {
            _fps = (1000 / delta).toInt().clamp(0, 120);
            _fpsHistory.add(FlSpot(_elapsed, _fps.toDouble()));
            if (_fpsHistory.length > 30) _fpsHistory.removeAt(0);
          });
        }
      }
      _lastFrameTime = now;
      if (widget.items["大型 3D 遊戲引擎模擬 (鳴潮等級)"]!) {
        for(int i=0; i<300000; i++) { math.atan2(i.toDouble(), 1.0); }
      }
    });

    _startStressLogic();
  }

  void _startStressLogic() {
    _systemTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final level = await _battery.batteryLevel;
      if (widget.items["Disk I/O 儲存讀寫極限測試"]!) await _performDiskIoTest();
      if (widget.items["SoC 極限浮點運算 (PI/SQRT)"]!) {
        for(int i=0; i<600000; i++) { math.sqrt(i) * math.atan(i.toDouble()); }
      }
      setState(() { _elapsed++; _batteryLevel = level; });
      if (_elapsed >= widget.duration.inSeconds) _finish();
    });
  }

  Future<void> _performDiskIoTest() async {
    final stopwatch = Stopwatch()..start();
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/test_io.bin');
    final bytes = List<int>.generate(40 * 1024 * 1024, (i) => i % 255);
    await file.writeAsBytes(bytes);
    await file.readAsBytes();
    stopwatch.stop();
    final double mbps = (80 / (stopwatch.elapsedMilliseconds / 1000.0));
    setState(() {
      _currentIoSpeed = mbps;
      _totalDataProcessed += 80;
      if (mbps > _peakIoSpeed) _peakIoSpeed = mbps;
      _ioHistorySpots.add(FlSpot(_elapsed, _currentIoSpeed));
      if (_ioHistorySpots.length > 30) _ioHistorySpots.removeAt(0);
    });
    if (await file.exists()) await file.delete();
  }

  void _finish() {
    _systemTimer?.cancel();
    WakelockPlus.disable();
    _showResultDialog();
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text("性能測試總結報告", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reportRow("峰值讀寫速度", "${_peakIoSpeed.toStringAsFixed(1)} MB/s"),
            _reportRow("累積處理數據", "${_totalDataProcessed} MB"),
            _reportRow("最終電量消耗", "$_batteryLevel%"),
            _reportRow("系統狀態", "SUCCESS", color: Colors.greenAccent),
          ],
        ),
        actions: [TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(context); }, child: const Text("完成"))],
      ),
    );
  }

  Widget _reportRow(String l, String v, {Color color = Colors.white}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 13)), Text(v, style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
  );

  @override
  void dispose() {
    _systemTimer?.cancel();
    _gameController.dispose();
    _renderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("實時性能分析儀", style: TextStyle(fontSize: 14)),
        actions: [IconButton(icon: Icon(_showGraphs ? Icons.analytics : Icons.remove_red_eye), onPressed: () => setState(() => _showGraphs = !_showGraphs))],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildAdvancedDash(),
            Expanded(child: _buildStage()),
            _buildControlPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedDash() {
    return Container(
      height: _showGraphs ? 240 : 100,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: _showGraphs ? 1.5 : 2.5,
        mainAxisSpacing: 10, crossAxisSpacing: 10,
        children: [
          _miniMonitor("REAL-TIME FPS", "$_fps", Colors.greenAccent, _fpsHistory, 120),
          _miniMonitor("DISK I/O (MB/s)", "${_currentIoSpeed.toInt()}", Colors.blueAccent, _ioHistorySpots, 1000),
        ],
      ),
    );
  }

  Widget _miniMonitor(String label, String value, Color color, List<FlSpot> spots, double maxVal) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          if (_showGraphs) ...[
            const Spacer(),
            SizedBox(
              height: 50,
              child: LineChart(
                LineChartData(
                  minY: 0, maxY: maxVal,
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: color, barWidth: 2, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)))],
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStage() {
    return Container(
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(border: Border.all(color: Colors.white10), color: Colors.black),
      child: Stack(
        children: [
          if (widget.items["大型 3D 遊戲引擎模擬 (鳴潮等級)"]!) CustomPaint(painter: GamePainter(_gameController.value), child: Container()),
          if (widget.items["Cinebench 物理像素渲染"]!) CustomPaint(painter: BucketPainter(_renderController.value), child: Container()),
          if (widget.items["Disk I/O 儲存讀寫極限測試"]!) const Positioned(bottom: 10, right: 10, child: Text("I/O TESTING...", style: TextStyle(color: Colors.white24, fontSize: 10))),
        ],
      ),
    );
  }

  Widget _buildControlPanel() => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("測試時間", style: TextStyle(fontSize: 10, color: Colors.grey)),
          Text("${_elapsed.toInt()}s", style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ]),
        CupertinoButton(color: Colors.redAccent.withOpacity(0.1), onPressed: _finish, child: const Text("停止測試並生成報告", style: TextStyle(color: Colors.redAccent, fontSize: 14))),
      ],
    ),
  );
}

class GamePainter extends CustomPainter {
  final double anim; GamePainter(this.anim);
  @override void paint(Canvas canvas, Size size) {
    final r = math.Random(42); final p = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 300; i++) {
      p.color = Color.fromARGB(150, (math.sin(anim*6)*127+128).toInt(), (r.nextDouble()*255).toInt(), 255);
      canvas.drawCircle(Offset(r.nextDouble()*size.width, r.nextDouble()*size.height), r.nextDouble()*3, p);
    }
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}

class BucketPainter extends CustomPainter {
  final double p; BucketPainter(this.p);
  @override void paint(Canvas canvas, Size size) {
    const int c = 8, r = 12; final bw = size.width / c, bh = size.height / r;
    final pFill = Paint()..color = Colors.orangeAccent.withOpacity(0.1);
    final pStroke = Paint()..style = PaintingStyle.stroke..color = Colors.orangeAccent..strokeWidth = 0.5;
    int cur = (c * r * p).toInt();
    for (int i = 0; i < c * r; i++) {
      Rect rect = Rect.fromLTWH((i%c)*bw, (i~/c)*bh, bw, bh);
      if (i < cur) canvas.drawRect(rect, pFill);
      else if (i == cur) {
        canvas.drawRect(rect, pStroke);
        canvas.drawLine(Offset(rect.left, rect.top+bh/2), Offset(rect.right, rect.top+bh/2), pStroke);
        canvas.drawLine(Offset(rect.left+bw/2, rect.top), Offset(rect.left+bw/2, rect.bottom), pStroke);
      }
    }
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}
