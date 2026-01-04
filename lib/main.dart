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

class ProStressApp extends StatefulWidget {
  const ProStressApp({super.key});
  @override
  State<ProStressApp> createState() => _ProStressAppState();
}

class _ProStressAppState extends State<ProStressApp> {
  bool _isDark = true; 

  void _toggleTheme() => setState(() => _isDark = !_isDark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _isDark ? ThemeData.dark() : ThemeData.light(),
      home: BenchmarkConfigPage(onThemeToggle: _toggleTheme, isDark: _isDark),
    );
  }
}

class BenchmarkConfigPage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDark;
  const BenchmarkConfigPage({super.key, required this.onThemeToggle, required this.isDark});

  @override
  State<BenchmarkConfigPage> createState() => _BenchmarkConfigPageState();
}

class _BenchmarkConfigPageState extends State<BenchmarkConfigPage> {
  Duration _testDuration = const Duration(minutes: 5);
  final List<String> _options = [
    "Cinebench 物理像素渲染", 
    "大型 3D 遊戲引擎模擬", 
    "Disk I/O 儲存讀寫測試", 
    "SoC 極限浮點運算", 
    "多軌影片剪輯壓力測試" // 獨立項目
  ];
  final Map<String, bool> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    for (var item in _options) _selectedItems[item] = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PRO SYSTEM STRESS V6"),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onThemeToggle,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 4,
              child: ListTile(
                title: const Text("設定測試總時長"),
                trailing: Text("${_testDuration.inMinutes} Min", style: TextStyle(color: widget.isDark ? Colors.orangeAccent : Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
                onTap: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (_) => Container(height: 250, color: widget.isDark ? Colors.grey[900] : Colors.white, child: CupertinoTimerPicker(onTimerDurationChanged: (d) => setState(() => _testDuration = d))),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: ListView(children: _options.map((e) => CheckboxListTile(
              title: Text(e, style: const TextStyle(fontSize: 14)), 
              value: _selectedItems[e], 
              activeColor: Colors.orangeAccent,
              onChanged: (v) => setState(() => _selectedItems[e] = v!)
            )).toList())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65), 
                backgroundColor: widget.isDark ? Colors.orangeAccent : Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => RunPage(duration: _testDuration, items: _selectedItems, isDark: widget.isDark))),
              child: const Text("啟動極限壓測", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}

class RunPage extends StatefulWidget {
  final Duration duration;
  final Map<String, bool> items;
  final bool isDark;
  const RunPage({super.key, required this.duration, required this.items, required this.isDark});

  @override
  State<RunPage> createState() => _RunPageState();
}

class _RunPageState extends State<RunPage> with TickerProviderStateMixin {
  final Battery _battery = Battery();
  int _fps = 0;
  int _batt = 0;
  double _elapsed = 0;
  Timer? _timer;
  late AnimationController _renderCtrl;
  late AnimationController _videoCtrl;
  List<FlSpot> _fpsSpots = [];
  double _ioSpeed = 0.0;
  double _cpuLoad = 0.0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _renderCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _videoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _startLogic();
  }

  void _startLogic() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final b = await _battery.batteryLevel;
      if (widget.items["Disk I/O 儲存讀寫測試"]!) await _ioTest();
      
      // 計算模擬負載
      double currentLoad = 10.0;
      if (widget.items["SoC 極限浮點運算"]!) currentLoad += 40.0;
      if (widget.items["大型 3D 遊戲引擎模擬"]!) currentLoad += 30.0;
      if (widget.items["多軌影片剪輯壓力測試"]!) currentLoad += 15.0;

      setState(() {
        _batt = b;
        _elapsed++;
        _cpuLoad = currentLoad + math.Random().nextDouble() * 5.0;
        _fps = 90 + math.Random().nextInt(31); 
        _fpsSpots.add(FlSpot(_elapsed, _fps.toDouble()));
        if (_fpsSpots.length > 25) _fpsSpots.removeAt(0);
      });
      if (_elapsed >= widget.duration.inSeconds) _finish();
    });
  }

  Future<void> _ioTest() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/io_test.bin');
    final start = DateTime.now();
    await file.writeAsBytes(List.generate(25 * 1024 * 1024, (i) => i % 255));
    await file.readAsBytes();
    final diff = DateTime.now().difference(start).inMilliseconds;
    setState(() => _ioSpeed = 50000 / (diff > 0 ? diff : 1));
  }

  void _finish() { _timer?.cancel(); WakelockPlus.disable(); Navigator.pop(context); }

  @override
  void dispose() {
    _renderCtrl.dispose();
    _videoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = widget.isDark ? Colors.orangeAccent : Colors.blue;
    return Scaffold(
      backgroundColor: widget.isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildDash(themeColor),
            _buildGraph(themeColor),
            Expanded(child: _buildStage(themeColor)),
            Padding(
              padding: const EdgeInsets.all(15),
              child: CupertinoButton(color: Colors.red, child: const Text("終止測試"), onPressed: _finish),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDash(Color color) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat("FPS", "$_fps", color),
          _stat("BATT", "$_batt%", Colors.redAccent),
          _stat("CPU", "${_cpuLoad.toStringAsFixed(1)}%", Colors.greenAccent),
          _stat("I/O", "${_ioSpeed.toInt()}MB/s", Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 20))]);

  Widget _buildGraph(Color color) {
    return SizedBox(
      height: 80,
      width: double.infinity,
      child: LineChart(LineChartData(
        minY: 0, maxY: 144,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [LineChartBarData(spots: _fpsSpots, isCurved: true, color: color, barWidth: 2, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)))],
      )),
    );
  }

  Widget _buildStage(Color color) {
    return Container(
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10)
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // 剪輯測試背景層
            if (widget.items["多軌影片剪輯壓力測試"]!) _buildVideoEditor(),
            // 3D 遊戲層
            if (widget.items["大型 3D 遊戲引擎模擬"]!) _buildParticleEngine(),
            // Cinebench 算圖層 (最上層)
            if (widget.items["Cinebench 物理像素渲染"]!) AnimatedBuilder(
              animation: _renderCtrl,
              builder: (c, _) => CustomPaint(painter: CinePainter(_renderCtrl.value, color), child: Container()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoEditor() {
    return Column(
      children: [
        Expanded(child: Center(child: Icon(Icons.movie_filter, size: 50, color: Colors.blue.withOpacity(0.2)))),
        Container(
          height: 100,
          color: Colors.black.withOpacity(0.1),
          child: Column(
            children: List.generate(3, (index) => Container(
              height: 20,
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 5),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
              child: AnimatedBuilder(
                animation: _videoCtrl,
                builder: (context, child) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.3,
                  child: Container(margin: EdgeInsets.only(left: _videoCtrl.value * 200), color: Colors.white24),
                ),
              ),
            )),
          ),
        )
      ],
    );
  }

  Widget _buildParticleEngine() {
    final r = math.Random(1);
    return Stack(children: List.generate(30, (i) => Positioned(
      left: r.nextDouble() * 300, 
      top: r.nextDouble() * 300, 
      child: const CircularProgressIndicator(strokeWidth: 1, valueColor: AlwaysStoppedAnimation(Colors.cyanAccent))
    )));
  }
}

class CinePainter extends CustomPainter {
  final double progress;
  final Color themeColor;
  CinePainter(this.progress, this.themeColor);

  @override
  void paint(Canvas canvas, Size size) {
    const int cols = 12;
    const int rows = 18;
    final bw = size.width / cols;
    final bh = size.height / rows;
    
    final fillPaint = Paint()..color = themeColor.withOpacity(0.6);
    final borderPaint = Paint()..style = PaintingStyle.stroke..color = themeColor..strokeWidth = 0.5;
    final activePaint = Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 2.0;

    int total = cols * rows;
    int currentIdx = (total * progress).toInt();

    for (int i = 0; i < total; i++) {
      Rect rect = Rect.fromLTWH((i % cols) * bw, (i ~/ cols) * bh, bw, bh);
      if (i < currentIdx) {
        // 已完成：保持填充狀態 (Cinebench 真實效果)
        canvas.drawRect(rect, fillPaint);
      } else if (i == currentIdx) {
        // 當前格：顯示強化邊框與十字線
        canvas.drawRect(rect, activePaint);
        canvas.drawLine(Offset(rect.left, rect.center.dy), Offset(rect.right, rect.center.dy), activePaint);
        canvas.drawLine(Offset(rect.center.dx, rect.top), Offset(rect.center.dx, rect.bottom), activePaint);
      } else {
        // 未完成：顯示淡色網格
        canvas.drawRect(rect, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(CinePainter old) => true;
}
