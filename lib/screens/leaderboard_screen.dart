import 'package:dita_app/services/ads_helper.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/dita_loader.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // 🟢 Colors moved to Theme (Only keeping medal colors)
  final Color _gold = const Color(0xFFFFD700);
  final Color _silver = const Color(0xFFC0C0C0);
  final Color _bronze = const Color(0xFFCD7F32);

  // State variable to hold the future, allowing us to refresh it
  late Future<List<dynamic>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _leaderboardFuture = ApiService.getLeaderboard();
  }

  void _refreshLeaderboard() {
    setState(() {
      _loadData();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          AdManager.showInterstitialAd();
        }
      },
      child: Scaffold(
      backgroundColor: scaffoldBg, // 🟢 Dynamic BG
      appBar: AppBar(
        title: const Text("Top Students 🏆", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          // 🔄 Refresh Button Added Here
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh List",
            onPressed: _refreshLeaderboard,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _leaderboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: DaystarSpinner(size: 120)); 
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return EmptyStateWidget(
              svgPath: 'assets/svgs/no_ranks.svg', // Ensure this SVG exists
              title: "The Throne is Empty!",
              message: "No one has earned points yet. Be the first to attend an event and claim the top spot!",
              actionLabel: "Find Events",
              onActionPressed: () => Navigator.pop(context), 
            );
          }

          final users = snapshot.data!;

          // Added RefreshIndicator for Pull-to-Refresh support as well
          return RefreshIndicator(
            onRefresh: () async {
              _refreshLeaderboard();
              await _leaderboardFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: users.length,
              // AlwaysScrollableScrollPhysics ensures pull-to-refresh works even if list is short
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final user = users[index];
                final int rank = index + 1;
                
                // Special styling for Top 3
                final bool isFirst = rank == 1;
                final bool isSecond = rank == 2;
                final bool isThird = rank == 3;
                
                Color? trophyColor;
                if (isFirst) trophyColor = _gold;
                if (isSecond) trophyColor = _silver;
                if (isThird) trophyColor = _bronze;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: cardColor, // 🟢 Dynamic Card BG
                    borderRadius: BorderRadius.circular(15),
                    border: isFirst ? Border.all(color: _gold, width: 2) : null,
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: subTextColor), // 🟢 Dynamic Grey
                            textAlign: TextAlign.center,
                          ),
                    ),
                    
                    // Avatar
                    title: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: primaryColor.withOpacity(0.1), // 🟢 Dynamic tint
                          backgroundImage: user['avatar'] != null ? NetworkImage(user['avatar']) : null,
                          child: user['avatar'] == null ? Icon(Icons.person, color: primaryColor) : null, // 🟢
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['username'] ?? "Unknown", 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor), // 🟢 Dynamic Text
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user['program'] ?? "Student", 
                                style: TextStyle(color: subTextColor, fontSize: 12), // 🟢 Dynamic Subtext
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
                        color: isDark ? Colors.white10 : primaryColor.withOpacity(0.1), // 🟢 Lighter badge in dark mode
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, color: isDark ? _gold : primaryColor, size: 16), // 🟢 Gold star on dark looks better
                          const SizedBox(width: 5),
                          Text(
                            "${user['points']}", 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: isDark ? Colors.white : primaryColor // 🟢 Dynamic Text
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    ),
    );
  }
}