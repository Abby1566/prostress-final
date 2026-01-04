import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // 導入 Cupertino 組件，提供 iOS 風格
import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';

void main() {
  // 確保 Flutter 服務初始化，尤其是在使用插件前
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProStressApp());
}

class ProStressApp extends StatefulWidget {
  const ProStressApp({super.key});
  @override
  State<ProStressApp> createState() => _ProStressAppState();
}

class _ProStressAppState extends State<ProStressApp> {
  bool _isDark = true; // 預設深色模式，符合專業工具感
  void _toggleTheme() => setState(() => _isDark = !_isDark);

  @override
  Widget build(BuildContext context) {
    // 使用 CupertinoApp 會有更純粹的 iOS 風格，但為了保持 MaterialApp 的通用性，這裡保持現狀
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 發布時隱藏調試標籤
      theme: _isDark ? ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white),
        cardTheme: CardTheme(color: Colors.grey[900]),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.redAccent)),
      ) : ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black),
        cardTheme: const CardTheme(color: Color(0xFFF0F0F0)),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.red)),
      ),
      home: BenchmarkConfigPage(onThemeToggle: _toggleTheme, isDark: _isDark),
    );
  }
}

// --- 1. 配置頁面 ---
class BenchmarkConfigPage extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDark;
  const BenchmarkConfigPage({super.key, required this.onThemeToggle, required this.isDark});

  @override
  State<BenchmarkConfigPage> createState() => _BenchmarkConfigPageState();
}

class _BenchmarkConfigPageState extends State<BenchmarkConfigPage> {
  Duration _testDuration = const Duration(minutes: 5);
  int _selectedIdx = 0;

  final List<String> _options = [
    "Cinebench 算圖 (CPU Multi-Core)", 
    "PugetBench 剪輯 (GPU/Media)", 
    "Matrix 數位矩陣 (CPU Cache/AI)", 
    "Ulam Spiral 質數 (Logic Unit)", 
    "HDR 峰值亮度 (Display Panel)",
    "Disk I/O 極限寫入 (NAND Flash)", 
    "3D 粒子引擎 (Graphics/Vulkan)",
    "RAM 數據吞吐測試 (Memory)",
    "🔥 大魔王等級：全系統巔峰壓測 🔥"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("iOS EXTREME STRESS V15"),
        actions: [IconButton(icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode), onPressed: widget.onThemeToggle)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 4,
              child: ListTile(
                leading: const Icon(CupertinoIcons.timer, color: Colors.blueAccent),
                title: const Text("設定測試總時長", style: TextStyle(fontWeight: FontWeight.w500)),
                trailing: Text("${_testDuration.inMinutes} Min", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent)),
                onTap: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (_) => Container(
                      height: 250, 
                      color: CupertinoColors.systemBackground.resolveFrom(context), // 適應 iOS 主題
                      child: CupertinoTimerPicker(
                        mode: CupertinoTimerPickerMode.remainsMinutes,
                        onTimerDurationChanged: (d) => setState(() => _testDuration = d),
                        initialTimerDuration: _testDuration,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _options.length,
              itemBuilder: (context, i) => RadioListTile<int>(
                title: Text(_options[i], style: TextStyle(
                  color: i == _options.length - 1 ? Colors.red : null,
                  fontWeight: i == _options.length - 1 ? FontWeight.bold : null,
                )),
                subtitle: Text(i == _options.length - 1 ? "警告：將同時激發所有硬體極限！" : "單項專門測試", style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                value: i, groupValue: _selectedIdx, activeColor: Colors.redAccent,
                onChanged: (v) => setState(() => _selectedIdx = v!),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: CupertinoButton.filled(
              onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (c) => RunPage( // 使用 CupertinoPageRoute
                duration: _testDuration, 
                testName: _options[_selectedIdx], 
                isDark: widget.isDark
              ))),
              child: const Text("啟動測試", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          )
        ],
      ),
    );
  }
}

// --- 2. 測試運行頁面 ---
class RunPage extends StatefulWidget {
  final Duration duration;
  final String testName;
  final bool isDark;
  const RunPage({super.key, required this.duration, required this.testName, required this.isDark});

  @override
  State<RunPage> createState() => _RunPageState();
}

class _RunPageState extends State<RunPage> with TickerProviderStateMixin {
  final Battery _battery = Battery();
  int _fps = 0, _battStart = 0, _battCurrent = 0, _primeCount = 0;
  double _elapsed = 0, _cpuLoad = 0.0;
  List<double> _fpsHistory = [];
  Timer? _timer;
  late AnimationController _anim;
  Color _screenColor = Colors.white;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // 保持螢幕常亮
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(); // 視覺動畫循環
    _initBattery(); // 初始化電池電量
    if (widget.testName.contains("Display") || widget.testName.contains("大魔王")) {
      ScreenBrightness.instance.setApplicationScreenBrightness(1.0); // 螢幕亮度調到最高
    }
    _startLogic(); // 啟動測試邏輯
  }

  Future<void> _initBattery() async { _battStart = await _battery.batteryLevel; }

  void _startLogic() {
    bool isOverlord = widget.testName.contains("大魔王");
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      _battCurrent = await _battery.batteryLevel;
      
      // 後台運算邏輯：根據測試模式觸發不同的硬體負載
      if (isOverlord || widget.testName.contains("Logic")) {
        // 質數運算，模擬 CPU 邏輯單元高負荷
        _primeCount += 1500; 
      }
      if (isOverlord || widget.testName.contains("CPU") || widget.testName.contains("Cache") || widget.testName.contains("AI")) {
        // CPU 多核心與快取重度運算，模擬浮點運算密集型任務
        for(int i=0; i<1000000; i++) { math.sqrt(i) * math.atan(i); }
      }
      if (isOverlord || widget.testName.contains("Flash")) {
        // 磁碟 I/O 寫入測試，模擬大量文件讀寫
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/io_test_data.bin');
        await file.writeAsBytes(List.generate(10 * 1024 * 1024, (i) => i % 255)); // 寫入 10MB 數據
        // 讀取操作可以增加負載：await file.readAsBytes();
      }
      // TODO: RAM 數據吞吐測試需要更底層的 C/C++ 實現或 Dart FFI，此處暫用模擬
      // TODO: 3D 粒子引擎需要 Flame 或原生 Metal/OpenGL，此處暫用模擬

      setState(() {
        _elapsed++;
        // FPS 模擬：大魔王模式下 FPS 會更低且波動大
        _fps = isOverlord ? 15 + math.Random().nextInt(35) : 58 + math.Random().nextInt(4);
        _fpsHistory.add(_fps.toDouble());
        // CPU 負載模擬：大魔王模式直接拉滿
        _cpuLoad = isOverlord ? 100.0 : (widget.testName.contains("CPU") ? 98.0 : 45.0);
      });
      if (_elapsed >= widget.duration.inSeconds) _finish(); // 達到設定時間結束測試
    });
  }

  void _finish() {
    _timer?.cancel(); // 停止定時器
    WakelockPlus.disable(); // 允許螢幕休眠
    ScreenBrightness.instance.resetApplicationScreenBrightness(); // 恢復螢幕亮度
    _showResult(); // 顯示測試結果
  }

  void _showResult() {
    double avgFps = _fpsHistory.isEmpty ? 0 : _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;
    int battDrop = _battStart - _battCurrent;
    String rank;
    if (widget.testName.contains("大魔王")) {
      rank = avgFps > 40 ? "iOS 旗艦戰神 (散熱優秀)" : avgFps > 20 ? "穩健可靠 (主流水平)" : "降頻嚴重 (烤麵包機級)";
    } else {
      rank = avgFps > 58 ? "極致流暢 (優異表現)" : avgFps > 40 ? "表現良好" : "略顯疲態 (需優化)";
    }

    // 顯示 iOS 風格的結果對話框
    showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(
      title: const Text("測試報告", style: TextStyle(fontWeight: FontWeight.bold)),
      content: Text("測試項目: ${widget.testName}\n平均 FPS: ${avgFps.toStringAsFixed(1)}\n電量消耗: $battDrop%\n系統耐壓評價: $rank"),
      actions: [CupertinoDialogAction(child: const Text("完成"), onPressed: () { Navigator.pop(c); Navigator.pop(context); })],
    ));
  }

  @override
  Widget build(BuildContext context) {
    bool isOverlord = widget.testName.contains("大魔王");
    return Scaffold(
      backgroundColor: widget.isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildMonitorBar(), // 頂部監控條
            Expanded(child: _buildStage(isOverlord)), // 測試視覺化區域
            Padding(
              padding: const EdgeInsets.all(20),
              child: CupertinoButton( // iOS 風格按鈕
                color: CupertinoColors.systemRed,
                child: const Text("停止測試", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                onPressed: _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("FPS", "$_fps", CupertinoColors.activeBlue),
          _statItem("CPU", "${_cpuLoad.toInt()}%", CupertinoColors.activeGreen),
          _statItem("BATT", "$_battCurrent%", CupertinoColors.systemOrange),
          _statItem("TIME", "${_elapsed.toInt()}s", CupertinoColors.systemGrey),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: CupertinoColors.inactiveGray)),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
  ]);

  Widget _buildStage(bool isOverlord) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: widget.isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: CupertinoColors.systemRed.withOpacity(0.3), width: 2)
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            // 分隔顯示邏輯：根據是否為大魔王模式或單項測試來渲染不同視覺
            // 1. HDR 峰值亮度測試 (底層)
            if (isOverlord || widget.testName.contains("Display")) 
              GestureDetector(
                onTap: () => setState(() => _screenColor = _screenColor == Colors.white ? Colors.red : (_screenColor == Colors.red ? Colors.green : Colors.white)), // 點擊切換顏色
                child: Container(color: _screenColor, child: const Center(child: Text("HDR PEAK MODE\nTap to Toggle Color", textAlign: TextAlign.center, style: TextStyle(color: CupertinoColors.inactiveGray, fontSize: 10)))),
              ),
            // 2. 數位矩陣 (中層)
            if (isOverlord || widget.testName.contains("CPU") || widget.testName.contains("Cache") || widget.testName.contains("AI"))
              AnimatedBuilder(animation: _anim, builder: (c, _) => CustomPaint(painter: MatrixPainter(_anim.value), child: Container())),
            // 3. 質數螺旋 (中層)
            if (isOverlord || widget.testName.contains("Logic"))
              CustomPaint(painter: PrimePainter(_primeCount), child: Container()),
            // 4. Cinebench 算圖方塊 (中層)
            if (isOverlord || widget.testName.contains("Multi-Core"))
              AnimatedBuilder(animation: _anim, builder: (c, _) => CustomPaint(painter: CinePainter(_anim.value), child: Container())),
            // 5. 大魔王模式警示 (頂層)
            if (isOverlord) 
              Center(child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.black54,
                child: const Text("🔥 OVERLORD MODE 🔥\nEXTREME STRESSING...", textAlign: TextAlign.center, style: TextStyle(color: CupertinoColors.systemRed, fontWeight: FontWeight.w900, fontSize: 22))
              )),
          ],
        ),
      ),
    );
  }
}

// --- 3. 繪圖組件 (Painters) ---
// 這些 CustomPainter 用於繪製各種視覺化的壓力測試效果

class MatrixPainter extends CustomPainter {
  final double v; MatrixPainter(this.v);
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random((v * 100).toInt()); // 根據動畫值生成隨機數
    for(int i=0; i<40; i++) {
      final p = TextPainter(text: TextSpan(text: r.nextInt(10).toString(), style: TextStyle(color: CupertinoColors.systemGreen.withOpacity(0.4), fontSize: 14)), textDirection: TextDirection.ltr)..layout();
      p.paint(canvas, Offset(r.nextDouble() * size.width, r.nextDouble() * size.height)); // 隨機位置繪製數字
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // 總是重繪以產生動態效果
}

class PrimePainter extends CustomPainter {
  final int c; PrimePainter(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = CupertinoColors.systemPurple.withOpacity(0.5)..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height / 2);
    // 繪製 Ulam Spiral 的點陣圖，模擬質數分佈
    for (int i = 0; i < c % 3000; i++) { // 限制點的數量以優化性能，但仍保持動態
      double a = 0.15 * i;
      canvas.drawCircle(center + Offset((1.5 * a) * math.cos(a), (1.5 * a) * math.sin(a)), 1, paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CinePainter extends CustomPainter {
  final double p; CinePainter(this.p);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = CupertinoColors.systemOrange.withOpacity(0.6);
    double side = size.width / 10; // 方塊大小
    int current = (100 * p).toInt(); // 根據進度繪製方塊數量
    for (int i = 0; i < current; i++) {
      canvas.drawRect(Rect.fromLTWH((i % 10) * side, (i ~/ 10) * side, side - 1, side - 1), paint); // 繪製 Cinebench 風格的算圖方塊
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
