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
  
  // --- THEME CONSTANTS (DITA) ---
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
  int _hoverXOffset = 0;
  int _hoverYOffset = 0;

  // --- SENTIMENTS ---
  final List<String> _praisePhrases = [
    "OPTIMIZED!", "CLEAN CODE!", "MEMORY FREED!", "BUG SQUASHED!", 
    "SYSTEM PURGED!", "EXCELLENT!", "SMOOTH!", "PERFECT FIT!"
  ];
  
  // Professional Palette (Matches Navy/White backgrounds)
  final List<Color> _processColors = [
    const Color(0xFF0EA5E9), // Sky Blue
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF6366F1), // Indigo
    const Color(0xFFEC4899), // Pink
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFF14B8A6), // Teal
  ];

  // --- BASE SHAPES ---
  final List<List<Point<int>>> _baseShapes = [
    [const Point(0,0)], 
    [const Point(0,0), const Point(0,1)], 
    [const Point(0,0), const Point(1,0)], 
    [const Point(0,0), const Point(0,1), const Point(1,0), const Point(1,1)], 
    [const Point(0,0), const Point(1,0), const Point(2,0)], 
    [const Point(0,0), const Point(0,1), const Point(0,2)], 
    [const Point(0,0), const Point(1,0), const Point(0,1)], 
    [const Point(0,0), const Point(1,0), const Point(2,0), const Point(1,1)], 
    [const Point(0,0), const Point(0,1), const Point(0,2), const Point(1,2)], 
    [const Point(0,0), const Point(1,0), const Point(2,0), const Point(3,0)],
  ];

  final List<List<Point<int>>?> _availableShapesInSlot = [null, null, null];
  final List<Color?> _slotColors = [null, null, null];

  @override
  void initState() {
    super.initState();
    _loadData();
    AdManager.loadAds();
    _fillAllSlots();
    
    // Combo Animation (Safe Bounds 0.0 -> 1.0)
    _comboController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _comboScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _comboController, curve: Curves.elasticOut)
    );

    // Shake Animation
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _shakeAnimation = Tween<double>(begin: 0, end: 6).animate(
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
    for (int i = 0; i < 6; i++) {
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
        title: Text("How to Optimize", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("1. Drag blocks to allocate RAM."),
            SizedBox(height: 8),
            Text("2. Fill rows or columns to clear memory."),
            SizedBox(height: 8),
            Text("3. Watch out for Red Bugs! Clear them quickly."),
          ],
        ),
        actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Start Optimizing")
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
    List<Point<int>> newShape = List.from(_baseShapes[Random().nextInt(_baseShapes.length)]);
    bool flipX = Random().nextBool();
    bool flipY = Random().nextBool();
      
    if (flipX || flipY) {
      newShape = newShape.map((p) => Point(flipX ? -p.x : p.x, flipY ? -p.y : p.y)).toList();
      int minX = newShape.map((p) => p.x).reduce(min);
      int minY = newShape.map((p) => p.y).reduce(min);
      newShape = newShape.map((p) => Point(p.x - minX, p.y - minY)).toList();
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
    bool isCorrupted = Random().nextInt(15) == 0; 
    Color finalColor = isCorrupted ? _bugColor : color;
      
    int kbGained = shape.length * 10;
    int pointsGained = shape.length; 

    HapticFeedback.lightImpact(); 
    if(shape.length > 4) _triggerShake();

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
        SnackBar(content: const Text("⚠️ Memory Leak Detected! (Bug)"), backgroundColor: _bugColor, duration: const Duration(seconds: 1))
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
    _comboController.forward(from: 0.0); // Play scale animation
    _triggerShake(); 
    HapticFeedback.mediumImpact(); 

    int totalBlocksCleared = (rowsToClear.length * gridSize) + (colsToClear.length * gridSize);
    int pointsGained = (totalBlocksCleared * 2) * _comboCount; 
    int kbCleaned = (totalBlocksCleared * 10) * _comboCount;
    int corruptionBonus = 0;

    // Juice: Particles
    for (int y in rowsToClear) {
      for (int x = 0; x < gridSize; x++) {
        Color? c = _board[y * gridSize + x];
        if (c == _bugColor) corruptionBonus += 50;
        _spawnExplosion(x, y, c ?? _ditaBlue);
      }
    }
    for (int x in colsToClear) {
      for (int y = 0; y < gridSize; y++) {
        if (!rowsToClear.contains(y)) {
           Color? c = _board[y * gridSize + x];
           if (c == _bugColor) corruptionBonus += 50;
           _spawnExplosion(x, y, c ?? _ditaBlue);
        }
      }
    }

    pointsGained += corruptionBonus;

    // --- SENTIMENT & FLOATING TEXT ---
    String sentiment = _praisePhrases[Random().nextInt(_praisePhrases.length)];
    if (corruptionBonus > 0) sentiment = "BUG PURGED!";
    
    // Pick color for text: Gold if combo/high score, Primary otherwise
    Color textColor = (_comboCount > 1 || pointsGained > 50) ? _ditaGold : Theme.of(context).primaryColor;
    // In Dark mode, primary color might be too dark for floating text, so ensure visibility
    if (Theme.of(context).brightness == Brightness.dark && textColor == _ditaBlue) {
      textColor = Colors.white;
    }

    _showFloatingText(sentiment, "+$pointsGained Pts", textColor);

    setState(() {
      _scoreKB += kbCleaned;
      _sessionPoints += pointsGained;
      _currentTotalPoints += pointsGained; 

      for (int y in rowsToClear) {
        for (int x = 0; x < gridSize; x++) { _board[y * gridSize + x] = null; }
      }
      for (int x in colsToClear) {
        for (int y = 0; y < gridSize; y++) { _board[y * gridSize + x] = null; }
      }
    });
  }

  void _showFloatingText(String sentiment, String points, Color color) {
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.3,
        left: 0, 
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * value), // Float Up
                child: Opacity(
                  opacity: (1 - value).clamp(0.0, 1.0),
                  child: Column(
                    children: [
                      Text(
                        sentiment, 
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color, 
                          fontSize: 28, 
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black.withOpacity(0.3))]
                        )
                      ),
                      Text(
                        points, 
                        style: TextStyle(
                          color: color.withOpacity(0.9), 
                          fontSize: 20, 
                          fontWeight: FontWeight.bold
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
    Future.delayed(const Duration(milliseconds: 1500), () => overlayEntry.remove());
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
        title: const Text("Out of Memory", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("No moves left. Watch a quick ad to clear 30% of memory and continue?"),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _endGame(); },
            child: const Text("Exit"),
          ),
          ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); _watchAdToResume(); },
            icon: const Icon(Icons.play_circle_fill),
            label: const Text("Resume Game"),
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
          int totalBlocks = gridSize * gridSize;
          int blocksToClear = (totalBlocks * 0.3).toInt();
          
          List<int> filledIndices = [];
          for (int i=0; i < _board.length; i++) {
            if (_board[i] != null) filledIndices.add(i);
          }
          
          filledIndices.shuffle();
          for (int i=0; i < min(blocksToClear, filledIndices.length); i++) {
            int idx = filledIndices[i];
            _spawnExplosion(idx % gridSize, idx ~/ gridSize, _board[idx]!);
            _board[idx] = null;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Memory Freed! Resuming..."), backgroundColor: Colors.green)
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
        title: const Text("Session Ended"),
        content: Text(
            "Final Report:\n\nOptimized: $_scoreKB KB\nSession Points: $_sessionPoints\n\nTotal Balance: $_currentTotalPoints",
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text("Exit")),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); _resetGame(); }, child: const Text("Restart")),
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
    double boardPadding = 24.0;
    double totalBoardWidth = screenWidth - boardPadding;
    double blockSize = (totalBoardWidth - (gridSpacing * (gridSize - 1)) - 16) / gridSize; 
    
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
          title: const Text("RAM Optimizer", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. STATS BAR
              Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4)
                    )
                  ]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildScoreCard("MEMORY", "$_scoreKB KB", Icons.memory, textColor),
                    Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
                    ScaleTransition(
                      scale: _comboScale,
                      child: _buildScoreCard("POINTS", "$_sessionPoints", Icons.stars, isDark ? _ditaGold : primaryColor)
                    ),
                    Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, spreadRadius: 2)
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

                            return DragTarget<int>(
                              onWillAcceptWithDetails: (details) {
                                int slotIndex = details.data;
                                var shape = _availableShapesInSlot[slotIndex]!;
                                int maxX = 0; int maxY = 0;
                                for(var p in shape) {
                                  if(p.x > maxX) maxX = p.x;
                                  if(p.y > maxY) maxY = p.y;
                                }
                                int xOff = (maxX + 1) ~/ 2;
                                setState(() {
                                  _hoverAnchorIndex = index;
                                  _hoverShape = shape;
                                  _hoverXOffset = xOff;
                                  _hoverYOffset = 0;
                                });
                                return true;
                              },
                              onLeave: (_) {
                                setState(() { _hoverAnchorIndex = null; _hoverShape = null; });
                              },
                              onAcceptWithDetails: (details) {
                                int slotIndex = details.data;
                                var shape = _availableShapesInSlot[slotIndex]!;
                                int maxX = 0; for(var p in shape) { if(p.x > maxX) maxX = p.x; }
                                int xOff = (maxX + 1) ~/ 2;
                                int targetX = (index % gridSize) - xOff;
                                int targetY = (index ~/ gridSize);

                                setState(() { _hoverAnchorIndex = null; _hoverShape = null; });
                                
                                if (_canPlace(shape, targetX, targetY)) {
                                  _placeShape(shape, _slotColors[slotIndex]!, targetX, targetY);
                                  _generateSingleShape(slotIndex); 
                                  _runGarbageCollection();
                                } else {
                                   HapticFeedback.vibrate(); 
                                }
                              },
                              builder: (context, candidates, rejects) {
                                final color = _board[index];
                                
                                if (color != null) {
                                  // FILLED BLOCK
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(color: color.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))
                                      ]
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: blockSize * 0.3, 
                                        height: blockSize * 0.3, 
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2), 
                                          shape: BoxShape.circle
                                        )
                                      )
                                    ),
                                  );
                                } else if (isPreview) {
                                  // PREVIEW BLOCK
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isValid ? primaryColor.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isValid ? primaryColor : Colors.red, width: 2)
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
                height: 160,
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(3, (index) {
                    var shape = _availableShapesInSlot[index];
                    if (shape == null) return const SizedBox(width: 80);
                    Color shapeColor = _slotColors[index]!;

                    int maxX = 0; int maxY = 0;
                    for(var p in shape) {
                      if(p.x > maxX) maxX = p.x;
                      if(p.y > maxY) maxY = p.y;
                    }
                    double width = (maxX + 1) * blockSize;
                    double visXOffset = width / 2;
                    double visYOffset = blockSize / 2; 

                    return Draggable<int>(
                      data: index,
                      dragAnchorStrategy: pointerDragAnchorStrategy,
                      onDragStarted: () => HapticFeedback.selectionClick(),
                      feedback: Transform.translate(
                        offset: Offset(-visXOffset, -visYOffset),
                        child: Material(
                          color: Colors.transparent,
                          child: CustomPaint(
                            size: Size(blockSize * 4, blockSize * 4), 
                            painter: BoardShapePainter(shape: shape, color: shapeColor, blockSize: blockSize),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.2,
                        child: _buildShapePreview(shape, shapeColor, isDark),
                      ),
                      child: _buildShapePreview(shape, shapeColor, isDark),
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
      children: [
        Icon(icon, size: 20, color: color.withOpacity(0.7)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10, letterSpacing: 1.0)),
      ],
    );
  }

  Widget _buildShapePreview(List<Point<int>> shape, Color color, bool isDark) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(50, 50),
          painter: BoardShapePainter(shape: shape, color: color, blockSize: 10),
        ),
      ),
    );
  }
}

// --- PAINTERS ---

class Particle {
  double x, y;
  double vx, vy;
  double size;
  double life;
  Color color;

  Particle({required this.x, required this.y, required this.color}) 
      : vx = (Random().nextDouble() - 0.5) * 0.5,
        vy = (Random().nextDouble() - 0.5) * 0.5,
        size = Random().nextDouble() * 6 + 2,
        life = 1.0;

  void update() {
    x += vx;
    y += vy;
    life -= 0.05;
    size *= 0.95;
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

class BoardShapePainter extends CustomPainter {
  final List<Point<int>> shape;
  final Color color;
  final double blockSize;

  BoardShapePainter({required this.shape, required this.color, required this.blockSize});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color..style = PaintingStyle.fill;
    double gap = 2.0; 

    for (var p in shape) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x * blockSize, p.y * blockSize, blockSize - gap, blockSize - gap), 
          const Radius.circular(6)
        ),
        paint
      );
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}