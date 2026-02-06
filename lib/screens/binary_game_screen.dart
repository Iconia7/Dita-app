import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:dita_app/services/api_service.dart';
import 'package:dita_app/services/ads_helper.dart';

// --- THEME CONSTANTS ---
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dita_app/providers/auth_provider.dart';

// --- THEME CONSTANTS ---
const Color kDeepSlate = Color(0xFF0F172A);
const Color kSurface = Color(0xFF1E293B);
const Color kDitaBlue = Color(0xFF003366);
const Color kNeonBlue = Color(0xFF38BDF8); // Player Color
const Color kNeonRed = Color(0xFFEF4444);  // AI/Enemy Color
const Color kDitaGold = Color(0xFFFFD700); // Win Color

enum GameMode { ai, friend }
enum GameDifficulty { easy, medium, hard }

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> with TickerProviderStateMixin {
  // Game Config
  GameMode _mode = GameMode.ai;
  GameDifficulty _difficulty = GameDifficulty.medium;
   
  // Game State
  List<String> _board = List.filled(9, "");
  String _currentPlayer = "1"; 
  bool _isGameOver = false;
  bool _isAiThinking = false;
  // --- AI LEARNING MEMORY ---
final Map<int, int> _playerMoveFrequency = {}; // index -> count
int _gamesPlayed = 0;

  
  // Winning Logic
  List<int>? _winningPattern; 
   
  // User Points
  late int _currentTotalPoints;
  int _pointsSinceLastSync = 0; // Track points for batching

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
    
    // 🟢 Points Init (Safe Parsing)
    final user = ref.read(currentUserProvider);
    _currentTotalPoints = user?.points ?? 0;

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
    // 👇 LEARN PLAYER BEHAVIOR
  _playerMoveFrequency[index] = (_playerMoveFrequency[index] ?? 0) + 1;

    _triggerShake(); 

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
    
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    int bestMove = _findBestMove();
    
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

  // 🟢 UPDATED: Improved AI Probability Logic
int _findBestMove() {
  switch (_difficulty) {
    case GameDifficulty.easy:
      return _easyAI();
    case GameDifficulty.medium:
      return _mediumAI();
    case GameDifficulty.hard:
      return _hardAI();
  }
}

int _hardAI() {
  int bestScore = -1000;
  int bestMove = 0;

  for (int i = 0; i < 9; i++) {
    if (_board[i] == "") {
      _board[i] = "0";
      int score = _minimax(false, 0);
      _board[i] = "";

            // 🧠 LEARNING SCALE (AI adapts over time)
      int learningBoost = min(_gamesPlayed, 20);

      // Slight bias against player-favorite cells
      score += (_playerMoveFrequency[i] ?? 0) * learningBoost;

      if (score > bestScore) {
        bestScore = score;
        bestMove = i;
      }
    }
  }
  return bestMove;
}

int _minimax(bool isMaximizing, int depth) {
  if (_checkWin("0")) return 10 - depth;
  if (_checkWin("1")) return depth - 10;
  if (_board.every((e) => e != "")) return 0;

  if (isMaximizing) {
    int best = -1000;
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") {
        _board[i] = "0";
        best = max(best, _minimax(false, depth + 1));
        _board[i] = "";
      }
    }
    return best;
  } else {
    int best = 1000;
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") {
        _board[i] = "1";
        best = min(best, _minimax(true, depth + 1));
        _board[i] = "";
      }
    }
    return best;
  }
}


int _easyAI() {
  // 30% random stupidity 😅
  if (Random().nextDouble() < 0.5) {
    return _getRandomMove();
  }
  return _getSmartMove();
}

int _mediumAI() {
  // 1. Win if possible
  for (int i = 0; i < 9; i++) {
    if (_board[i] == "") {
      _board[i] = "0";
      if (_checkWin("0")) { _board[i] = ""; return i; }
      _board[i] = "";
    }
  }

  // 2. Block player
  for (int i = 0; i < 9; i++) {
    if (_board[i] == "") {
      _board[i] = "1";
      if (_checkWin("1")) { _board[i] = ""; return i; }
      _board[i] = "";
    }
  }

  // 3. COUNTER PLAYER HABITS 🧠
  int? mostPlayed;
  int maxCount = 0;
  _playerMoveFrequency.forEach((index, count) {
    if (_board[index] == "" && count > maxCount) {
      maxCount = count;
      mostPlayed = index;
    }
  });

  if (mostPlayed != null) return mostPlayed!;

  // 4. Center or random
  if (_board[4] == "") return 4;
  return _getRandomMove();
}



  // Calculates the mathematically best move (Win -> Block -> Center -> Random)
  int _getSmartMove() {
    // 1. Try to WIN
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") {
        _board[i] = "0";
        if (_checkWin("0")) { _board[i] = ""; return i; }
        _board[i] = "";
      }
    }
    
    // 2. Block Player
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") {
        _board[i] = "1";
        if (_checkWin("1")) { _board[i] = ""; return i; }
        _board[i] = "";
      }
    }
    
    // 3. Take Center (Strategic)
    if (_board[4] == "") return 4;
    
    // 4. Fallback to Random
    return _getRandomMove();
  }

  int _getRandomMove() {
    List<int> emptySpots = [];
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") emptySpots.add(i);
    }
    if (emptySpots.isEmpty) return 0; 
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
  bool playerWon = false;

  if (_mode == GameMode.ai) {
    if (result == "1") {
      title = "SYSTEM SECURED";
      int bonus = _difficulty == GameDifficulty.hard ? 30 : (_difficulty == GameDifficulty.medium ? 20 : 10);
      msg = "Protocol Complete. +$bonus Points.";
      pointsEarned = bonus;
      color = kNeonBlue;
      playerWon = true;
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
    
    // Send game stats to backend for achievements
    try {
      await ApiService.updateGameStats({
        'game_type': 'binary',
        'difficulty': _difficulty == GameDifficulty.hard ? 'hard' 
                    : _difficulty == GameDifficulty.medium ? 'medium' 
                    : 'easy',
        'won': playerWon,
      });
    } catch (e) {
      debugPrint("Error updating game stats: $e");
    }
  } else {
    if (result == "1") { title = "PLAYER 1 WINS"; color = kNeonBlue; } 
    else if (result == "0") { title = "PLAYER 2 WINS"; color = kNeonRed; }
    else { title = "DRAW"; color = Colors.grey; }
  }

  if (pointsEarned > 0 && _mode == GameMode.ai) {
    setState(() {
      _currentTotalPoints += pointsEarned;
      _pointsSinceLastSync += pointsEarned;
    });
    
    // Sync every 50 points or immediately at game end
    if (_pointsSinceLastSync >= 50) {
      await _syncPointsToBackend();
    } else {
      // Still update provider immediately for live UI
      _updateProviderOnly();
    }
  }
  _gamesPlayed++;


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

  // Update provider immediately without backend sync (for live UI)
  void _updateProviderOnly() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      // Update local provider state for immediate UI reflection
      ref.read(authProvider.notifier).updateLocalUserPoints(_currentTotalPoints);
    }
  }

  // Sync points to backend and update provider
  Future<void> _syncPointsToBackend() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      try {
        await ref.read(authProvider.notifier).updateUser(user.id, {"points": _currentTotalPoints});
        _pointsSinceLastSync = 0; // Reset counter
      } catch (e) {
        debugPrint("Error syncing points: $e");
      }
    }
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).primaryColor;
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
        body: SafeArea(
          // 🟢 FIX: Wrap in SizedBox to force full width and center
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, 
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

                // 2. DIFFICULTY SELECTOR
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
                        GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12,
                          ),
                          itemCount: 9,
                          itemBuilder: (context, index) => _buildGridTile(index),
                        ),

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
                
                // 6. BANNER AD
                const SizedBox(
                  width: double.infinity, 
                  child: BannerAdWidget(),
                ),
              ],
            ),
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
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    double cellW = size.width / 3;
    double cellH = size.height / 3;
    int start = pattern.first;
    int end = pattern.last;

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
    canvas.translate(size.width / 2, size.height / 2); // Center particles

    for (var p in particles) {
      final paint = Paint()..color = p.color.withOpacity(p.life.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}