import 'dart:async';
import 'dart:math';
import 'package:dita_app/services/ads_helper.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dita_app/services/api_service.dart';

class SnakeGameScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const SnakeGameScreen({super.key, required this.user});

  @override
  State<SnakeGameScreen> createState() => _SnakeGameScreenState();
}

enum Direction { up, down, left, right }
enum PowerUpType { doubleScore, speedBoost, slowMo, ghostMode, megaPoint }

class _SnakeGameScreenState extends State<SnakeGameScreen> with TickerProviderStateMixin {
  // --- CONFIG ---
  static const int rows = 30;
  static const int columns = 20;
  static const int baseSpeed = 250; 

  // --- GAME ENTITIES ---
  List<Point<int>> _snake = [];
  Point<int>? _food;
  List<Point<int>> _obstacles = [];
  List<_GameItem> _activePowerUps = [];
  List<_Particle> _particles = [];

  // --- STATE ---
  Direction _direction = Direction.up;
  Direction _nextDirection = Direction.up;
  Timer? _timer;
  int _currentSpeed = baseSpeed;
   
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSaving = false;
  bool _hasRevived = false; // Track if user used their one revive
   
  // SCORING
  int _score = 0; 
  late int _totalUserPoints; 
  int _localHighScore = 0;   

  // COMBO SYSTEM
  int _comboMultiplier = 1;
  DateTime _lastEatTime = DateTime.now();
  double _comboMeter = 0.0;

  // ACTIVE EFFECTS
  bool _isGhost = false;
  bool _doubleScore = false;
  Timer? _effectTimer;

  // VISUALS
  late AnimationController _pulseController;
  int _skinIndex = 0;
  final List<Color> _skinColors = [Colors.greenAccent, Colors.cyanAccent, Colors.purpleAccent, Colors.redAccent];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Load Ads (Interstitial + Rewarded)
    AdManager.loadAds();
    
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _resetGameState();
  }

  Future<void> _loadData() async {
    if (widget.user['points'] != null) {
      _totalUserPoints = int.tryParse(widget.user['points'].toString()) ?? 0;
    } else {
      _totalUserPoints = 0;
    }

    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _localHighScore = prefs.getInt('snake_high_score') ?? 0;
      });
    }
  }

  void _resetGameState() {
    _snake = [const Point(10, 10), const Point(10, 11), const Point(10, 12)];
    _food = null;
    _obstacles = [];
    _activePowerUps = [];
    _particles = [];
    _score = 0;
    _currentSpeed = baseSpeed;
    _direction = Direction.up;
    _nextDirection = Direction.up;
    _comboMultiplier = 1;
    _comboMeter = 0.0;
    _isGhost = false;
    _doubleScore = false;
    _hasRevived = false; // Reset revive ability
  }

  @override
  void dispose() {
    _timer?.cancel();
    _effectTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // --- GAME LOOP ---

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _resetGameState();
      _generateFood();
      _generateObstacles(3);
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _currentSpeed), (timer) {
      _updateGame();
    });
  }

  void _updateGame() {
    setState(() {
      _moveSnake();
      _updateParticles();
      _updateCombo();
    });
  }

  void _updateCombo() {
    if (_comboMeter > 0) {
      _comboMeter -= 0.05; 
      if (_comboMeter <= 0) {
        _comboMeter = 0;
        _comboMultiplier = 1;
      }
    }
  }

  void _updateParticles() {
    _particles.removeWhere((p) => p.life <= 0);
    for (var p in _particles) {
      p.update();
    }
  }

  void _moveSnake() {
    _direction = _nextDirection;
    
    Point<int> currentHead = _snake.first;
    Point<int> newHead;

    switch (_direction) {
      case Direction.up:    newHead = Point(currentHead.x, currentHead.y - 1); break;
      case Direction.down:  newHead = Point(currentHead.x, currentHead.y + 1); break;
      case Direction.left:  newHead = Point(currentHead.x - 1, currentHead.y); break;
      case Direction.right: newHead = Point(currentHead.x + 1, currentHead.y); break;
    }

    // 1. Collision Logic
    if (_isGhost) {
      // Wrap around logic
      if (newHead.x < 0) newHead = Point(columns - 1, newHead.y);
      if (newHead.x >= columns) newHead = Point(0, newHead.y);
      if (newHead.y < 0) newHead = Point(newHead.x, rows - 1);
      if (newHead.y >= rows) newHead = Point(newHead.x, 0);
    } else {
      // Standard Collision (Walls, Self, Obstacles)
      if (newHead.x < 0 || newHead.x >= columns || 
          newHead.y < 0 || newHead.y >= rows || 
          _snake.contains(newHead) || 
          _obstacles.contains(newHead)) {
        
        // --- CRASH DETECTED ---
        _handleCrash();
        return;
      }
    }

    _snake.insert(0, newHead);

    // 2. Interaction Checks
    if (newHead == _food) {
      _handleEatFood();
    } else {
      // Check PowerUps
      int pIndex = _activePowerUps.indexWhere((p) => p.pos == newHead);
      if (pIndex != -1) {
        _activatePowerUp(_activePowerUps[pIndex].type);
        _activePowerUps.removeAt(pIndex);
        _snake.removeLast(); 
      } else {
        _snake.removeLast();
      }
    }
  }

  // --- REVIVE / CRASH LOGIC ---

  void _handleCrash() {
    _timer?.cancel(); // Pause game
    _effectTimer?.cancel();
    setState(() => _isPlaying = false);

    if (!_hasRevived) {
      // Offer Revive
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text("SYSTEM CRASHED!", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: const Text("Watch a short ad to activate Emergency Ghost Mode and continue?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _gameOver(); // User declined
              },
              child: const Text("GIVE UP"),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _watchAdToRevive();
              },
              icon: const Icon(Icons.play_circle_fill),
              label: const Text("REVIVE"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            )
          ],
        ),
      );
    } else {
      // Already revived once, straight to Game Over
      _gameOver();
    }
  }

  void _watchAdToRevive() {
    AdManager.showRewardedAd(
      onReward: () {
        // Success! Revive Logic
        setState(() {
          _hasRevived = true;
          _isPlaying = true;
          // Activate Ghost Mode so they don't immediately crash again
          _activatePowerUp(PowerUpType.ghostMode);
          
          // Move snake slightly if stuck in wall (Optional, Ghost mode handles it mostly)
          // Just resume timer
          _startTimer();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("👻 SYSTEM RESTORED! Ghost Mode Active."), backgroundColor: Colors.green)
        );
      },
      onFailure: () {
        // Ad failed or cancelled
        _gameOver();
      }
    );
  }

  void _handleEatFood() {
    _spawnExplosion(_snake.first, Colors.orange);
    
    // Scoring & Points
    int points = 10 * _comboMultiplier * (_doubleScore ? 2 : 1);
    _score += points;
    _totalUserPoints += points;
    
    // Combo Logic
    DateTime now = DateTime.now();
    if (now.difference(_lastEatTime).inMilliseconds < 2000) {
      _comboMeter = 1.0;
      if (_comboMultiplier < 5) _comboMultiplier++;
    } else {
      _comboMeter = 0.5; // Start fresh combo
      _comboMultiplier = 1;
    }
    _lastEatTime = now;

    // Difficulty Scaling
    if (_score % 100 == 0) {
      _generateObstacles(2); 
      if (_currentSpeed > 100) {
        _currentSpeed = (_currentSpeed * 0.95).toInt();
        _startTimer();
      }
    }

    // Chance to spawn PowerUp (20%)
    if (Random().nextInt(5) == 0) _generatePowerUp();

    _generateFood();
  }

  void _activatePowerUp(PowerUpType type) {
    if (type != PowerUpType.ghostMode) {
      // Don't spawn particles for auto-revive ghost mode to keep it clean
       _spawnExplosion(_snake.first, Colors.white);
    }
    
    // Cancel previous effects
    _effectTimer?.cancel();
    if (_currentSpeed != 100 && _currentSpeed != 400) _currentSpeed = baseSpeed; 
    
    _isGhost = false;
    _doubleScore = false;

    switch (type) {
      case PowerUpType.megaPoint:
        _score += 50;
        _totalUserPoints += 50;
        _startTimer(); 
        break;
      case PowerUpType.speedBoost:
        _currentSpeed = 100; // Fast
        _startTimer();
        _setEffectTimeout();
        break;
      case PowerUpType.slowMo:
        _currentSpeed = 400; // Slow
        _startTimer();
        _setEffectTimeout();
        break;
      case PowerUpType.ghostMode:
        _isGhost = true;
        _setEffectTimeout();
        break;
      case PowerUpType.doubleScore:
        _doubleScore = true;
        _setEffectTimeout();
        break;
    }
  }

  void _setEffectTimeout() {
    _effectTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isGhost = false;
          _doubleScore = false;
          if (_currentSpeed != 100 && _currentSpeed != 400) _currentSpeed = baseSpeed;
          _startTimer();
        });
      }
    });
  }

  void _spawnExplosion(Point<int> pos, Color color) {
    for (int i = 0; i < 8; i++) {
      double angle = (pi * 2 * i) / 8;
      _particles.add(_Particle(
        x: pos.x.toDouble(), 
        y: pos.y.toDouble(), 
        vx: cos(angle) * 0.2, 
        vy: sin(angle) * 0.2, 
        color: color
      ));
    }
  }

  // --- GENERATORS ---

  void _generateFood() {
    _food = _findEmptySpot();
  }

  void _generatePowerUp() {
    Point<int> pos = _findEmptySpot();
    PowerUpType type = PowerUpType.values[Random().nextInt(PowerUpType.values.length)];
    _activePowerUps.add(_GameItem(pos, type));
  }

  void _generateObstacles(int count) {
    for(int i=0; i<count; i++) {
      _obstacles.add(_findEmptySpot());
    }
  }

  Point<int> _findEmptySpot() {
    Random rng = Random();
    Point<int> p;
    do {
      p = Point(rng.nextInt(columns), rng.nextInt(rows));
    } while (_snake.contains(p) || _obstacles.contains(p) || p == _food);
    return p;
  }

  // --- SAVE & EXIT LOGIC ---

  void _gameOver() async {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });
    
    await _saveGameData();
  }

  Future<void> _saveGameData() async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Save High Score LOCALLY
      if (_score > _localHighScore) {
        await prefs.setInt('snake_high_score', _score);
        setState(() {
          _localHighScore = _score;
        });
      }

      // 2. Save Points to BACKEND
      int userId = 0;
      if (widget.user['id'] is int) userId = widget.user['id'];
      else if (widget.user['id'] is String) userId = int.tryParse(widget.user['id']) ?? 0;

      if (userId != 0) {
        await ApiService.updateUser(userId, {"points": _totalUserPoints});
        print("✅ Snake Saved: Points=$_totalUserPoints, HighScore=$_localHighScore");
      }
    } catch (e) {
      print("Error saving snake data: $e");
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _onBackPressed() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saving Progress..."), duration: Duration(milliseconds: 800))
    );
    await _saveGameData();
    if (mounted) Navigator.pop(context);
  }

  // --- CONTROLS ---

  void _handleVerticalDrag(DragUpdateDetails details) {
    if (_direction == Direction.left || _direction == Direction.right) {
      _nextDirection = details.delta.dy > 0 ? Direction.down : Direction.up;
    }
  }

  void _handleHorizontalDrag(DragUpdateDetails details) {
    if (_direction == Direction.up || _direction == Direction.down) {
      _nextDirection = details.delta.dx > 0 ? Direction.right : Direction.left;
    }
  }

  void _cycleSkin() {
    setState(() {
      _skinIndex = (_skinIndex + 1) % _skinColors.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final snakeColor = _isGhost ? Colors.white.withOpacity(0.5) : _skinColors[_skinIndex];

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
          title: const Text("Data Snake V2", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: primaryColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _onBackPressed,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.palette, color: Colors.white),
              tooltip: "Change Skin",
              onPressed: _cycleSkin,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  "$_score", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)
                ),
              ),
            )
          ],
        ),
        body: Column(
          children: [
            // TOP STATS
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).cardColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(Icons.monetization_on, "Balance", "$_totalUserPoints"),
                  _buildStat(Icons.emoji_events, "High Score", "${max(_localHighScore, _score)}"),
                  _buildStat(Icons.speed, "Speed", _currentSpeed < 150 ? "MAX" : "${((baseSpeed - _currentSpeed)/2).toInt()}%"),
                ],
              ),
            ),

            // COMBO BAR
            LinearProgressIndicator(
              value: _comboMeter,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(_comboMultiplier > 1 ? Colors.orangeAccent : Colors.transparent),
              minHeight: 4,
            ),
            
            // GAME AREA
            Expanded(
              child: GestureDetector(
                onVerticalDragUpdate: _handleVerticalDrag,
                onHorizontalDragUpdate: _handleHorizontalDrag,
                child: Container(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: columns / rows,
                      child: Stack(
                        children: [
                          // Game Board
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
                              color: isDark ? Colors.black : Colors.white,
                            ),
                            child: CustomPaint(
                              painter: SnakePainter(
                                snake: _snake, 
                                food: _food, 
                                obstacles: _obstacles,
                                powerUps: _activePowerUps,
                                particles: _particles,
                                rows: rows, 
                                cols: columns,
                                snakeColor: snakeColor,
                                gridColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                pulse: _pulseController.value,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                          
                          // Game Over Overlay
                          if (_isGameOver)
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.broken_image, color: Colors.redAccent, size: 60),
                                    const SizedBox(height: 10),
                                    const Text("SYSTEM CRASHED", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                    Text("Score: $_score", style: const TextStyle(color: Colors.white70, fontSize: 18)),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: _startGame,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)
                                      ),
                                      child: const Text("REBOOT SYSTEM", style: TextStyle(color: Colors.white)),
                                    )
                                  ],
                                ),
                              ),
                            ),

                          // Start Overlay
                          if (!_isPlaying && !_isGameOver)
                            Container(
                              color: Colors.black45,
                              child: Center(
                                child: ElevatedButton.icon(
                                  onPressed: _startGame,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text("INITIALIZE"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)
                                  ),
                                ),
                              ),
                            ),
                            
                          // UI Elements (Combo, Effects)
                          if (_comboMultiplier > 1 && _isPlaying)
                            Positioned(
                              top: 20, right: 20,
                              child: Text(
                                "COMBO x$_comboMultiplier!",
                                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 20, shadows: [Shadow(blurRadius: 10, color: Colors.red)]),
                              ),
                            ),
                            
                          if (_isGhost)
                            const Positioned(bottom: 20, left: 20, child: Text("👻 GHOST MODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          if (_doubleScore)
                            const Positioned(bottom: 20, right: 20, child: Text("🍒 DOUBLE SCORE", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // 3. BANNER AD AT BOTTOM
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
   
  Widget _buildStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

// --- HELPER CLASSES ---

class _GameItem {
  Point<int> pos;
  PowerUpType type;
  _GameItem(this.pos, this.type);
}

class _Particle {
  double x, y, vx, vy;
  double life = 1.0;
  Color color;
  _Particle({required this.x, required this.y, required this.vx, required this.vy, required this.color});
   
  void update() {
    x += vx;
    y += vy;
    life -= 0.05;
  }
}

class SnakePainter extends CustomPainter {
  final List<Point<int>> snake;
  final Point<int>? food;
  final List<Point<int>> obstacles;
  final List<_GameItem> powerUps;
  final List<_Particle> particles;
   
  final int rows;
  final int cols;
  final Color snakeColor;
  final Color gridColor;
  final double pulse; 

  SnakePainter({
    required this.snake, 
    required this.food, 
    required this.obstacles,
    required this.powerUps,
    required this.particles,
    required this.rows, 
    required this.cols,
    required this.snakeColor,
    required this.gridColor,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double cellW = size.width / cols;
    double cellH = size.height / rows;

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()..color = gridColor..style = PaintingStyle.stroke;

    // Grid
    for(int c = 0; c <= cols; c++) canvas.drawLine(Offset(c * cellW, 0), Offset(c * cellW, size.height), strokePaint);
    for(int r = 0; r <= rows; r++) canvas.drawLine(Offset(0, r * cellH), Offset(size.width, r * cellH), strokePaint);

    // Obstacles
    fillPaint.color = Colors.grey;
    for (var o in obstacles) {
      canvas.drawRect(Rect.fromLTWH(o.x * cellW, o.y * cellH, cellW, cellH), fillPaint);
      canvas.drawRect(Rect.fromLTWH(o.x * cellW + 2, o.y * cellH + 2, cellW - 4, cellH - 4), Paint()..color = Colors.black12);
    }

    // Food
    if (food != null) {
      fillPaint.color = Colors.orangeAccent.withOpacity(0.8 + (pulse * 0.2));
      canvas.drawCircle(Offset((food!.x * cellW) + cellW/2, (food!.y * cellH) + cellH/2), (cellW/2) - 1 + pulse, fillPaint);
    }

    // PowerUps
    for (var p in powerUps) {
      switch(p.type) {
        case PowerUpType.megaPoint: fillPaint.color = Colors.cyan; break;
        case PowerUpType.speedBoost: fillPaint.color = Colors.yellow; break;
        case PowerUpType.slowMo: fillPaint.color = Colors.blue; break;
        case PowerUpType.ghostMode: fillPaint.color = Colors.white; break;
        case PowerUpType.doubleScore: fillPaint.color = Colors.pink; break;
      }
      canvas.drawRect(Rect.fromLTWH(p.pos.x * cellW + 2, p.pos.y * cellH + 2, cellW - 4, cellH - 4), fillPaint);
    }

    // Snake
    fillPaint.color = snakeColor;
    for (int i = 0; i < snake.length; i++) {
      var p = snake[i];
      if (i == 0) fillPaint.color = snakeColor.withOpacity(1.0);
      else fillPaint.color = snakeColor.withOpacity(0.4 + ((snake.length - i) / snake.length) * 0.6);
       
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(p.x * cellW + 1, p.y * cellH + 1, cellW - 2, cellH - 2), const Radius.circular(4)), 
        fillPaint
      );
    }

    // Particles
    for (var p in particles) {
      fillPaint.color = p.color.withOpacity(p.life);
      canvas.drawCircle(Offset(p.x * cellW + cellW/2, p.y * cellH + cellH/2), 3 * p.life, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) => true;
}