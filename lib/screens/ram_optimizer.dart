import 'dart:async';
import 'dart:math';
import 'package:dita_app/services/ads_helper.dart';
import 'package:flutter/material.dart';
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
   
  // --- STATE ---
  List<Color?> _board = List.filled(gridSize * gridSize, null);
  final List<Timer> _corruptedTimers = []; 
   
  int _scoreKB = 0; // Current Session Score
  int _sessionPoints = 0; // Points earned THIS session
   
  late int _currentTotalPoints; // Master points (synced with backend)
  int _localHighScore = 0; // Master High Score (Local Storage)

  bool _isGameOver = false;
  bool _isSaving = false;
  bool _hasRevived = false;

  // --- HOVER STATE ---
  int? _hoverAnchorIndex;
  List<Point<int>>? _hoverShape;
  int _hoverXOffset = 0;
  int _hoverYOffset = 0;

  // --- THEME ---
  late Color _emptyColor;
  late Color _gridLineColor;
  final Color _corruptedColor = const Color(0xFF6A1B9A); 
   
  final List<Color> _processColors = [
    Colors.cyan, Colors.greenAccent, Colors.orangeAccent, Colors.blueAccent, Colors.pinkAccent,
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
  ];

  List<List<Point<int>>?> _availableShapesInSlot = [null, null, null];
  List<Color?> _slotColors = [null, null, null];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Pre-load Ads (Banner + Interstitial + Rewarded)
    AdManager.loadAds();
    
    _fillAllSlots();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showInstructions());
  }

  Future<void> _loadData() async {
    // 1. Load Total Points from Backend User Object
    if (widget.user['points'] != null) {
      _currentTotalPoints = int.tryParse(widget.user['points'].toString()) ?? 0;
    } else {
      _currentTotalPoints = 0;
    }

    // 2. Load High Score from Local Storage
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
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("RAM OPTIMIZER+", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("1. DRAG shapes to allocate memory."),
            const SizedBox(height: 8),
            const Text("2. The block places exactly under your finger."),
            const SizedBox(height: 8),
            const Text("⚠️ Watch out for Purple Corrupted Blocks!"),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("START"))],
      ),
    );
  }

  // --- GAME LOGIC ---

  void _fillAllSlots() {
    for(int i=0; i<3; i++) _generateSingleShape(i);
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
    bool isCorrupted = Random().nextInt(10) == 0; 
    Color finalColor = isCorrupted ? _corruptedColor : color;
     
    // Scoring
    int kbGained = shape.length * 10;
    int pointsGained = shape.length; 

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
        SnackBar(content: const Text("⚠️ Corrupted Block Detected!"), backgroundColor: _corruptedColor, duration: const Duration(seconds: 1))
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
        if ((d == 1 && nextX == 0) || (d == -1 && currentX == 0)) continue; 
        
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

    if (rowsToClear.isEmpty && colsToClear.isEmpty) return;

    int totalBlocksCleared = (rowsToClear.length * gridSize) + (colsToClear.length * gridSize);
    int pointsGained = totalBlocksCleared * 2; 
    int kbCleaned = totalBlocksCleared * 10;
    int corruptionBonus = 0;

    for (int y in rowsToClear) {
      for (int x = 0; x < gridSize; x++) {
        if (_board[y * gridSize + x] == _corruptedColor) corruptionBonus += 50;
      }
    }
    for (int x in colsToClear) {
      for (int y = 0; y < gridSize; y++) {
        if (_board[y * gridSize + x] == _corruptedColor) corruptionBonus += 50;
      }
    }

    pointsGained += corruptionBonus;

    if (corruptionBonus > 0) {
      _showFloatingText("PURGED! +$corruptionBonus", _corruptedColor);
    } else {
      _showFloatingText("+$pointsGained Pts!", Colors.amber);
    }

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

  void _showFloatingText(String text, Color color) {
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.4,
        left: MediaQuery.of(context).size.width * 0.3,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -60 * value),
                child: Opacity(
                  opacity: 1 - value,
                  child: Text(text, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold, shadows: const [Shadow(blurRadius: 10, color: Colors.black)])),
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
    setState(() => _isGameOver = true); // Pause placement
    
    // Check if player has already revived
    if (_hasRevived) {
      _endGame(); // Already revived once, game over
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("OUT OF MEMORY", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("No available moves.\nWatch a short ad to purge 30% of system memory and continue?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endGame(); // Give up
            },
            child: const Text("EXIT", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _watchAdToResume();
            },
            icon: const Icon(Icons.cleaning_services),
            label: const Text("PURGE RAM"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
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
          // Clear 30% of random blocks to make space
          int totalBlocks = gridSize * gridSize;
          int blocksToClear = (totalBlocks * 0.3).toInt();
          
          List<int> filledIndices = [];
          for (int i=0; i < _board.length; i++) {
            if (_board[i] != null) filledIndices.add(i);
          }
          
          filledIndices.shuffle();
          for (int i=0; i < min(blocksToClear, filledIndices.length); i++) {
            _board[filledIndices[i]] = null;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ MEMORY PURGED. SYSTEM RESUMED."), backgroundColor: Colors.green)
        );
      },
      onFailure: () {
        _endGame();
      }
    );
  }

  Future<void> _saveGameData() async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      if (_scoreKB > _localHighScore) {
        await prefs.setInt('ram_high_score', _scoreKB);
        setState(() {
          _localHighScore = _scoreKB;
        });
      }

      int userId = 0;
      if (widget.user['id'] is int) userId = widget.user['id'];
      else if (widget.user['id'] is String) userId = int.tryParse(widget.user['id']) ?? 0;

      if (userId != 0) {
        await ApiService.updateUser(userId, {"points": _currentTotalPoints});
        print("✅ RAM Saved: Points=$_currentTotalPoints");
      }
    } catch (e) {
      print("Save Error: $e");
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _onBackPressed() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saving Progress..."), duration: Duration(milliseconds: 800))
    );
    // Ad logic handled by PopScope
    await _saveGameData();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _endGame() async {
    await _saveGameData();

    if(!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("SYSTEM HALTED"),
        content: Text("Final Report:\n\nKB Cleared: $_scoreKB\nSession Points: $_sessionPoints\n\nTotal Balance: $_currentTotalPoints"),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text("Exit")),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); _resetGame(); }, child: const Text("Reboot")),
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
      _isGameOver = false;
      _hasRevived = false;
      _fillAllSlots();
    });
  }

  // --- PREVIEW HELPERS ---
  bool _isPreviewCell(int index) {
    if (_hoverAnchorIndex == null || _hoverShape == null) return false;
     
    // Use the stored offsets calculated during DragTarget.onWillAccept
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _emptyColor = isDark ? const Color(0xFF1E293B) : Colors.grey[200]!;
    _gridLineColor = isDark ? Colors.white10 : Colors.black12;

    double screenWidth = MediaQuery.of(context).size.width;
    double boardPadding = 24.0;
    double totalBoardWidth = screenWidth - boardPadding;
    double blockSize = (totalBoardWidth - (gridSpacing * (gridSize - 1)) - 16) / gridSize; 

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          AdManager.showInterstitialAd();
        }
        await _saveGameData();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("RAM Optimizer+", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Theme.of(context).primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white), 
            onPressed: _onBackPressed 
          ),
        ),
        body: Column(
          children: [
            Container(
              color: Theme.of(context).primaryColor,
              padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildScoreCard("MEMORY", "$_scoreKB KB", Icons.memory),
                  _buildScoreCard("HIGH SCORE", "${max(_localHighScore, _scoreKB)}", Icons.emoji_events, color: Colors.yellowAccent),
                  _buildScoreCard("POINTS", "$_sessionPoints", Icons.monetization_on, color: Colors.amberAccent),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            Expanded(
              child: Center(
                child: Container(
                  width: totalBoardWidth,
                  height: totalBoardWidth, 
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)]
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
                        onWillAccept: (slotIndex) {
                          if (slotIndex != null) {
                             var shape = _availableShapesInSlot[slotIndex]!;
                             
                             // Calculate dynamic offset based on shape size
                             int maxX = 0; int maxY = 0;
                             for(var p in shape) {
                               if(p.x > maxX) maxX = p.x;
                               if(p.y > maxY) maxY = p.y;
                             }

                             // --- CHANGED ---
                             // Centers Horizontally, but keeps Vertical offset to 0.
                             // This means the "Finger" is on Row 0 of the shape.
                             int xOff = (maxX + 1) ~/ 2;
                             int yOff = 0; 

                             setState(() {
                               _hoverAnchorIndex = index;
                               _hoverShape = shape;
                               _hoverXOffset = xOff;
                               _hoverYOffset = yOff;
                             });
                          }
                          return true;
                        },
                        onLeave: (_) {
                          setState(() { _hoverAnchorIndex = null; _hoverShape = null; });
                        },
                        onAccept: (slotIndex) {
                          var shape = _availableShapesInSlot[slotIndex]!;
                          
                          int maxX = 0; int maxY = 0;
                          for(var p in shape) {
                             if(p.x > maxX) maxX = p.x;
                             if(p.y > maxY) maxY = p.y;
                          }
                          
                          // --- CHANGED ---
                          // Must match onWillAccept logic
                          int xOff = (maxX + 1) ~/ 2;
                          int yOff = 0;

                          int targetX = (index % gridSize) - xOff;
                          int targetY = (index ~/ gridSize) - yOff;

                          setState(() { _hoverAnchorIndex = null; _hoverShape = null; });
                          
                          if (_canPlace(shape, targetX, targetY)) {
                            _placeShape(shape, _slotColors[slotIndex]!, targetX, targetY);
                            _generateSingleShape(slotIndex); 
                            _runGarbageCollection();
                          } else {
                            // Optional: Shake effect or error sound
                          }
                        },
                        builder: (context, candidates, rejects) {
                          final color = _board[index];
                          Color? cellColor = color ?? _emptyColor;
                          if (isPreview) {
                            cellColor = isValid ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5);
                          }
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(4),
                              border: color != null ? null : Border.all(color: _gridLineColor),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            Container(
              height: 180,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]
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
                  // double height = (maxY + 1) * blockSize; // Unused in new logic
                  
                  // --- CHANGED ---
                  // Visual Offset: We only center X.
                  // For Y, we shift it slightly so the finger is in the center of the TOP block.
                  double visXOffset = width / 2;
                  double visYOffset = blockSize / 2; 

                  return Draggable<int>(
                    data: index,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Transform.translate(
                      // Offset matches the visual anchor
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
                      opacity: 0.3,
                      child: _buildShapePreview(shape, shapeColor),
                    ),
                    child: _buildShapePreview(shape, shapeColor),
                  );
                }),
              ),
            ),
            // 3. BANNER AD AT BOTTOM
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, String value, IconData icon, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildShapePreview(List<Point<int>> shape, Color color) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(50, 50),
          painter: BoardShapePainter(shape: shape, color: color, blockSize: 12),
        ),
      ),
    );
  }
}

class BoardShapePainter extends CustomPainter {
  final List<Point<int>> shape;
  final Color color;
  final double blockSize; 

  BoardShapePainter({required this.shape, required this.color, required this.blockSize});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color..style = PaintingStyle.fill;
    
    // We draw relative to 0,0, which works perfectly with the new "Direct Drag" logic
    // where 0,0 is under the finger.
    double gap = 2.0; 

    for (var p in shape) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x * blockSize, p.y * blockSize, blockSize - gap, blockSize - gap), 
          const Radius.circular(4)
        ),
        paint
      );
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}