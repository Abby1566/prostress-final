import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const ProStressApp());

class ProStressApp extends StatelessWidget {
  const ProStressApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: Colors.blueAccent,
      ),
      home: const BenchmarkMainPage(),
    );
  }
}

class BenchmarkMainPage extends StatefulWidget {
  const BenchmarkMainPage({super.key});
  @override
  State<BenchmarkMainPage> createState() => _BenchmarkMainPageState();
}

class _BenchmarkMainPageState extends State<BenchmarkMainPage> with TickerProviderStateMixin {
  final Battery _battery = Battery();
  bool _isTesting = false;
  double _testTimeLimit = 5; // 分鐘
  int _batteryLevel = 0;
  List<FlSpot> _performanceHistory = [];
  double _elapsed = 0;
  Timer? _timer;
  
  // 測試開關
  bool _doGpu = true;
  bool _doScroll = true;
  bool _doCpu = false;

  late AnimationController _gpuAnim;

  @override
  void initState() {
    super.initState();
    _gpuAnim = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _battery.batteryLevel.then((v) => setState(() => _batteryLevel = v));
  }

  void _runBenchmark() {
    setState(() {
      _isTesting = true;
      _performanceHistory.clear();
      _elapsed = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_elapsed >= _testTimeLimit * 60 && _testTimeLimit < 60) {
        _stopBenchmark();
      } else {
        int level = await _battery.batteryLevel;
        setState(() {
          _elapsed++;
          _batteryLevel = level;
          // 模擬負載效能數據
          _performanceHistory.add(FlSpot(_elapsed, 30 + math.Random().nextDouble() * 15));
          if (_performanceHistory.length > 50) _performanceHistory.removeAt(0);
        });
      }
    });
  }

  void _stopBenchmark() {
    _timer?.cancel();
    setState(() => _isTesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PRO BENCHMARK V2"), centerTitle: true),
      body: _isTesting ? _buildTestingView() : _buildSetupView(),
    );
  }

  // --- 設置畫面 ---
  Widget _buildSetupView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("測試偏好設定", style: TextStyle(fontSize: 18, color: Colors.blueAccent)),
          const SizedBox(height: 20),
          _buildToggle("GPU 幾何渲染測試", _doGpu, (v) => setState(() => _doGpu = v)),
          _buildToggle("UI 列表滑動模擬", _doScroll, (v) => setState(() => _doScroll = v)),
          _buildToggle("CPU 密集運算負載", _doCpu, (v) => setState(() => _doCpu = v)),
          const SizedBox(height: 30),
          Text("測試時長: ${_testTimeLimit.toInt()} 分鐘"),
          Slider(
            value: _testTimeLimit, min: 1, max: 60,
            onChanged: (v) => setState(() => _testTimeLimit = v),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              backgroundColor: Colors.blueAccent,
            ),
            onPressed: _runBenchmark,
            child: const Text("啟動測試", style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String title, bool val, Function(bool) onChanged) {
    return SwitchListTile(title: Text(title), value: val, onChanged: onChanged);
  }

  // --- 測試中畫面 ---
  Widget _buildTestingView() {
    return Column(
      children: [
        _buildDataRow(),
        if (_doGpu) Expanded(child: _buildGpuCanvas()),
        if (_doScroll) Expanded(child: _buildScrollArea()),
        _buildLiveChart(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: OutlinedButton(onPressed: _stopBenchmark, child: const Text("終止測試")),
        )
      ],
    );
  }

  Widget _buildDataRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueAccent.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat("進度", "${(_elapsed / (_testTimeLimit * 60) * 100).toInt()}%"),
          _stat("電量", "$_batteryLevel%"),
          _stat("耗時", "${_elapsed.toInt()}s"),
        ],
      ),
    );
  }

  Widget _stat(String l, String v) => Column(children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]);

  Widget _buildGpuCanvas() {
    return AnimatedBuilder(
      animation: _gpuAnim,
      builder: (context, _) => CustomPaint(
        painter: GpuStressPainter(_gpuAnim.value),
        child: Container(),
      ),
    );
  }

  Widget _buildScrollArea() {
    return ListView.builder(
      itemCount: 1000,
      itemBuilder: (c, i) => ListTile(title: Text("Stress Data Line #$i"), leading: const Icon(Icons.sync_problem)),
    );
  }

  Widget _buildLiveChart() {
    return SizedBox(
      height: 120,
      child: LineChart(LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [LineChartBarData(spots: _performanceHistory, isCurved: true, color: Colors.blueAccent, dotData: const FlDotData(show: false))],
      )),
    );
  }
}

class GpuStressPainter extends CustomPainter {
  final double anim;
  GpuStressPainter(this.anim);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blueAccent.withOpacity(0.5)..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 100; i++) {
      double r = 20.0 + i * 2;
      canvas.drawRect(Rect.fromCenter(center: center, width: r * anim, height: r), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
