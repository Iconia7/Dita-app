import 'package:dita_app/services/ads_helper.dart';
import 'package:dita_app/widgets/dita_loader.dart';
import 'package:dita_app/widgets/skeleton_loader.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends ConsumerState<AttendanceHistoryScreen> {

  @override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    final user = ref.watch(currentUserProvider);
    final userId = user?.id ?? 0;
    final historyAsync = ref.watch(attendanceHistoryProvider(userId));

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
        title: const Text("My Attendance Log", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Attendance",
            onPressed: () => ref.refresh(attendanceHistoryProvider(userId)),
          )
        ],
      ),
      body: historyAsync.when(
        loading: () => const SkeletonList(
          padding: EdgeInsets.all(20),
          skeleton: CardSkeleton(hasImage: false),
          itemCount: 10,
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(attendanceHistoryProvider(userId)),
                child: const Text('Retry'),
              )
            ],
          ),
        ),
        data: (events) => events.isEmpty
           ? EmptyStateWidget(
              svgPath: 'assets/svgs/no_attendance.svg',
              title: "No Attendance Yet",
              message: "You haven't checked in to any events. Look for the QR codes at DITA events to earn points!",
              actionLabel: "Scan Now",
              onActionPressed: () {
                 Navigator.of(context).pop(); 
              },
            )
           : RefreshIndicator(
               onRefresh: () async {
                 return ref.refresh(attendanceHistoryProvider(userId));
               },
               child: ListView.builder(
                 padding: const EdgeInsets.all(20),
                 itemCount: events.length,
                 itemBuilder: (context, index) {
                   final event = events[index];
                   return Container(
                     margin: const EdgeInsets.only(bottom: 15),
                     decoration: BoxDecoration(
                       color: cardColor,
                       borderRadius: BorderRadius.circular(15),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.05), 
                           blurRadius: 5
                         )
                       ]
                     ),
                     child: ListTile(
                       leading: Container(
                         padding: const EdgeInsets.all(10),
                         decoration: BoxDecoration(
                           color: Colors.green.withOpacity(0.1),
                           shape: BoxShape.circle
                         ),
                         child: const Icon(Icons.check_circle, color: Colors.green),
                       ),
                       title: Text(
                         event.title, 
                         style: TextStyle(
                           fontWeight: FontWeight.bold,
                           color: textColor
                         )
                       ),
                       subtitle: Text(
                         "Location: ${event.location ?? 'N/A'}",
                         style: TextStyle(color: subTextColor)
                       ),
                       trailing: Text(
                         "+20 pts",
                         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700])
                       ),
                      ),
                    );
                  },
                ),
              ),
            ),
      ),
    );
  }
}