import 'package:dita_app/services/ads_helper.dart';
import 'package:flutter/material.dart';
import 'package:dita_app/screens/binary_game_screen.dart'; 
import 'package:dita_app/screens/ram_optimizer.dart';
import 'package:dita_app/screens/snake_game.dart';

class GamesListScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const GamesListScreen({super.key, required this.user});

  void _navigateToGame(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("DITA Arcade", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Choose a Challenge",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Test your logic and optimization skills.",
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // --- GAME 1: RAM OPTIMIZER ---
                    _GameCard(
                      title: "RAM Optimizer",
                      description: "Fit memory blocks efficiently. Avoid stack overflow.",
                      icon: Icons.memory,
                      color: Colors.green,
                      isDark: isDark,
                      onTap: () => _navigateToGame(context, RamOptimizerScreen(user: user)),
                    ),

                    const SizedBox(height: 16),

                    // --- GAME 2: BINARY TAC-TOE ---
                    _GameCard(
                      title: "Binary Tac-Toe",
                      description: "Classic strategy with a binary twist. Vs AI or Friend.",
                      icon: Icons.grid_3x3,
                      color: Colors.cyan,
                      isDark: isDark,
                      onTap: () => _navigateToGame(context, GameScreen(user: user)), // Removed userId as it's likely inside user map
                    ),

                    const SizedBox(height: 16),

                    // --- GAME 3: DATA SNAKE ---
                    _GameCard(
                      title: "Data Snake",
                      description: "Collect data packets and grow your stream. Don't crash!",
                      icon: Icons.timeline, 
                      color: Colors.purpleAccent,
                      isDark: isDark,
                      onTap: () => _navigateToGame(context, SnakeGameScreen(user: user)),
                    ),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
          
          // 🟢 Banner Ad at the bottom
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            // Arrow
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}