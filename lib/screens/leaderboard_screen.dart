import 'package:dita_app/data/models/user_model.dart';
import 'package:dita_app/providers/auth_provider.dart';
import 'package:dita_app/services/ads_helper.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/leaderboard_model.dart';
import '../providers/leaderboard_provider.dart';
import '../widgets/dita_loader.dart';
import '../widgets/skeleton_loader.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> with TickerProviderStateMixin {
  final Color _gold = const Color(0xFFFFD700);
  final Color _silver = const Color(0xFFC0C0C0);
  final Color _bronze = const Color(0xFFCD7F32);
  
  // Animations
  late AnimationController _glowController;
  late AnimationController _slideController;
  late Animation<double> _glowAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Podium animations
  final Map<int, AnimationController> _podiumControllers = {};
  final Map<int, Animation<double>> _podiumAnimations = {};

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(_glowController);
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _slideController.forward();
  }

  void _refreshLeaderboard() {
    HapticFeedback.mediumImpact();
    ref.read(leaderboardProvider.notifier).refresh();
    _slideController.forward(from: 0);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _slideController.dispose();
    for (var controller in _podiumControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildPodium(BuildContext context, List<LeaderboardModel> users) {
    if (users.length < 3) return const SizedBox();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final first = users[0];
    final second = users[1];
    final third = users[2];
    
    // Initialize podium animations
    for (int i = 0; i < 3; i++) {
      if (!_podiumControllers.containsKey(i)) {
        _podiumControllers[i] = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 500 + (i * 200)),
        );
        _podiumAnimations[i] = CurvedAnimation(
          parent: _podiumControllers[i]!,
          curve: Curves.elasticOut,
        );
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) _podiumControllers[i]?.forward();
        });
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
            ? [Theme.of(context).primaryColor.withOpacity(0.3), Colors.transparent]
            : [Theme.of(context).primaryColor.withOpacity(0.1), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          // Trophy Icon Header
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _gold.withOpacity(_glowAnimation.value * 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.emoji_events,
                  size: 60,
                  color: _gold,
                  shadows: [
                    Shadow(
                      color: _gold.withOpacity(_glowAnimation.value),
                      blurRadius: 30,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Text(
            "TOP PERFORMERS",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 30),
          
          // Podium
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place
              Expanded(
                child: ScaleTransition(
                  scale: _podiumAnimations[1]!,
                  child: _buildPodiumPlace(
                    context,
                    user: second,
                    rank: 2,
                    height: 140,
                    color: _silver,
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // 1st Place (Tallest)
              Expanded(
                child: ScaleTransition(
                  scale: _podiumAnimations[0]!,
                  child: _buildPodiumPlace(
                    context,
                    user: first,
                    rank: 1,
                    height: 180,
                    color: _gold,
                    isDark: isDark,
                    isWinner: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // 3rd Place
              Expanded(
                child: ScaleTransition(
                  scale: _podiumAnimations[2]!,
                  child: _buildPodiumPlace(
                    context,
                    user: third,
                    rank: 3,
                    height: 120,
                    color: _bronze,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(
    BuildContext context, {
    required LeaderboardModel user,
    required int rank,
    required double height,
    required Color color,
    required bool isDark,
    bool isWinner = false,
  }) {
    return Column(
      children: [
        // Avatar with glow
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: isWinner ? [
                  BoxShadow(
                    color: color.withOpacity(_glowAnimation.value * 0.6),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ] : [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: isWinner ? 40 : 32,
                backgroundColor: color.withOpacity(0.3),
                backgroundImage: user.avatar != null ? CachedNetworkImageProvider(user.avatar!) : null,
                child: user.avatar == null 
                  ? Icon(Icons.person, color: color, size: isWinner ? 40 : 32)
                  : null,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        
        // Crown for 1st place
        if (isWinner)
          Icon(Icons.workspace_premium, color: _gold, size: 30),
        
        // Username
        Text(
          user.username,
          style: TextStyle(
            fontSize: isWinner ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        
        // Points
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 10,
              )
            ],
          ),
          child: Text(
            "${user.points} pts",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        
        // Podium Base
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.8),
                color.withOpacity(0.4),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events,
                  color: Colors.white.withOpacity(0.5),
                  size: isWinner ? 50 : 40,
                ),
                const SizedBox(height: 8),
                Text(
                  "#$rank",
                  style: TextStyle(
                    fontSize: isWinner ? 32 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.leaderboard, color: Colors.white),
              const SizedBox(width: 10),
              const Text("Leaderboard", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
              ),
            ),
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: "Refresh",
              onPressed: _refreshLeaderboard,
            ),
          ],
        ),
        body: Consumer(
          builder: (context, ref, child) {
            final leaderboardAsync = ref.watch(leaderboardProvider);

            return leaderboardAsync.when(
              data: (leaderboard) {
                if (leaderboard.isEmpty) {
                  return EmptyStateWidget(
                    svgPath: 'assets/svgs/no_ranks.svg',
                    title: "The Throne is Empty!",
                    message: "No one has earned points yet. Be the first to attend an event and claim the top spot!",
                    actionLabel: "Find Events",
                    onActionPressed: () => Navigator.pop(context),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(leaderboardProvider.notifier).refresh();
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Podium Section for Top 3
                      if (leaderboard.length >= 3)
                        SliverToBoxAdapter(
                          child: _buildPodium(context, leaderboard),
                        ),
                      
                      // Section Header
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(15, 20, 15, 10),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(0.2),
                                primaryColor.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.format_list_numbered, color: primaryColor, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                leaderboard.length > 3 ? "ALL RANKINGS" : "RANKINGS",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  letterSpacing: 1,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "${leaderboard.length} Students",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Rankings List
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            // Skip top 3 if they're shown in podium
                            final actualIndex = leaderboard.length >= 3 ? index + 3 : index;
                            if (actualIndex >= leaderboard.length) return null;
                            
                            final user = leaderboard[actualIndex];
                            final int rank = actualIndex + 1;

                            return SlideTransition(
                              position: _slideAnimation,
                              child: _buildRankCard(
                                context,
                                user: user,
                                rank: rank,
                                isDark: isDark,
                                cardColor: cardColor,
                                primaryColor: primaryColor,
                                textColor: textColor,
                                subTextColor: subTextColor,
                              ),
                            );
                          },
                          childCount: leaderboard.length >= 3 ? leaderboard.length - 3 : leaderboard.length,
                        ),
                      ),
                      
                      // Bottom padding
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 20),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SkeletonList(
                padding: EdgeInsets.only(top: 20),
                skeleton: LeaderboardSkeleton(),
                itemCount: 10,
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load leaderboard',
                      style: TextStyle(fontSize: 18, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(fontSize: 14, color: subTextColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.read(leaderboardProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRankCard(
    BuildContext context, {
    required LeaderboardModel user,
    required int rank,
    required bool isDark,
    required Color cardColor,
    required Color primaryColor,
    required Color? textColor,
    required Color? subTextColor,
  }) {
    // Determine rank color
    Color rankColor = primaryColor;
    IconData? rankIcon;
    
    if (rank <= 10) {
      rankColor = Colors.orange;
    }
    if (rank <= 5) {
      rankColor = Colors.deepOrange;
      rankIcon = Icons.star;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: rank <= 10 
          ? Border.all(color: rankColor.withOpacity(0.3), width: 2)
          : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            HapticFeedback.selectionClick();
            // Could navigate to user profile
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: rank <= 10
                      ? LinearGradient(
                          colors: [rankColor, rankColor.withOpacity(0.6)],
                        )
                      : null,
                    color: rank > 10 ? (isDark ? Colors.white10 : Colors.grey[200]) : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: rank <= 10 ? [
                      BoxShadow(
                        color: rankColor.withOpacity(0.3),
                        blurRadius: 10,
                      )
                    ] : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (rankIcon != null)
                        Icon(rankIcon, color: Colors.white, size: 16),
                      Text(
                        "$rank",
                        style: TextStyle(
                          fontSize: rank <= 10 ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: rank <= 10 ? Colors.white : subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: primaryColor.withOpacity(0.1),
                      backgroundImage: user.avatar != null ? CachedNetworkImageProvider(user.avatar!) : null,
                      child: user.avatar== null 
                        ? Icon(Icons.person, color: primaryColor, size: 28)
                        : null,
                    ),
                    if (rank <= 5)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: rankColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: cardColor, width: 2),
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 15),
                
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.school, size: 12, color: subTextColor),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              user.program ?? "Student",
                              style: TextStyle(color: subTextColor, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                
                // Points Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: rank <= 10
                      ? LinearGradient(
                          colors: [
                            rankColor.withOpacity(0.2),
                            rankColor.withOpacity(0.1),
                          ],
                        )
                      : null,
                    color: rank > 10 
                      ? (isDark ? Colors.white10 : primaryColor.withOpacity(0.1))
                      : null,
                    borderRadius: BorderRadius.circular(20),
                    border: rank <= 10 
                      ? Border.all(color: rankColor.withOpacity(0.5), width: 1.5)
                      : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        color: rank <= 10 ? rankColor : (isDark ? _gold : primaryColor),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${user.points}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: rank <= 10 ? rankColor : (isDark ? Colors.white : primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}