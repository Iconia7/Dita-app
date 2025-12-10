import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dita_app/services/api_service.dart';

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
  int _sessionWins = 0; // Renamed from _score to be clearer this is just session wins
  bool _isAiThinking = false;
  
  // User Points State (Fixed: Track points locally so they update between games)
  late int _currentTotalPoints;

  // Design Colors
  final Color _p1Color = Colors.cyanAccent;   // Player 1 (Binary 1)
  final Color _p2Color = Colors.redAccent;    // Player 2 / AI (Binary 0)

  @override
  void initState() {
    super.initState();
    // Initialize points from the passed user object
    _currentTotalPoints = widget.user['points'] ?? 0;
  }

  // --- GAME LOGIC ---

  void _handleTap(int index) {
    if (_board[index] != "" || _isGameOver || _isAiThinking) return;

    setState(() {
      _board[index] = _currentPlayer;
    });

    if (_checkWin(_currentPlayer)) {
      _endGame(_currentPlayer);
    } else if (_board.every((element) => element != "")) {
      _endGame("Draw");
    } else {
      _switchTurn();
    }
  }

  void _switchTurn() {
    if (_mode == GameMode.friend) {
      // Local Multiplayer: Just switch symbols
      setState(() {
        _currentPlayer = _currentPlayer == "1" ? "0" : "1";
      });
    } else {
      // AI Mode: Player is always "1", AI is "0"
      _aiMove();
    }
  }

  void _aiMove() async {
    setState(() => _isAiThinking = true);
    
    // Fake "Thinking" delay
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    int bestMove = _findBestMove();
    
    setState(() {
      _board[bestMove] = "0"; 
      _isAiThinking = false;
    });

    if (_checkWin("0")) {
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

  bool _checkWin(String player) {
    List<List<int>> winPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], 
      [0, 3, 6], [1, 4, 7], [2, 5, 8], 
      [0, 4, 8], [2, 4, 6]              
    ];

    for (var pattern in winPatterns) {
      if (_board[pattern[0]] == player &&
          _board[pattern[1]] == player &&
          _board[pattern[2]] == player) {
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
      // AI SCORING
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
      // MULTIPLAYER SCORING (No Points)
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

    // UPDATE SERVER & LOCAL STATE (Only if vs AI)
    if (pointsEarned > 0 && _mode == GameMode.ai) {
      // 1. Update local state immediately so next game has correct baseline
      setState(() {
        _currentTotalPoints += pointsEarned;
      });

      // 2. Send the NEW total to the server
      try {
        await ApiService.updateUser(widget.user['id'], {"points": _currentTotalPoints});
      } catch (e) {
        debugPrint("Error updating points: $e");
        // Optional: Revert _currentTotalPoints if network fails
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
              Navigator.pop(context); // Leave Game
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
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
          // Points only show in AI Mode
           if (_mode == GameMode.ai)
             Container(
               margin: const EdgeInsets.only(right: 15),
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
               decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
               // Displaying Wins AND Total Points now for better feedback
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
              child: GridView.builder(
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
          const SizedBox(height: 30),
        ],
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