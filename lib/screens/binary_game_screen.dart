import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dita_app/services/api_service.dart';
import 'package:dita_app/services/ads_helper.dart'; 

enum GameMode { ai, friend }

class GameScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const GameScreen({super.key, required this.user, required userId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  // Game Configuration
  GameMode _mode = GameMode.ai;
   
  // Game State
  List<String> _board = List.filled(9, "");
  String _currentPlayer = "1"; // "1" starts
  bool _isGameOver = false;
  int _sessionWins = 0;
  bool _isAiThinking = false;
  
  // Winning Logic
  List<int>? _winningPattern; // Stores the indices of the winning line
   
  // User Points State
  late int _currentTotalPoints;

  // Design Colors
  final Color _p1Color = Colors.cyanAccent;   // Player 1 (Binary 1)
  final Color _p2Color = Colors.redAccent;    // Player 2 / AI (Binary 0)

  @override
  void initState() {
    super.initState();
    // Pre-load Ad
    AdManager.loadInterstitialAd();
    
    // Initialize points from the passed user object
    _currentTotalPoints = widget.user['points'] ?? 0;
  }

  // --- GAME LOGIC ---

  void _handleTap(int index) {
    if (_board[index] != "" || _isGameOver || _isAiThinking) return;

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
      // Local Multiplayer
      setState(() {
        _currentPlayer = _currentPlayer == "1" ? "0" : "1";
      });
    } else {
      // AI Mode
      _aiMove();
    }
  }

  void _aiMove() async {
    setState(() => _isAiThinking = true);
    
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    int bestMove = _findBestMove();
    
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

  // Smart AI Logic
  int _findBestMove() {
    // 1. Try to WIN
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") {
        _board[i] = "0";
        if (_checkWin("0")) { 
          _board[i] = ""; return i;
        }
        _board[i] = "";
      }
    }
    // 2. Block Player
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") {
        _board[i] = "1";
        if (_checkWin("1")) { 
          _board[i] = ""; return i;
        }
        _board[i] = "";
      }
    }
    // 3. Take Center
    if (_board[4] == "") return 4;
    // 4. Random
    List<int> emptySpots = [];
    for (int i = 0; i < 9; i++) {
      if (_board[i] == "") emptySpots.add(i);
    }
    return emptySpots[Random().nextInt(emptySpots.length)];
  }

  /// Checks if [player] has won.
  /// [setPattern]: If true, updates the UI state with the winning line.
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
        }
        return true;
      }
    }
    return false;
  }

  Future<void> _endGame(String result) async {
    setState(() => _isGameOver = true);
    
    String title = "";
    String msg = "";
    int pointsEarned = 0;

    if (_mode == GameMode.ai) {
      if (result == "1") {
        title = "YOU WON! 🎉";
        msg = "Binary Master! You earned +20 Points.";
        pointsEarned = 20;
        _sessionWins += 1;
      } else if (result == "0") {
        title = "SYSTEM WINS 🤖";
        msg = "The AI outsmarted you this time.";
      } else {
        title = "IT'S A DRAW 🤝";
        msg = "Balanced match. +5 Points for effort.";
        pointsEarned = 5;
      }
    } else {
      if (result == "1") {
        title = "PLAYER 1 WINS!";
        msg = "Congratulations Player 1 (Blue)";
      } else if (result == "0") {
        title = "PLAYER 2 WINS!";
        msg = "Congratulations Player 2 (Red)";
      } else {
        title = "DRAW!";
        msg = "No winner this time.";
      }
    }

    if (pointsEarned > 0 && _mode == GameMode.ai) {
      setState(() {
        _currentTotalPoints += pointsEarned;
      });
      try {
        await ApiService.updateUser(widget.user['id'], {"points": _currentTotalPoints});
      } catch (e) {
        debugPrint("Error updating points: $e");
      }
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: result == "1" ? Colors.green : (result == "0" ? Colors.red : Colors.orange))),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("EXIT"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetGame();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
            child: const Text("PLAY AGAIN"),
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          AdManager.showInterstitialAd();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text("Binary Tac-Toe", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          backgroundColor: primaryColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
             if (_mode == GameMode.ai)
               Container(
                 margin: const EdgeInsets.only(right: 15),
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                 decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                 child: Row(
                   children: [
                     const Icon(Icons.star, color: Colors.yellow, size: 16),
                     const SizedBox(width: 4),
                     Text("$_currentTotalPoints", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   ],
                 ),
               )
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 20),
            
            // MODE TOGGLE
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(25)
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeBtn("Single Player (AI)", GameMode.ai),
                  _buildModeBtn("2 Players (Local)", GameMode.friend),
                ],
              ),
            ),

            const Spacer(),

            // STATUS TEXT
            if (_mode == GameMode.ai)
               Column(
                 children: [
                   Text(
                     _isAiThinking ? "AI is calculating..." : "Your Turn (1)",
                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _isAiThinking ? Colors.grey : _p1Color),
                   ),
                   const SizedBox(height: 5),
                   Text("Session Wins: $_sessionWins", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                 ],
               )
            else 
               Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text("Player 1", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _currentPlayer == "1" ? _p1Color : Colors.grey)),
                   const SizedBox(width: 20),
                   const Text("vs", style: TextStyle(color: Colors.grey)),
                   const SizedBox(width: 20),
                   Text("Player 2", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _currentPlayer == "0" ? _p2Color : Colors.grey)),
                 ],
               ),

            const SizedBox(height: 40),

            // THE BOARD
            Center(
              child: Container(
                width: 320,
                height: 320,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                  ]
                ),
                child: Stack(
                  children: [
                    // Layer 1: The Grid
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: 9,
                      itemBuilder: (context, index) {
                        return _buildGridTile(index, isDark);
                      },
                    ),
                    
                    // Layer 2: The Winning Overlay (Border + Strikethrough)
                    if (_winningPattern != null)
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: WinningOverlayPainter(
                            winningPattern: _winningPattern!,
                            // Default green for win, can be dynamic
                            color: Colors.greenAccent, 
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // Reset Button
            TextButton.icon(
              onPressed: _resetGame, 
              icon: Icon(Icons.refresh, color: textColor), 
              label: Text("Restart Game", style: TextStyle(color: textColor)),
              style: TextButton.styleFrom(padding: const EdgeInsets.all(20)),
            ),
            
            // 3. BANNER AD AT BOTTOM
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBtn(String label, GameMode mode) {
    bool isSelected = _mode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _mode = mode);
        _resetGame();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey, 
            fontWeight: FontWeight.bold
          )
        ),
      ),
    );
  }

  Widget _buildGridTile(int index, bool isDark) {
    String value = _board[index];
    Color cellColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    Color txtColor = Colors.grey;

    if (value == "1") {
      cellColor = _p1Color.withOpacity(0.1);
      txtColor = _p1Color; 
    } else if (value == "0") {
      cellColor = _p2Color.withOpacity(0.1);
      txtColor = _p2Color; 
    }

    return GestureDetector(
      onTap: () => _handleTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value == "" ? Colors.transparent : txtColor,
            width: 2
          )
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 40, 
              fontWeight: FontWeight.w900, 
              color: txtColor,
              shadows: value != "" ? [Shadow(color: txtColor.withOpacity(0.5), blurRadius: 10)] : null
            ),
          ),
        ),
      ),
    );
  }
}

// --- PAINTER FOR WINNING OVERLAY ---
class WinningOverlayPainter extends CustomPainter {
  final List<int> winningPattern;
  final Color color;

  WinningOverlayPainter({required this.winningPattern, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (winningPattern.isEmpty) return;

    final paintLine = Paint()
      ..color = color
      ..strokeWidth = 8.0 // Thick strike-through line
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintBorder = Paint()
      ..color = color
      ..strokeWidth = 4.0 // Border thickness
      ..style = PaintingStyle.stroke;

    // Grid measurements (accounting for padding in the main container if necessary, 
    // but here size is the GridView size)
    final cellW = size.width / 3;
    final cellH = size.height / 3;

    // Sort to ensure we draw from top/left to bottom/right
    final sorted = List<int>.from(winningPattern)..sort();
    final first = sorted.first;
    final last = sorted.last;

    // Calculate centers of start and end cells for the line
    final p1 = Offset(
      (first % 3) * cellW + cellW / 2,
      (first ~/ 3) * cellH + cellH / 2,
    );
    final p2 = Offset(
      (last % 3) * cellW + cellW / 2,
      (last ~/ 3) * cellH + cellH / 2,
    );

    // 1. Draw Strikethrough
    canvas.drawLine(p1, p2, paintLine);

    // 2. Draw Group Border
    // Determine type based on index difference
    if (sorted[1] == sorted[0] + 1) { 
      // Horizontal Row
      // Create a rect around the row, slightly padded inside the grid area
      final rect = Rect.fromCenter(
        center: Offset(size.width / 2, p1.dy), 
        width: size.width - 10, 
        height: cellH - 10
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(15)), paintBorder);
    } else if (sorted[1] == sorted[0] + 3) {
      // Vertical Column
      final rect = Rect.fromCenter(
        center: Offset(p1.dx, size.height / 2), 
        width: cellW - 10, 
        height: size.height - 10
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(15)), paintBorder);
    } else {
      // Diagonal (0,4,8 or 2,4,6)
      final center = Offset(size.width / 2, size.height / 2);
      // Calculate diagonal length via Pythagoras, subtract some padding
      final diagLength = sqrt(pow(size.width, 2) + pow(size.height, 2)) - 40;
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      
      // Rotate 45 degrees (pi/4) or -45 depending on direction
      if (first == 0) {
        canvas.rotate(pi / 4); // Top-left to bottom-right
      } else {
        canvas.rotate(-pi / 4); // Top-right to bottom-left
      }
      
      // Draw a "capsule" shape around the diagonal path
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: diagLength, 
        height: cellH - 30 // Thickness of the diagonal border
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(15)), paintBorder);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant WinningOverlayPainter oldDelegate) {
    return oldDelegate.winningPattern != winningPattern;
  }
}