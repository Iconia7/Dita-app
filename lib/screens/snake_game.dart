import 'dart:async';
import 'dart:math';
import 'package:dita_app/services/ads_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dita_app/services/api_service.dart';

// --- THEME CONSTANTS ---
const Color kDeepSlate = Color(0xFF0F172A);
const Color kSurface = Color(0xFF1E293B);
const Color kNeonBlue = Color(0xFF38BDF8);
const Color kNeonGreen = Color(0xFF4ADE80);
const Color kNeonRed = Color(0xFFEF4444);
const Color kDitaGold = Color(0xFFFFD700);

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
  static const int baseSpeed = 200; 

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
  bool _hasRevived = false;
   
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
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late Ticker _ticker;

  // SKINS (Cyber Theme)
  int _skinIndex = 0;
  final List<Color> _skinColors = [kNeonBlue, kNeonGreen, Color(0xFFD946EF), kDitaGold];

  @override
  void initState() {
    super.initState();
    _loadData();
    AdManager.loadAds();
    
    // Pulse Animation (Food Glow)
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    
    // Shake Animation (Impact)
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut)
    )..addListener(() => setState((){}));

    // Particle Loop
    _ticker = createTicker(_updateParticles)..start();

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
    _hasRevived = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _effectTimer?.cancel();
    _pulseController.dispose();
    _shakeController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  // --- FX HELPERS ---
  
  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward().then((value) => _shakeController.reverse());
  }

  void _updateParticles(Duration elapsed) {
    if (_particles.isEmpty) return;
    // We don't need setState here usually if using a specialized loop, 
    // but since we repaint the whole CustomPaint via state, we'll clean list here
    // and let the game loop trigger the repaint or the pulse controller.
    _particles.removeWhere((p) => p.life <= 0);
    for (var p in _particles) {
      p.update();
    }
  }

  void _spawnExplosion(Point<int> pos, Color color) {
    for (int i = 0; i < 12; i++) {
      double angle = (pi * 2 * i) / 12;
      double speed = 0.2 + Random().nextDouble() * 0.3;
      _particles.add(_Particle(
        x: pos.x.toDouble(), 
        y: pos.y.toDouble(), 
        vx: cos(angle) * speed, 
        vy: sin(angle) * speed, 
        color: color
      ));
    }
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
      _updateCombo();
    });
  }

  void _updateCombo() {
    if (_comboMeter > 0) {
      _comboMeter -= 0.02; // Decay slower
      if (_comboMeter <= 0) {
        _comboMeter = 0;
        _comboMultiplier = 1;
      }
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
      // Standard Collision
      if (newHead.x < 0 || newHead.x >= columns || 
          newHead.y < 0 || newHead.y >= rows || 
          _snake.contains(newHead) || 
          _obstacles.contains(newHead)) {
        
        _triggerShake();
        HapticFeedback.heavyImpact();
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
    _timer?.cancel(); 
    _effectTimer?.cancel();
    setState(() => _isPlaying = false);

    if (!_hasRevived) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kNeonRed)),
          title: const Text("CONNECTION LOST", style: TextStyle(color: kNeonRed, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
          content: const Text("System crash detected.\nEstablish emergency uplink (Watch Ad) to activate GHOST PROTOCOL?", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _gameOver();
              },
              child: const Text("ABORT", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _watchAdToRevive();
              },
              icon: const Icon(Icons.wifi_tethering),
              label: const Text("RECONNECT"),
              style: ElevatedButton.styleFrom(backgroundColor: kNeonBlue, foregroundColor: Colors.black),
            )
          ],
        ),
      );
    } else {
      _gameOver();
    }
  }

  void _watchAdToRevive() {
    AdManager.showRewardedAd(
      onReward: () {
        setState(() {
          _hasRevived = true;
          _isPlaying = true;
          _activatePowerUp(PowerUpType.ghostMode); // Ghost logic handles timer restart
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("GHOST PROTOCOL INITIATED"), backgroundColor: kNeonBlue)
        );
      },
      onFailure: () => _gameOver()
    );
  }

  void _handleEatFood() {
    HapticFeedback.lightImpact();
    _spawnExplosion(_snake.first, kDitaGold);
    
    // Scoring & Points
    int points = 10 * _comboMultiplier * (_doubleScore ? 2 : 1);
    _score += points;
    _totalUserPoints += points;
    
    // Combo Logic
    DateTime now = DateTime.now();
    if (now.difference(_lastEatTime).inMilliseconds < 3000) {
      _comboMeter = 1.0;
      if (_comboMultiplier < 5) _comboMultiplier++;
    } else {
      _comboMeter = 0.5; 
      _comboMultiplier = 1;
    }
    _lastEatTime = now;

    // Difficulty Scaling
    if (_score % 100 == 0) {
      _generateObstacles(2); 
      if (_currentSpeed > 80) {
        _currentSpeed = (_currentSpeed * 0.95).toInt();
        _startTimer();
      }
    }

    if (Random().nextInt(5) == 0) _generatePowerUp();
    _generateFood();
  }

  void _activatePowerUp(PowerUpType type) {
    if (type != PowerUpType.ghostMode) {
       _spawnExplosion(_snake.first, Colors.white);
       _triggerShake();
    }
    
    _effectTimer?.cancel();
    // Reset speed unless we are applying a speed modifier
    if (type != PowerUpType.speedBoost && type != PowerUpType.slowMo) {
       if (_currentSpeed == 80 || _currentSpeed == 400) _currentSpeed = baseSpeed;
    }
    
    _isGhost = false;
    _doubleScore = false;

    switch (type) {
      case PowerUpType.megaPoint:
        _score += 50;
        _totalUserPoints += 50;
        _showFloatingText("DATA UPLOAD +50", kNeonBlue);
        _startTimer(); 
        break;
      case PowerUpType.speedBoost:
        _currentSpeed = 80; // Fast
        _showFloatingText("OVERCLOCK!", kNeonRed);
        _startTimer();
        _setEffectTimeout();
        break;
      case PowerUpType.slowMo:
        _currentSpeed = 300; // Slow
        _showFloatingText("SYSTEM LAG...", kNeonBlue);
        _startTimer();
        _setEffectTimeout();
        break;
      case PowerUpType.ghostMode:
        _isGhost = true;
        _startTimer(); // Ensure timer is running if coming from revive
        _setEffectTimeout();
        break;
      case PowerUpType.doubleScore:
        _doubleScore = true;
        _showFloatingText("2X BANDWIDTH", Colors.pinkAccent);
        _setEffectTimeout();
        break;
    }
  }

  void _showFloatingText(String text, Color color) {
    // Simplified juice text wrapper (logic identical to previous games)
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
         backgroundColor: Colors.transparent,
         elevation: 0,
         duration: const Duration(milliseconds: 800),
       )
    );
  }

  void _setEffectTimeout() {
    _effectTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isGhost = false;
          _doubleScore = false;
          // Reset speed modifiers
          if (_currentSpeed == 80 || _currentSpeed == 300) _currentSpeed = baseSpeed;
          _startTimer();
        });
      }
    });
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

  // --- SAVE & EXIT ---

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

      if (_score > _localHighScore) {
        await prefs.setInt('snake_high_score', _score);
        setState(() => _localHighScore = _score);
      }

      int userId = 0;
      if (widget.user['id'] is int) {
        userId = widget.user['id'];
      } else if (widget.user['id'] is String) userId = int.tryParse(widget.user['id']) ?? 0;

      if (userId != 0) {
        await ApiService.updateUser(userId, {"points": _totalUserPoints});
      }
    } catch (e) {
      debugPrint("Error saving snake data: $e");
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _onBackPressed() async {
    await _saveGameData();
    if (mounted) Navigator.pop(context);
  }

  // --- CONTROLS ---

  void _handleVerticalDrag(DragUpdateDetails details) {
    if (_direction == Direction.left || _direction == Direction.right) {
      // Sensitivity check to prevent accidental U-turns
      if (details.delta.dy.abs() > 5) {
        _nextDirection = details.delta.dy > 0 ? Direction.down : Direction.up;
      }
    }
  }

  void _handleHorizontalDrag(DragUpdateDetails details) {
    if (_direction == Direction.up || _direction == Direction.down) {
      if (details.delta.dx.abs() > 5) {
        _nextDirection = details.delta.dx > 0 ? Direction.right : Direction.left;
      }
    }
  }

  void _cycleSkin() {
    setState(() {
      _skinIndex = (_skinIndex + 1) % _skinColors.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    // Current Skin Color
    final snakeColor = _isGhost ? Colors.white.withOpacity(0.5) : _skinColors[_skinIndex];
    
    // Shake Offset
    double shakeOffset = sin(_shakeController.value * pi * 4) * _shakeAnimation.value;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) AdManager.showInterstitialAd();
        await _saveGameData();
      },
      child: Scaffold(
        backgroundColor: isDark ? kDeepSlate : scaffoldBg,
        appBar: AppBar(
          title: const Text("DATA STREAM // SNAKE", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Courier')),
          elevation: 0,
          backgroundColor: primaryColor,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color.fromARGB(255, 255, 255, 255)),
            onPressed: _onBackPressed,
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.palette, color: snakeColor),
              onPressed: _cycleSkin,
            ),
          ],
        ),
        body: Column(
          children: [
            // 1. STATS HUD
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStat("SCORE", "$_score", kNeonBlue),
                  _buildStat("HIGH", "${max(_localHighScore, _score)}", kDitaGold),
                  _buildStat("CREDITS", "$_totalUserPoints", kNeonGreen),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // COMBO BAR
            if (_isPlaying)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _comboMeter,
                    backgroundColor: kSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _comboMultiplier >= 5 ? Colors.redAccent : (_comboMultiplier > 1 ? Colors.orangeAccent : Colors.transparent)
                    ),
                    minHeight: 6,
                  ),
                ),
              ),

            const SizedBox(height: 10),
            
            // 2. GAME AREA
            Expanded(
              child: Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: GestureDetector(
                  onVerticalDragUpdate: _handleVerticalDrag,
                  onHorizontalDragUpdate: _handleHorizontalDrag,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B101A), // Darker than slate for board
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kNeonBlue.withOpacity(0.3), width: 1),
                      boxShadow: [BoxShadow(color: kNeonBlue.withOpacity(0.1), blurRadius: 20)]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate exact cell size to fit container
                          return CustomPaint(
                            painter: SnakePainter(
                              snake: _snake, 
                              food: _food, 
                              obstacles: _obstacles,
                              powerUps: _activePowerUps,
                              particles: _particles,
                              rows: rows, 
                              cols: columns,
                              snakeColor: snakeColor,
                              gridColor: Colors.white.withOpacity(0.03),
                              pulse: _pulseController.value,
                              isGhost: _isGhost
                            ),
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                          );
                        }
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. OVERLAY STATUS
            if (_comboMultiplier > 1 && _isPlaying)
              Text("COMBO x$_comboMultiplier", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),

            if (_isGameOver)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                   onPressed: _startGame,
                   icon: const Icon(Icons.refresh),
                   label: const Text("REBOOT SYSTEM"),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: kNeonBlue, 
                     foregroundColor: Colors.black,
                     padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)
                   ),
                ),
              ),

             if (!_isPlaying && !_isGameOver)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                   onPressed: _startGame,
                   icon: const Icon(Icons.play_arrow),
                   label: const Text("INITIALIZE STREAM"),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: kNeonGreen, 
                     foregroundColor: Colors.black,
                     padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)
                   ),
                ),
              ),

            // 4. BANNER AD
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
   
  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color, fontFamily: 'Courier')),
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
  final bool isGhost;

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
    required this.isGhost,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double cellW = size.width / cols;
    double cellH = size.height / rows;

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);

    // 1. Draw Grid
    final Paint gridPaint = Paint()..color = gridColor..style = PaintingStyle.stroke;
    for(int c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * cellW, 0), Offset(c * cellW, size.height), gridPaint);
    }
    for(int r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * cellH), Offset(size.width, r * cellH), gridPaint);
    }

    // 2. Obstacles (Firewalls)
    for (var o in obstacles) {
      fillPaint.color = Colors.redAccent.withOpacity(0.2);
      canvas.drawRect(Rect.fromLTWH(o.x * cellW, o.y * cellH, cellW, cellH), fillPaint);
      
      // X mark
      final p = Paint()..color = Colors.redAccent..strokeWidth = 2;
      canvas.drawLine(Offset(o.x * cellW + 4, o.y * cellH + 4), Offset(o.x * cellW + cellW - 4, o.y * cellH + cellH - 4), p);
      canvas.drawLine(Offset(o.x * cellW + cellW - 4, o.y * cellH + 4), Offset(o.x * cellW + 4, o.y * cellH + cellH - 4), p);
    }

    // 3. Food (Data Packets)
    if (food != null) {
      Offset center = Offset((food!.x * cellW) + cellW/2, (food!.y * cellH) + cellH/2);
      
      // Glow
      glowPaint.color = kDitaGold.withOpacity(0.6 + (pulse * 0.4));
      canvas.drawCircle(center, (cellW/2) + pulse * 2, glowPaint);
      
      // Core
      fillPaint.color = Colors.white;
      canvas.drawCircle(center, (cellW/2) - 3, fillPaint);
    }

    // 4. PowerUps
    for (var p in powerUps) {
      Color pColor;
      switch(p.type) {
        case PowerUpType.megaPoint: pColor = Colors.cyan; break;
        case PowerUpType.speedBoost: pColor = Colors.redAccent; break;
        case PowerUpType.slowMo: pColor = Colors.blue; break;
        case PowerUpType.ghostMode: pColor = Colors.white; break;
        case PowerUpType.doubleScore: pColor = Colors.pink; break;
      }
      fillPaint.color = pColor;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.pos.x * cellW + 2, p.pos.y * cellH + 2, cellW - 4, cellH - 4), const Radius.circular(4)), fillPaint);
    }

    // 5. Snake (Data Stream)
    for (int i = 0; i < snake.length; i++) {
      var p = snake[i];
      double opacity = isGhost ? 0.3 : (0.4 + ((snake.length - i) / snake.length) * 0.6);
      fillPaint.color = snakeColor.withOpacity(opacity);
      
      if (i == 0 && !isGhost) {
        // Head Glow
        canvas.drawCircle(Offset(p.x * cellW + cellW/2, p.y * cellH + cellH/2), cellW/1.5, Paint()..color = snakeColor.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        fillPaint.color = snakeColor; // Solid head
      }
        
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(p.x * cellW + 1, p.y * cellH + 1, cellW - 2, cellH - 2), const Radius.circular(4)), 
        fillPaint
      );
    }

    // 6. Particles
    for (var p in particles) {
      fillPaint.color = p.color.withOpacity(p.life.clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(p.x * cellW + cellW/2, p.y * cellH + cellH/2, 4 * p.life, 4 * p.life), fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SnakePainter oldDelegate) => true;
}