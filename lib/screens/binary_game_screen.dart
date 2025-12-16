import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:dita_app/services/api_service.dart';
import 'package:dita_app/services/ads_helper.dart';

// --- THEME CONSTANTS ---
const Color kDeepSlate = Color(0xFF0F172A);
const Color kSurface = Color(0xFF1E293B);
const Color kDitaBlue = Color(0xFF003366);
const Color kNeonBlue = Color(0xFF38BDF8); // Player Color
const Color kNeonRed = Color(0xFFEF4444);  // AI/Enemy Color
const Color kDitaGold = Color(0xFFFFD700); // Win Color

enum GameMode { ai, friend }
enum GameDifficulty { easy, medium, hard } // 🟢 Added Difficulty Enum

class GameScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final dynamic userId; // Added to match constructor usage
  const GameScreen({super.key, required this.user, required this.userId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Game Config
  GameMode _mode = GameMode.ai;
  GameDifficulty _difficulty = GameDifficulty.medium; // 🟢 Default Difficulty
   
  // Game State
  List<String> _board = List.filled(9, "");
  String _currentPlayer = "1"; 
  bool _isGameOver = false;
  bool _isAiThinking = false;
  
  // Winning Logic
  List<int>? _winningPattern; 
   
  // User Points
  late int _currentTotalPoints;

  // --- ANIMATION CONTROLLERS ---
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  // Particles
  final List<Particle> _particles = [];
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    AdManager.loadInterstitialAd();
    
    // Points Init
    _currentTotalPoints = (widget.user['points'] is int) 
        ? widget.user['points'] 
        : int.tryParse(widget.user['points'].toString()) ?? 0;

    // Shake Animation (Impact Effect)
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut)
    )..addListener(() => setState((){}));

    // Particle System
    _ticker = createTicker(_updateParticles)..start();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _ticker.dispose();
    super.dispose();
  }

  // --- FX LOGIC ---

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward().then((value) => _shakeController.reverse());
    HapticFeedback.lightImpact();
  }

  void _updateParticles(Duration elapsed) {
    if (_particles.isEmpty) return;
    setState(() {
      for (var p in _particles) { p.update(); }
      _particles.removeWhere((p) => p.life <= 0);
    });
  }

  void _spawnExplosion(List<int> indices, Color color) {
    for (int index in indices) {
      int row = index ~/ 3;
      int col = index % 3;
      double x = (col - 1) * 100.0; 
      double y = (row - 1) * 100.0;

      for (int i = 0; i < 15; i++) {
        _particles.add(Particle(x: x, y: y, color: color));
      }
    }
  }

  // --- GAME LOGIC ---

  void _handleTap(int index) {
    if (_board[index] != "" || _isGameOver || _isAiThinking) return;

    _triggerShake(); // JUICE: Shake on every move

    setState(() {
      _board[index] = _currentPlayer;
    });

    if (_checkWin(_currentPlayer, setPattern: true)) {
      _endGame(_currentPlayer);
    } else if (_board.every((element) => element != "")) {
      _endGame("Draw");
    } else {
      _switchTurn();
    }
  }

  void _switchTurn() {
    if (_mode == GameMode.friend) {
      setState(() {
        _currentPlayer = _currentPlayer == "1" ? "0" : "1";
      });
    } else {
      _aiMove();
    }
  }

  void _aiMove() async {
    setState(() => _isAiThinking = true);
    
    // Thinking delay
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    int bestMove = _findBestMove();
    
    // AI Move Effect
    HapticFeedback.selectionClick(); 
    
    setState(() {
      _board[bestMove] = "0"; 
      _isAiThinking = false;
    });

    if (_checkWin("0", setPattern: true)) {
      _endGame("0");
    } else if (_board.every((element) => element != "")) {
      _endGame("Draw");
    }
  }

  int _findBestMove() {
    // 🟢 1. EASY: Pure Random (20% chance to play smart)
    if (_difficulty == GameDifficulty.easy) {
      if (Random().nextDouble() > 0.2) return _getRandomMove();
    }

    // 🟢 2. MEDIUM: Wins if can, Blocks if critical, otherwise Random
    if (_difficulty == GameDifficulty.medium) {
      // 50% chance to miss a block/win opportunity
      if (Random().nextDouble() > 0.5) return _getRandomMove();
    }

    // 🟢 3. HARD (and Medium fallback): Smart Logic
    
    // A. Try to WIN
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") {
        _board[i] = "0";
        if (_checkWin("0")) { _board[i] = ""; return i; }
        _board[i] = "";
      }
    }
    
    // B. Block Player
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") {
        _board[i] = "1";
        if (_checkWin("1")) { _board[i] = ""; return i; }
        _board[i] = "";
      }
    }
    
    // C. Take Center
    if (_board[4] == "") return 4;
    
    // D. Random
    return _getRandomMove();
  }

  int _getRandomMove() {
    List<int> emptySpots = [];
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") emptySpots.add(i);
    }
    if (emptySpots.isEmpty) return 0; // Should not happen
    return emptySpots[Random().nextInt(emptySpots.length)];
  }

  bool _checkWin(String player, {bool setPattern = false}) {
    List<List<int>> winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], 
      [0, 3, 6], [1, 4, 7], [2, 5, 8], 
      [0, 4, 8], [2, 4, 6]              
    ];

    for (var pattern in winPatterns) {
      if (_board[pattern[0]] == player &&
          _board[pattern[1]] == player &&
          _board[pattern[2]] == player) {
        
        if (setPattern) {
          _winningPattern = pattern;
          // JUICE: Explode particles on winning line
          _spawnExplosion(pattern, player == "1" ? kDitaGold : kNeonRed);
        }
        return true;
      }
    }
    return false;
  }

  Future<void> _endGame(String result) async {
    setState(() => _isGameOver = true);
    HapticFeedback.heavyImpact(); 
    await Future.delayed(const Duration(milliseconds: 1500));
    if(!mounted) return;
    
    String title = "";
    String msg = "";
    Color color = Colors.white;
    int pointsEarned = 0;

    if (_mode == GameMode.ai) {
      if (result == "1") {
        title = "SYSTEM SECURED";
        // 🟢 Bonus based on difficulty
        int bonus = _difficulty == GameDifficulty.hard ? 30 : (_difficulty == GameDifficulty.medium ? 20 : 10);
        msg = "Protocol Complete. +$bonus Points.";
        pointsEarned = bonus;
        color = kNeonBlue;
      } else if (result == "0") {
        title = "BREACH DETECTED";
        msg = "The Virus won this round.";
        color = kNeonRed;
      } else {
        title = "STALEMATE";
        msg = "Connection stable. +5 Points.";
        pointsEarned = 5;
        color = Colors.grey;
      }
    } else {
      if (result == "1") { title = "PLAYER 1 WINS"; color = kNeonBlue; } 
      else if (result == "0") { title = "PLAYER 2 WINS"; color = kNeonRed; }
      else { title = "DRAW"; color = Colors.grey; }
    }

    if (pointsEarned > 0 && _mode == GameMode.ai) {
      setState(() => _currentTotalPoints += pointsEarned);
      try {
        await ApiService.updateUser(widget.userId, {"points": _currentTotalPoints});
      } catch (e) {
        debugPrint("Error updating points: $e");
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color, width: 2)),
        title: Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 24)),
        content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text("EXIT", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _resetGame(); },
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black),
            child: const Text("REBOOT SYSTEM"),
          )
        ],
      )
    );
  }

  void _resetGame() {
    setState(() {
      _board = List.filled(9, "");
      _isGameOver = false;
      _currentPlayer = "1";
      _isAiThinking = false;
      _winningPattern = null; 
      _particles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors from DITA Theme
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).primaryColor;
    
    // Shake Offset
    double shakeOffset = sin(_shakeController.value * pi * 4) * _shakeAnimation.value;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) AdManager.showInterstitialAd();
      },
      child: Scaffold(
        backgroundColor: isDark ? kDeepSlate : Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("CYBER TIC-TAC-TOE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: primaryColor,
          // 🟢 Ensure back button is visible
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_mode == GameMode.ai)
               Container(
                 margin: const EdgeInsets.only(right: 20),
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                 child: Row(
                   children: [
                     const Icon(Icons.stars, color: kDitaGold, size: 16),
                     const SizedBox(width: 6),
                     Text("$_currentTotalPoints", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   ],
                 ),
               )
          ],
        ),
        body: SafeArea( // 🟢 Fix Layout Shift: SafeArea
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // 🟢 Fix Layout Shift: Center Horizontally
            children: [
              const SizedBox(height: 20),
              
              // 1. MODE SELECTOR
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(30)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeBtn("AI BATTLE", GameMode.ai),
                    _buildModeBtn("PVP LOCAL", GameMode.friend),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // 🟢 2. DIFFICULTY SELECTOR (Only in AI Mode)
              if (_mode == GameMode.ai)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: kSurface.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDifficultyBtn("Easy", GameDifficulty.easy, Colors.greenAccent),
                      _buildDifficultyBtn("Med", GameDifficulty.medium, Colors.orangeAccent),
                      _buildDifficultyBtn("Hard", GameDifficulty.hard, Colors.redAccent),
                    ],
                  ),
                ),

              const Spacer(),

              // 3. STATUS
              Text(
                _isAiThinking ? "SYSTEM CALCULATING..." : (_isGameOver ? "GAME OVER" : (_currentPlayer == "1" ? "YOUR TURN (1)" : "OPPONENT TURN (0)")),
                style: TextStyle(
                  color: _isAiThinking ? Colors.grey : (_currentPlayer == "1" ? kNeonBlue : kNeonRed),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0
                ),
              ),
              
              const SizedBox(height: 30),

              // 4. BOARD WITH FX
              Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: SizedBox(
                  width: 300, height: 300,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // A. The Grid
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12,
                        ),
                        itemCount: 9,
                        itemBuilder: (context, index) => _buildGridTile(index),
                      ),

                      // B. Winning Line Overlay
                      if (_winningPattern != null)
                        IgnorePointer(
                          child: CustomPaint(
                            size: const Size(300, 300),
                            painter: LaserLinePainter(
                              pattern: _winningPattern!, 
                              color: _board[_winningPattern![0]] == "1" ? kDitaGold : kNeonRed
                            ),
                          ),
                        ),
                    
                      // C. Particle Overlay
                      IgnorePointer(
                        child: Center(
                          child: CustomPaint(
                            size: const Size(300, 300),
                            painter: GameParticlePainter(_particles),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // 5. RESET
              TextButton.icon(
                onPressed: _resetGame,
                icon: const Icon(Icons.refresh, color: Colors.grey),
                label: const Text("RESET BOARD", style: TextStyle(color: Colors.grey, letterSpacing: 1.2)),
              ),
              
              const SizedBox(height: 10),
              
              // 🟢 6. BANNER AD (Centered at bottom)
              const SizedBox(
                width: double.infinity, 
                child: BannerAdWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeBtn(String label, GameMode mode) {
    bool isSelected = _mode == mode;
    return GestureDetector(
      onTap: () { setState(() => _mode = mode); _resetGame(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? kDitaBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  // 🟢 Helper for Difficulty Buttons
  Widget _buildDifficultyBtn(String label, GameDifficulty difficulty, Color activeColor) {
    bool isSelected = _difficulty == difficulty;
    return GestureDetector(
      onTap: () { setState(() => _difficulty = difficulty); _resetGame(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? activeColor : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? activeColor : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
    );
  }

  Widget _buildGridTile(int index) {
    String value = _board[index];
    Color borderColor = Colors.white10;
    Color txtColor = Colors.white;
    List<BoxShadow> shadows = [];

    if (value == "1") {
      borderColor = kNeonBlue;
      txtColor = kNeonBlue;
      shadows = [BoxShadow(color: kNeonBlue.withOpacity(0.4), blurRadius: 15)];
    } else if (value == "0") {
      borderColor = kNeonRed;
      txtColor = kNeonRed;
      shadows = [BoxShadow(color: kNeonRed.withOpacity(0.4), blurRadius: 15)];
    }

    return GestureDetector(
      onTap: () => _handleTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: value == "" ? Colors.white10 : borderColor, width: 2),
          boxShadow: shadows
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: txtColor),
          ),
        ),
      ),
    );
  }
}

// --- PAINTERS ---

class LaserLinePainter extends CustomPainter {
  final List<int> pattern;
  final Color color;
  LaserLinePainter({required this.pattern, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4); // Glow effect

    double cellW = size.width / 3;
    double cellH = size.height / 3;
    int start = pattern.first;
    int end = pattern.last;

    // Fix diagonal sorting for drawing
    if (pattern.contains(2) && pattern.contains(6)) {
        start = 2; end = 6;
    }

    double x1 = (start % 3) * cellW + cellW / 2;
    double y1 = (start ~/ 3) * cellH + cellH / 2;
    double x2 = (end % 3) * cellW + cellW / 2;
    double y2 = (end ~/ 3) * cellH + cellH / 2;

    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Particle {
  double x, y, vx, vy, size, life;
  Color color;
  Particle({required this.x, required this.y, required this.color}) 
      : vx = (Random().nextDouble() - 0.5) * 4,
        vy = (Random().nextDouble() - 0.5) * 4,
        size = Random().nextDouble() * 5 + 2,
        life = 1.0;
  void update() { x += vx; y += vy; life -= 0.05; size *= 0.95; }
}

class GameParticlePainter extends CustomPainter {
  final List<Particle> particles;
  GameParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    // Center the painter
    canvas.translate(size.width / 2, size.height / 2); // 🟢 Fixed Offset logic relative to center if needed, but particle x/y logic was based on -100 to 100 in spawn
    // Actually, spawn logic uses 0..200 range relative to grid? No, spawn uses `(col - 1) * 100.0`.
    // Center of grid is 0,0 for `(col-1)`. 
    // `col` ranges 0,1,2. `col-1` ranges -1, 0, 1.
    // So 0,0 is indeed center.
    
    // We need to translate canvas to center of SizedBox(300,300) so 0,0 is center.
    canvas.translate(150, 150); // Hardcoded half of 300 since SizedBox is 300x300

    for (var p in particles) {
      final paint = Paint()..color = p.color.withOpacity(p.life.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}