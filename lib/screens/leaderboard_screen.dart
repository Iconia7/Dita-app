import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/dita_loader.dart'; // Assuming you have this

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final Color _primaryDark = const Color(0xFF003366);
  final Color _accentGold = const Color(0xFFFFD700);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Top Students 🏆", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.getLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: DaystarSpinner(size: 120,)); // Your custom loader
          }
          
          // In LeaderboardScreen (inside FutureBuilder)
if (!snapshot.hasData || snapshot.data!.isEmpty) {
  return EmptyStateWidget(
    svgPath: 'assets/svgs/no_ranks.svg',
    title: " The Throne is Empty!",
    message: "No one has earned points yet. Be the first to attend an event and claim the top spot!",
    actionLabel: "Find Events",
    onActionPressed: () => Navigator.pop(context), // Go back to Home/Events
  );
}

          final users = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final int rank = index + 1;
              
              // Special styling for Top 3
              final bool isFirst = rank == 1;
              final bool isSecond = rank == 2;
              final bool isThird = rank == 3;
              
              Color? trophyColor;
              if (isFirst) trophyColor = const Color(0xFFFFD700); // Gold
              if (isSecond) trophyColor = const Color(0xFFC0C0C0); // Silver
              if (isThird) trophyColor = const Color(0xFFCD7F32); // Bronze

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: isFirst ? Border.all(color: _accentGold, width: 2) : null,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  // Rank Number or Trophy
                  leading: SizedBox(
                    width: 40,
                    child: trophyColor != null 
                      ? Icon(Icons.emoji_events_rounded, color: trophyColor, size: 30)
                      : Text(
                          "#$rank", 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                  ),
                  
                  // Avatar
                  title: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _primaryDark.withOpacity(0.1),
                        backgroundImage: user['avatar'] != null ? NetworkImage(user['avatar']) : null,
                        child: user['avatar'] == null ? Icon(Icons.person, color: _primaryDark) : null,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['username'] ?? "Unknown", 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user['program'] ?? "Student", 
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Points Badge
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stars_rounded, color: _primaryDark, size: 16),
                        const SizedBox(width: 5),
                        Text(
                          "${user['points']}", 
                          style: TextStyle(fontWeight: FontWeight.bold, color: _primaryDark)
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}