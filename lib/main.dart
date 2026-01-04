import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const ProBenchmarkApp());

class ProBenchmarkApp extends StatelessWidget {
  const ProBenchmarkApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: const BenchmarkPage(),
    );
  }
}

class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key});
  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> with SingleTickerProviderStateMixin {
  final Battery _battery = Battery();
  bool _isTesting = false;
  int _batteryLevel = 0;
  List<FlSpot> _performanceData = [];
  double _timerCount = 0;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _getInitialBattery();
  }

  Future<void> _getInitialBattery() async {
    _batteryLevel = await _battery.batteryLevel;
    setState(() {});
  }

  void _cpuStressTest() {
    if (!_isTesting) return;
    // 執行大量無理數計算以消耗 CPU
    for (int i = 0; i < 1500000; i++) {
      math.sqrt(math.pow(i, 1.5));
    }
  }

  void _toggleTest() {
    setState(() {
      _isTesting = !_isTesting;
      if (_isTesting) {
        _performanceData.clear();
        _timerCount = 0;
        _startDataTracking();
      }
    });
  }

  void _startDataTracking() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isTesting) {
        timer.cancel();
        return;
      }
      _cpuStressTest();
      _batteryLevel = await _battery.batteryLevel;
      
      setState(() {
        _timerCount++;
        // 模擬發熱曲線：從 30 度開始隨負載升高
        double simulatedTemp = 30 + (math.min(_timerCount / 8, 18.0));
        _performanceData.add(FlSpot(_timerCount, simulatedTemp));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('核心效能壓力測試')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem("電量", "$_batteryLevel%"),
                _statItem("狀態", _isTesting ? "測試中" : "待機"),
                _statItem("預估溫度", "${30 + (math.min(_timerCount / 8, 18.0)).toInt()}°C"),
              ],
            ),
          ),
          Expanded(child: _isTesting ? _buildGpuStress() : const Center(child: Text("準備開始壓力測試"))),
          _buildChart(),
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTesting ? Colors.red : Colors.green,
                minimumSize: const Size(200, 60),
              ),
              onPressed: _toggleTest,
              child: Text(_isTesting ? "停止測試" : "開始壓力測試", style: const TextStyle(fontSize: 20, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(children: [Text(label), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]);
  }

  // GPU 壓力測試：渲染大量高位元率變色方塊
  Widget _buildGpuStress() {
    return ListView.builder(
      itemCount: 150,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 2.0 * math.pi,
              child: Container(
                margin: const EdgeInsets.all(5),
                height: 40,
                color: Color((math.Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(0.8),
                child: const Center(child: Text("HIGH LOAD")),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LineChart(LineChartData(
        minY: 25, maxY: 50,
        lineBarsData: [LineChartBarData(spots: _performanceData, isCurved: true, color: Colors.orange, barWidth: 4)],
      )),
    );
  }
}
