import 'dart:async';
import 'dart:math';
import 'package:dita_app/services/ads_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dita_app/services/api_service.dart';

class RamOptimizerScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const RamOptimizerScreen({super.key, required this.user});

  @override
  State<RamOptimizerScreen> createState() => _RamOptimizerScreenState();
}

class _RamOptimizerScreenState extends State<RamOptimizerScreen> with TickerProviderStateMixin {
  // --- CONFIG ---
  static const int gridSize = 8;
  static const double gridSpacing = 4.0;

  // --- THEME CONSTANTS ---
  final Color _ditaGold = const Color(0xFFFFD700);
  final Color _ditaBlue = const Color(0xFF003366);
  final Color _bugColor = const Color(0xFFEF4444); // Red for "Bugs/Corruption"

  // --- STATE ---
  List<Color?> _board = List.filled(gridSize * gridSize, null);
  final List<Timer> _corruptedTimers = [];

  int _scoreKB = 0;
  int _sessionPoints = 0;
  late int _currentTotalPoints;
  int _localHighScore = 0;

  bool _isGameOver = false;
  bool _isSaving = false;
  bool _hasRevived = false;

  // --- ANIMATION & FX ---
  int _comboCount = 0;
  late AnimationController _comboController;
  late Animation<double> _comboScale;

  // Particle System
  final List<Particle> _particles = [];
  late Ticker _ticker;

  // Screen Shake
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // --- HOVER STATE ---
  int? _hoverAnchorIndex;
  List<Point<int>>? _hoverShape;
  Color? _hoverColor; // Added to track the color of the shape being dragged
  int _hoverXOffset = 0;
  int _hoverYOffset = 0;

  // --- PROCESS COLORS (3D Texture Palette) ---
  final List<Color> _processColors = [
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFFEC4899), // Pink
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFFF97316), // Orange
    const Color(0xFF6366F1), // Indigo
  ];

  // --- EXTENDED SHAPE LIBRARY (Block Blast Style) ---
  final List<List<Point<int>>> _baseShapes = [
    // 1. Single
    [const Point(0,0)],
    // 2. Lines
    [const Point(0,0), const Point(1,0)], // 2H
    [const Point(0,0), const Point(0,1)], // 2V
    [const Point(0,0), const Point(1,0), const Point(2,0)], // 3H
    [const Point(0,0), const Point(0,1), const Point(0,2)], // 3V
    [const Point(0,0), const Point(1,0), const Point(2,0), const Point(3,0)], // 4H
    [const Point(0,0), const Point(0,1), const Point(0,2), const Point(0,3)], // 4V
    [const Point(0,0), const Point(1,0), const Point(2,0), const Point(3,0), const Point(4,0)], // 5H
    [const Point(0,0), const Point(0,1), const Point(0,2), const Point(0,3), const Point(0,4)], // 5V
    // 3. Squares
    [const Point(0,0), const Point(1,0), const Point(0,1), const Point(1,1)], // 2x2
    [const Point(0,0), const Point(1,0), const Point(2,0), const Point(0,1), const Point(1,1), const Point(2,1), const Point(0,2), const Point(1,2), const Point(2,2)], // 3x3
    // 4. L Shapes (Corner)
    [const Point(0,0), const Point(1,0), const Point(0,1)], // TL Corner
    [const Point(0,0), const Point(1,0), const Point(1,1)], // TR Corner
    [const Point(0,0), const Point(0,1), const Point(1,1)], // BL Corner
    [const Point(1,0), const Point(0,1), const Point(1,1)], // BR Corner
    // 5. L Shapes (Large)
    [const Point(0,0), const Point(0,1), const Point(0,2), const Point(1,2)], // L Normal
    [const Point(0,0), const Point(1,0), const Point(2,0), const Point(0,1)], // L Rot 1
    [const Point(0,0), const Point(1,0), const Point(1,1), const Point(1,2)], // L Rot 2
    [const Point(2,0), const Point(0,1), const Point(1,1), const Point(2,1)], // L Rot 3
    // 6. T Shapes
    [const Point(0,0), const Point(1,0), const Point(2,0), const Point(1,1)], // T Down
    [const Point(1,0), const Point(0,1), const Point(1,1), const Point(1,2)], // T Left
    [const Point(1,0), const Point(0,1), const Point(1,1), const Point(2,1)], // T Up
    [const Point(0,0), const Point(0,1), const Point(1,1), const Point(0,2)], // T Right
    // 7. Z & S Shapes
    [const Point(0,0), const Point(1,0), const Point(1,1), const Point(2,1)], // Z Horz
    [const Point(1,0), const Point(1,1), const Point(0,1), const Point(0,2)], // Z Vert
    [const Point(1,0), const Point(2,0), const Point(0,1), const Point(1,1)], // S Horz
    [const Point(0,0), const Point(0,1), const Point(1,1), const Point(1,2)], // S Vert
  ];

  final List<List<Point<int>>?> _availableShapesInSlot = [null, null, null];
  final List<Color?> _slotColors = [null, null, null];

  @override
  void initState() {
    super.initState();
    _loadData();
    AdManager.loadAds();
    _fillAllSlots();

    // Combo Animation
    _comboController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _comboScale = Tween<double>(begin: 1.0, end: 1.5).animate(
        CurvedAnimation(parent: _comboController, curve: Curves.elasticOut)
    );

    // Shake Animation
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _shakeAnimation = Tween<double>(begin: 0, end: 5).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut)
    )..addListener(() => setState((){}));

    // Particle Ticker
    _ticker = createTicker(_updateParticles)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) => _showInstructions());
  }

  void _updateParticles(Duration elapsed) {
    if (_particles.isEmpty) return;
    setState(() {
      for (var p in _particles) { p.update(); }
      _particles.removeWhere((p) => p.life <= 0);
    });
  }

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward().then((value) => _shakeController.reverse());
  }

  void _spawnExplosion(int x, int y, Color color) {
    for (int i = 0; i < 8; i++) {
      _particles.add(Particle(x: x.toDouble(), y: y.toDouble(), color: color));
    }
  }

  Future<void> _loadData() async {
    if (widget.user['points'] != null) {
      _currentTotalPoints = int.tryParse(widget.user['points'].toString()) ?? 0;
    } else {
      _currentTotalPoints = 0;
    }
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _localHighScore = prefs.getInt('ram_high_score') ?? 0;
      });
    }
  }

  @override
  void dispose() {
    _cancelAllTimers();
    _comboController.dispose();
    _shakeController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _cancelAllTimers() {
    for (var t in _corruptedTimers) { t.cancel(); }
    _corruptedTimers.clear();
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("System Optimization", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("1. Drag 3D blocks to the grid."),
            SizedBox(height: 8),
            Text("2. Fill rows or columns to free RAM."),
            SizedBox(height: 8),
            Text("3. Isolate corrupt (Red) blocks to delete them."),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Start")
          )
        ],
      ),
    );
  }

  // --- GAME LOGIC ---

  void _fillAllSlots() {
    for(int i=0; i<3; i++) {
      _generateSingleShape(i);
    }
  }

  void _generateSingleShape(int index) {
    // Pick a random shape from the extended library
    List<Point<int>> newShape = List.from(_baseShapes[Random().nextInt(_baseShapes.length)]);
    
    // We already have many rotations, but flipping creates mirrored variants for L/Z/S
    // Occasional flip for variety
    if (Random().nextBool()) {
      bool flipX = Random().nextBool();
      bool flipY = Random().nextBool();
      
      if (flipX || flipY) {
        newShape = newShape.map((p) => Point(flipX ? -p.x : p.x, flipY ? -p.y : p.y)).toList();
        int minX = newShape.map((p) => p.x).reduce(min);
        int minY = newShape.map((p) => p.y).reduce(min);
        newShape = newShape.map((p) => Point(p.x - minX, p.y - minY)).toList();
      }
    }

    setState(() {
      _availableShapesInSlot[index] = newShape;
      _slotColors[index] = _processColors[Random().nextInt(_processColors.length)];
    });
    _checkGameOver();
  }

  bool _canPlace(List<Point<int>> shape, int x, int y) {
    for (var p in shape) {
      int targetX = x + p.x;
      int targetY = y + p.y;
      if (targetX < 0 || targetX >= gridSize || targetY < 0 || targetY >= gridSize) return false;
      int targetIndex = targetY * gridSize + targetX;
      if (_board[targetIndex] != null) return false;
    }
    return true;
  }

  void _placeShape(List<Point<int>> shape, Color color, int originX, int originY) {
    bool isCorrupted = Random().nextInt(20) == 0; // 5% chance of bug
    Color finalColor = isCorrupted ? _bugColor : color;

    int kbGained = shape.length * 10;
    int pointsGained = shape.length;

    HapticFeedback.lightImpact();

    setState(() {
      for (var p in shape) {
        int targetIndex = (originY + p.y) * gridSize + (originX + p.x);
        _board[targetIndex] = finalColor;
      }
      _scoreKB += kbGained;
      _sessionPoints += pointsGained;
      _currentTotalPoints += pointsGained;
    });

    if (isCorrupted) {
      _startCorruptionTimer(finalColor);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("⚠️ Corruption Detected!"), backgroundColor: _bugColor, duration: const Duration(milliseconds: 800))
      );
    }
  }

  void _startCorruptionTimer(Color colorKey) {
    Timer? timer;
    timer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (_isGameOver || !mounted) { t.cancel(); return; }
      List<int> currentPositions = [];
      for (int i = 0; i < _board.length; i++) {
        if (_board[i] == colorKey) currentPositions.add(i);
      }
      if (currentPositions.isEmpty) { t.cancel(); _corruptedTimers.remove(t); return; }

      int fromIndex = currentPositions[Random().nextInt(currentPositions.length)];
      List<int> dirs = [-1, 1, -gridSize, gridSize];
      dirs.shuffle();
      for (int d in dirs) {
        int toIndex = fromIndex + d;
        int currentX = fromIndex % gridSize;
        int nextX = toIndex % gridSize;
        if ((d == 1 && nextX == 0) || (d == -1 && currentX == gridSize - 1)) continue;

        if (toIndex >= 0 && toIndex < _board.length && _board[toIndex] == null) {
          setState(() {
            _board[toIndex] = colorKey;
            _board[fromIndex] = null;
          });
          break;
        }
      }
    });
    _corruptedTimers.add(timer);
  }

  void _runGarbageCollection() {
    List<int> rowsToClear = [];
    List<int> colsToClear = [];

    for (int y = 0; y < gridSize; y++) {
      bool full = true;
      for (int x = 0; x < gridSize; x++) {
        if (_board[y * gridSize + x] == null) { full = false; break; }
      }
      if (full) rowsToClear.add(y);
    }
    for (int x = 0; x < gridSize; x++) {
      bool full = true;
      for (int y = 0; y < gridSize; y++) {
        if (_board[y * gridSize + x] == null) { full = false; break; }
      }
      if (full) colsToClear.add(x);
    }

    if (rowsToClear.isEmpty && colsToClear.isEmpty) {
      _comboCount = 0;
      return;
    }

    // COMBO LOGIC
    _comboCount++;
    _comboController.forward(from: 0.0);
    _triggerShake();
    HapticFeedback.mediumImpact();

    int totalBlocksCleared = (rowsToClear.length * gridSize) + (colsToClear.length * gridSize);
    // Exponential combo bonus
    int pointsGained = (totalBlocksCleared * 2) + (_comboCount * 20);
    int kbCleaned = (totalBlocksCleared * 10);
    int corruptionBonus = 0;

    // Juice: Particles
    Set<int> clearedIndices = {};
    
    for (int y in rowsToClear) {
      for (int x = 0; x < gridSize; x++) {
        int idx = y * gridSize + x;
        if(clearedIndices.contains(idx)) continue;
        clearedIndices.add(idx);
        
        Color? c = _board[idx];
        if (c == _bugColor) corruptionBonus += 50;
        _spawnExplosion(x, y, c ?? _ditaBlue);
      }
    }
    for (int x in colsToClear) {
      for (int y = 0; y < gridSize; y++) {
         int idx = y * gridSize + x;
         if(clearedIndices.contains(idx)) continue;
         clearedIndices.add(idx);

         Color? c = _board[idx];
         if (c == _bugColor) corruptionBonus += 50;
         _spawnExplosion(x, y, c ?? _ditaBlue);
      }
    }

    pointsGained += corruptionBonus;

    String sentiment = "OPTIMIZED!";
    if (_comboCount > 1) sentiment = "COMBO x$_comboCount!";
    if (_comboCount > 3) sentiment = "UNSTOPPABLE!";
    if (corruptionBonus > 0) sentiment = "BUG PURGED!";

    Color textColor = (_comboCount > 1) ? _ditaGold : Theme.of(context).primaryColor;
    if (Theme.of(context).brightness == Brightness.dark) textColor = Colors.white;

    _showFloatingText(sentiment, "+$pointsGained", textColor);

    setState(() {
      _scoreKB += kbCleaned;
      _sessionPoints += pointsGained;
      _currentTotalPoints += pointsGained;

      for (int idx in clearedIndices) {
        _board[idx] = null;
      }
    });
  }

  void _showFloatingText(String sentiment, String points, Color color) {
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.35,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.5 + (0.5 * value),
                child: Opacity(
                  opacity: (1 - value).clamp(0.0, 1.0),
                  child: Column(
                    children: [
                      Text(
                          sentiment,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: color,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(blurRadius: 10, color: Colors.black.withOpacity(0.5), offset: const Offset(2,2))]
                          )
                      ),
                      Text(
                          points,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(blurRadius: 5, color: Colors.black.withOpacity(0.5))]
                          )
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 1200), () => overlayEntry.remove());
  }

  void _checkGameOver() {
    bool possible = false;
    for (var shape in _availableShapesInSlot) {
      if (shape == null) continue;
      for (int i = 0; i < gridSize * gridSize; i++) {
        if (_canPlace(shape, i % gridSize, i ~/ gridSize)) {
          possible = true; break;
        }
      }
      if (possible) break;
    }
    if (!possible) {
      _triggerCrash();
    }
  }

  // --- SAVE & EXIT LOGIC ---

  void _triggerCrash() {
    setState(() => _isGameOver = true);
    HapticFeedback.vibrate();

    if (_hasRevived) {
      _endGame();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("System Crash!", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("Out of memory. Watch an ad to clear a 3x3 block and continue?"),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _endGame(); },
            child: const Text("Exit"),
          ),
          ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); _watchAdToResume(); },
            icon: const Icon(Icons.play_circle_fill),
            label: const Text("Emergency Reboot"),
            style: ElevatedButton.styleFrom(backgroundColor: _ditaBlue, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _watchAdToResume() {
    AdManager.showRewardedAd(
        onReward: () {
          setState(() {
            _isGameOver = false;
            _hasRevived = true;
            // Clear center 3x3
            int centerStart = (gridSize ~/ 2) - 1;
            for(int y=centerStart; y<centerStart+3; y++) {
               for(int x=centerStart; x<centerStart+3; x++) {
                 int idx = y * gridSize + x;
                 if(_board[idx] != null) _spawnExplosion(x, y, _board[idx]!);
                 _board[idx] = null;
               }
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Emergency Reboot Successful!"), backgroundColor: Colors.green)
          );
        },
        onFailure: () => _endGame()
    );
  }

  Future<void> _saveGameData() async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_scoreKB > _localHighScore) {
        await prefs.setInt('ram_high_score', _scoreKB);
        setState(() => _localHighScore = _scoreKB);
      }
      int userId = 0;
      if (widget.user['id'] is int) userId = widget.user['id'];
      else if (widget.user['id'] is String) userId = int.tryParse(widget.user['id']) ?? 0;

      if (userId != 0) {
        await ApiService.updateUser(userId, {"points": _currentTotalPoints});
      }
    } catch (e) {
      debugPrint("Save Error: $e");
    } finally {
      _isSaving = false;
    }
  }


  Future<void> _endGame() async {
    await _saveGameData();

    if(!mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Optimization Complete"),
          content: Text(
            "Report:\n\nFreed: $_scoreKB KB\nSession: $_sessionPoints Pts\n\nTotal: $_currentTotalPoints Pts",
          ),
          actions: [
            TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text("Close")),
            ElevatedButton(onPressed: () { Navigator.pop(ctx); _resetGame(); }, child: const Text("Re-Optimize")),
          ],
        )
    );
  }

  void _resetGame() {
    _cancelAllTimers();
    setState(() {
      _board = List.filled(gridSize * gridSize, null);
      _scoreKB = 0;
      _sessionPoints = 0;
      _comboCount = 0;
      _isGameOver = false;
      _hasRevived = false;
      _particles.clear();
      _fillAllSlots();
    });
  }

  // --- PREVIEW HELPERS ---
  bool _isPreviewCell(int index) {
    if (_hoverAnchorIndex == null || _hoverShape == null) return false;
    int anchorX = (_hoverAnchorIndex! % gridSize) - _hoverXOffset;
    int anchorY = (_hoverAnchorIndex! ~/ gridSize) - _hoverYOffset;

    for (var p in _hoverShape!) {
      int targetX = anchorX + p.x;
      int targetY = anchorY + p.y;
      int targetIndex = targetY * gridSize + targetX;
      if (targetIndex == index) return true;
    }
    return false;
  }

  bool _isValidPreview() {
    if (_hoverAnchorIndex == null || _hoverShape == null) return false;
    int anchorX = (_hoverAnchorIndex! % gridSize) - _hoverXOffset;
    int anchorY = (_hoverAnchorIndex! ~/ gridSize) - _hoverYOffset;
    return _canPlace(_hoverShape!, anchorX, anchorY);
  }

  @override
  Widget build(BuildContext context) {
    // Shake calculation
    double shakeOffset = sin(_shakeController.value * pi * 4) * _shakeAnimation.value;

    double screenWidth = MediaQuery.of(context).size.width;
    double boardPadding = 16.0;
    double totalBoardWidth = screenWidth - (boardPadding * 2);
    // Adjust block size slightly to account for shadows
    double blockSize = (totalBoardWidth - (gridSpacing * (gridSize - 1))) / gridSize;

    // Theme Colors
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color cardColor = Theme.of(context).cardColor;
    final Color scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final Color textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) AdManager.showInterstitialAd();
        await _saveGameData();
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: const Text("RAM Optimizer", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          centerTitle: true,
          backgroundColor: primaryColor,
          elevation: 0,
          foregroundColor: textColor,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. STATS BAR
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4)
                      )
                    ]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildScoreCard("MEMORY FREED", "$_scoreKB KB", Icons.sd_storage, textColor),
                    ScaleTransition(
                        scale: _comboScale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _ditaBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _ditaBlue.withOpacity(0.3))
                          ),
                          child: Column(
                            children: [
                              Text("$_sessionPoints", style: TextStyle(color: _ditaBlue, fontSize: 24, fontWeight: FontWeight.w900)),
                              const Text("POINTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5))
                            ],
                          ),
                        )
                    ),
                    _buildScoreCard("HIGH SCORE", "${max(_localHighScore, _scoreKB)}", Icons.emoji_events, textColor),
                  ],
                ),
              ),

              const Spacer(),

              // 2. GAME BOARD
              Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: totalBoardWidth,
                        height: totalBoardWidth,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                            ]
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: gridSize * gridSize,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridSize,
                            crossAxisSpacing: gridSpacing,
                            mainAxisSpacing: gridSpacing,
                          ),
                          itemBuilder: (ctx, index) {
                            bool isPreview = _isPreviewCell(index);
                            bool isValid = _isValidPreview();
                            Color? cellColor = _board[index];

                            return DragTarget<int>(
                              onWillAcceptWithDetails: (details) {
                                int slotIndex = details.data;
                                var shape = _availableShapesInSlot[slotIndex]!;
                                int maxX = 0;
                                for(var p in shape) { if(p.x > maxX) maxX = p.x; }
                                int xOff = (maxX + 1) ~/ 2;
                                setState(() {
                                  _hoverAnchorIndex = index;
                                  _hoverShape = shape;
                                  _hoverColor = _slotColors[slotIndex]; // Capture color for ghost preview
                                  _hoverXOffset = xOff;
                                  _hoverYOffset = 0;
                                });
                                return true;
                              },
                              onLeave: (_) {
                                setState(() { _hoverAnchorIndex = null; _hoverShape = null; _hoverColor = null; });
                              },
                              onAcceptWithDetails: (details) {
                                int slotIndex = details.data;
                                var shape = _availableShapesInSlot[slotIndex]!;
                                int maxX = 0; for(var p in shape) { if(p.x > maxX) maxX = p.x; }
                                int xOff = (maxX + 1) ~/ 2;
                                int targetX = (index % gridSize) - xOff;
                                int targetY = (index ~/ gridSize);

                                setState(() { _hoverAnchorIndex = null; _hoverShape = null; _hoverColor = null; });

                                if (_canPlace(shape, targetX, targetY)) {
                                  _placeShape(shape, _slotColors[slotIndex]!, targetX, targetY);
                                  _generateSingleShape(slotIndex);
                                  _runGarbageCollection();
                                } else {
                                  HapticFeedback.vibrate();
                                }
                              },
                              builder: (context, candidates, rejects) {
                                if (cellColor != null) {
                                  // 3D RENDERED BLOCK
                                  return CustomPaint(
                                    painter: Block3DPainter(color: cellColor),
                                  );
                                } else if (isPreview) {
                                  // PREVIEW GHOST (Now 3D and colored)
                                  return Opacity(
                                    opacity: 0.5,
                                    child: CustomPaint(
                                      painter: Block3DPainter(
                                        color: isValid ? (_hoverColor ?? Colors.grey) : Colors.red
                                      ),
                                    ),
                                  );
                                } else {
                                  // EMPTY SLOT
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),

                      // 2. PARTICLE OVERLAY (Visual Effects)
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size(totalBoardWidth, totalBoardWidth),
                          painter: ParticlePainter(_particles, blockSize, gridSpacing),
                        ),
                      )
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // 3. SHAPE TRAY
              Container(
                height: 180,
                padding: const EdgeInsets.fromLTRB(10, 30, 10, 20),
                decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (index) {
                    var shape = _availableShapesInSlot[index];
                    if (shape == null) return const SizedBox(width: 80, height: 80);
                    Color shapeColor = _slotColors[index]!;

                    // Calc size for centering
                    int maxX = 0; int maxY = 0;
                    for(var p in shape) {
                      if(p.x > maxX) maxX = p.x;
                      if(p.y > maxY) maxY = p.y;
                    }
                    double previewBlockSize = 25.0; // Smaller in tray
                    double shapeWidth = (maxX + 1) * previewBlockSize;
                    double shapeHeight = (maxY + 1) * previewBlockSize;
                    
                    // Drag Anchor Adjustment
                    double dragBlockSize = blockSize * 0.9; // Slightly smaller when dragging

                    return Draggable<int>(
                      data: index,
                      dragAnchorStrategy: (draggable, context, position) {
                        // Keep anchor at the visual center of the first block row to prevent obscuring
                        return Offset((maxX+1)*dragBlockSize/2, dragBlockSize/2);
                      },
                      onDragStarted: () => HapticFeedback.selectionClick(),
                      feedback: Transform.scale(
                        scale: 1.15, // Lift effect
                        child: Material(
                          color: Colors.transparent,
                          elevation: 10, // Shadow for 3D depth
                          shadowColor: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          child: CustomPaint(
                            size: Size((maxX+1)*dragBlockSize, (maxY+1)*dragBlockSize),
                            painter: BoardShapePainter(shape: shape, color: shapeColor, blockSize: dragBlockSize),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: SizedBox(
                          width: 80, height: 80,
                          child: Center(
                            child: CustomPaint(
                              size: Size(shapeWidth, shapeHeight),
                              painter: BoardShapePainter(shape: shape, color: shapeColor, blockSize: previewBlockSize),
                            ),
                          ),
                        ),
                      ),
                      child: SizedBox(
                        width: 80, height: 80,
                        child: Center(
                          child: CustomPaint(
                            size: Size(shapeWidth, shapeHeight),
                            painter: BoardShapePainter(shape: shape, color: shapeColor, blockSize: previewBlockSize),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// --- 3D PAINTERS ---

/// Renders a single block with a sophisticated 3D Bevel and Texture effect
class Block3DPainter extends CustomPainter {
  final Color color;
  Block3DPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Setup Colors
    // Highlight (Top/Left)
    final Color highlight = Colors.white.withOpacity(0.4);
    // Shadow (Bottom/Right)
    final Color shadow = Colors.black.withOpacity(0.3);
    // Deep Shadow (Bottom Edge for height)
    final Color deepShadow = HSLColor.fromColor(color).withLightness((HSLColor.fromColor(color).lightness - 0.2).clamp(0.0, 1.0)).toColor();
    
    final double bevel = size.width * 0.15;
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    // 2. Draw Deep Bottom Shadow (Height simulation)
    final Rect heightRect = Rect.fromLTWH(0, bevel, size.width, size.height);
    final RRect heightRRect = RRect.fromRectAndRadius(heightRect, const Radius.circular(6));
    canvas.drawRRect(heightRRect, Paint()..color = deepShadow);

    // 3. Draw Main Face Base
    canvas.drawRRect(rrect, Paint()..color = color);

    // 4. Draw Bevels (Triangular paths for sharp 3D look)
    final Path topBevel = Path()
      ..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width - bevel, bevel)..lineTo(bevel, bevel)..close();
    canvas.drawPath(topBevel, Paint()..color = highlight);

    final Path leftBevel = Path()
      ..moveTo(0, 0)..lineTo(0, size.height)..lineTo(bevel, size.height - bevel)..lineTo(bevel, bevel)..close();
    canvas.drawPath(leftBevel, Paint()..color = highlight);

    final Path rightBevel = Path()
      ..moveTo(size.width, 0)..lineTo(size.width, size.height)..lineTo(size.width - bevel, size.height - bevel)..lineTo(size.width - bevel, bevel)..close();
    canvas.drawPath(rightBevel, Paint()..color = shadow);

    final Path bottomBevel = Path()
      ..moveTo(0, size.height)..lineTo(size.width, size.height)..lineTo(size.width - bevel, size.height - bevel)..lineTo(bevel, size.height - bevel)..close();
    canvas.drawPath(bottomBevel, Paint()..color = shadow);

    // 5. Draw Inner Face (The textured part)
    final Rect innerRect = Rect.fromLTWH(bevel, bevel, size.width - (bevel * 2), size.height - (bevel * 2));
    
    // Texture: Subtle scanlines/stripes
    canvas.save();
    canvas.clipRect(innerRect);
    final Paint texturePaint = Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 1.0;
    for(double i = -size.height; i < size.width; i+=4) {
       canvas.drawLine(Offset(i, size.height), Offset(i + size.height, 0), texturePaint);
    }
    canvas.restore();
    
    // 6. Final Gloss Shine (Top Left Curve)
    final Path shine = Path()
      ..moveTo(bevel + 2, bevel + 10)
      ..quadraticBezierTo(bevel + 2, bevel + 2, bevel + 10, bevel + 2);
    canvas.drawPath(shine, Paint()..color = Colors.white.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant Block3DPainter oldDelegate) => oldDelegate.color != color;
}

/// Renders a complex shape composed of multiple 3D blocks
class BoardShapePainter extends CustomPainter {
  final List<Point<int>> shape;
  final Color color;
  final double blockSize;

  BoardShapePainter({required this.shape, required this.color, required this.blockSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in shape) {
      // Calculate offset for this specific block
      double px = p.x * blockSize;
      double py = p.y * blockSize;
      
      // We essentially reuse the logic from Block3DPainter but translated
      canvas.save();
      canvas.translate(px, py);
      
      // Draw 3D Block (Miniaturized logic for performance)
      // We pass a smaller size to create gaps between blocks in a shape
      double gap = 2.0;
      double bSize = blockSize - gap;
      
      Block3DPainter(color: color).paint(canvas, Size(bSize, bSize));
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- PARTICLES ---

class Particle {
  double x, y;
  double vx, vy;
  double size;
  double life;
  Color color;

  Particle({required this.x, required this.y, required this.color})
      : vx = (Random().nextDouble() - 0.5) * 0.4,
        vy = (Random().nextDouble() - 0.5) * 0.4,
        size = Random().nextDouble() * 5 + 3,
        life = 1.0;

  void update() {
    x += vx;
    y += vy;
    life -= 0.04;
    size *= 0.96;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double blockSize;
  final double gridSpacing;

  ParticlePainter(this.particles, this.blockSize, this.gridSpacing);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      double px = p.x * (blockSize + gridSpacing) + (blockSize/2);
      double py = p.y * (blockSize + gridSpacing) + (blockSize/2);

      final paint = Paint()
        ..color = p.color.withOpacity(p.life.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px, py), p.size, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}