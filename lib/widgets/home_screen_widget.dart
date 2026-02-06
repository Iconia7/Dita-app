import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/timetable_model.dart';

class HomeWidgetUI extends StatelessWidget {
  final List<TimetableModel> upcomingClasses;
  final String dateStr;

  const HomeWidgetUI({
    super.key,
    required this.upcomingClasses,
    required this.dateStr,
  });

  // DITA Brand Colors
  static const Color ditaBlue = Color(0xFF003366);
  static const Color ditaGold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentClass = _getCurrentClass(now);
    final nextClass = _getNextClass(now);
    final totalClasses = _getTotalClassesToday();
    final completedClasses = _getCompletedClasses(now);
    
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF002244), // Darker DITA Blue
            ditaBlue,
            Color(0xFF004477), // Lighter DITA Blue
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          Expanded(
            child: currentClass != null
                ? _buildInSessionState(currentClass, now)
                : nextClass != null
                    ? _buildUpcomingState(nextClass, now, totalClasses, completedClasses)
                    : _buildAllClearState(totalClasses),
          ),
          if (totalClasses > 0) ...[
            const SizedBox(height: 16),
            _buildProgressBar(completedClasses, totalClasses),
          ],
          const SizedBox(height: 12),
          _buildFooter(currentClass != null, nextClass != null),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DITA SCHEDULE',
              style: GoogleFonts.outfit(
                color: ditaGold,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 35,
              height: 3,
              decoration: BoxDecoration(
                color: ditaGold,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: ditaGold.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            dateStr,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInSessionState(TimetableModel currentClass, DateTime now) {
    final timeLeft = _getTimeRemaining(currentClass, now);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'IN SESSION',
              style: GoogleFonts.inter(
                color: const Color(0xFF00FF88),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          currentClass.title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.1,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ditaGold.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: ditaGold, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        currentClass.venue ?? 'TBA',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ditaGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      timeLeft,
                      style: GoogleFonts.inter(
                        color: ditaGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingState(TimetableModel nextClass, DateTime now, int total, int completed) {
    final countdown = _getCountdown(nextClass, now);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ditaGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ditaGold.withOpacity(0.3)),
          ),
          child: Text(
            'NEXT UP',
            style: GoogleFonts.inter(
              color: ditaGold,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          nextClass.title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ditaGold.withOpacity(0.15),
                ditaGold.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ditaGold.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: ditaGold, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        nextClass.startTime,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ditaGold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      countdown,
                      style: GoogleFonts.inter(
                        color: ditaBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, color: Colors.white60, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    nextClass.venue ?? 'TBA',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllClearState(int totalClasses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: ditaGold,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          totalClasses > 0 ? 'All Done!' : 'No Classes',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          totalClasses > 0
              ? 'You\'ve completed all $totalClasses ${totalClasses == 1 ? 'class' : 'classes'} for today. Great work!'
              : 'No classes scheduled for today. Enjoy your free time!',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(int completed, int total) {
    final progress = total > 0 ? completed / total : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Progress',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.6),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '$completed of $total',
              style: GoogleFonts.inter(
                color: ditaGold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ditaGold, ditaGold.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: ditaGold.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool inSession, bool hasNext) {
    final now = DateTime.now();
    final contextMessage = _getContextualMessage(now, inSession, hasNext);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: inSession ? const Color(0xFF00FF88) : ditaGold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (inSession ? const Color(0xFF00FF88) : ditaGold).withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              inSession ? 'ACTIVE SESSION' : hasNext ? 'SCHEDULE SYNCED' : 'RESTING MODE',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.3),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        if (contextMessage.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            contextMessage,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  // Helper Methods
  TimetableModel? _getCurrentClass(DateTime now) {
    for (var classItem in upcomingClasses) {
      final times = _parseClassTimes(classItem, now);
      if (times != null && now.isAfter(times['start']!) && now.isBefore(times['end']!)) {
        return classItem;
      }
    }
    return null;
  }

  TimetableModel? _getNextClass(DateTime now) {
    for (var classItem in upcomingClasses) {
      final times = _parseClassTimes(classItem, now);
      if (times != null && now.isBefore(times['start']!)) {
        return classItem;
      }
    }
    return null;
  }

  Map<String, DateTime>? _parseClassTimes(TimetableModel classItem, DateTime now) {
    try {
      final startParts = classItem.startTime.split(':');
      final endParts = classItem.endTime.split(':');
      
      final startTime = DateTime(
        now.year, now.month, now.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );
      
      final endTime = DateTime(
        now.year, now.month, now.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );
      
      return {'start': startTime, 'end': endTime};
    } catch (e) {
      return null;
    }
  }

  String _getTimeRemaining(TimetableModel classItem, DateTime now) {
    final times = _parseClassTimes(classItem, now);
    if (times == null) return '';
    
    final remaining = times['end']!.difference(now);
    final minutes = remaining.inMinutes;
    
    if (minutes < 60) {
      return '$minutes min left';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m left';
    }
  }

  String _getCountdown(TimetableModel classItem, DateTime now) {
    final times = _parseClassTimes(classItem, now);
    if (times == null) return '';
    
    final until = times['start']!.difference(now);
    final minutes = until.inMinutes;
    
    if (minutes < 60) {
      return 'in $minutes min';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return 'in ${hours}h ${mins}m';
    }
  }

  int _getTotalClassesToday() {
    return upcomingClasses.length;
  }

  int _getCompletedClasses(DateTime now) {
    int count = 0;
    for (var classItem in upcomingClasses) {
      final times = _parseClassTimes(classItem, now);
      if (times != null && now.isAfter(times['end']!)) {
        count++;
      }
    }
    return count;
  }

  String _getContextualMessage(DateTime now, bool inSession, bool hasNext) {
    final hour = now.hour;
    final totalClasses = _getTotalClassesToday();
    final completed = _getCompletedClasses(now);
    
    // Morning (before noon)
    if (hour < 12) {
      if (hasNext && !inSession) {
        final nextClass = _getNextClass(now);
        if (nextClass != null) {
          return 'Good morning — first class at ${nextClass.startTime}';
        }
      }
      return 'Good morning ☀️';
    }
    
    // Afternoon/Midday (noon to 6pm)
    if (hour >= 12 && hour < 18) {
      if (totalClasses > 0 && completed > 0) {
        final progress = completed / totalClasses;
        if (progress >= 0.4 && progress < 0.7) {
          return 'Halfway through the day 💪';
        }
      }
      return 'Keep going 💪';
    }
    
    // Evening (after 6pm)
    if (hour >= 18) {
      if (totalClasses > 0 && !hasNext) {
        return 'All done. Recharge 🌙';
      }
      return 'Evening time 🌙';
    }
    
    return '';
  }
}
