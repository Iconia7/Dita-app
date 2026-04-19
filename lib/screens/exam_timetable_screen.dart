import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:dita_app/widgets/dita_loader.dart';
import 'package:dita_app/widgets/skeleton_loader.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:dita_app/providers/timetable_provider.dart';
import 'package:dita_app/data/models/timetable_model.dart';
import 'package:dita_app/providers/network_provider.dart';
import '../services/notification.dart';
import '../providers/ai_provider.dart';
import 'ai_assistant_screen.dart';
import 'package:dita_app/utils/dita_toast.dart';

class ExamTimetableScreen extends ConsumerStatefulWidget {
  const ExamTimetableScreen({super.key});

  @override
  ConsumerState<ExamTimetableScreen> createState() => _ExamTimetableScreenState();
}

class _ExamTimetableScreenState extends ConsumerState<ExamTimetableScreen> {
  final Color _accentGold = const Color(0xFFFFD700);
  final Color _urgentRed = const Color(0xFFEF4444);

  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      setState(() {});
    });

    // Handle initial fetch if timetable is already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(examsProvider) is AsyncLoading) {
        ref.read(timetableProvider).whenData((items) {
          final codes = items
              .where((i) => i.isClass)
              .map((i) {
                final raw = i.code ?? i.title;
                return raw.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
              })
              .where((c) => c.isNotEmpty && c.length >= 3)
              .toSet()
              .toList();

          if (codes.isNotEmpty) {
            print('🔍 DEBUG: Searching exams for codes: $codes');
            ref.read(examsProvider.notifier).fetchExams(codes);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CALENDAR HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Adds a single exam to the device calendar via the native UI.
  void _addExamToCalendar(TimetableModel exam) {
    if (exam.examDate == null) return;

    final start = exam.examDate!;

    // Derive end time from model's startTime/endTime HH:mm strings
    DateTime end;
    try {
      final endParts = exam.endTime.split(':');
      final startParts = exam.startTime.split(':');
      final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final durationMinutes = endMinutes > startMinutes ? endMinutes - startMinutes : 120;
      end = start.add(Duration(minutes: durationMinutes));
    } catch (_) {
      end = start.add(const Duration(hours: 2)); // safe fallback
    }

    final code = exam.code ?? exam.title;

    final event = Event(
      title: 'Exam: $code',
      description: 'DITA — ${exam.title}',
      location: exam.venue ?? '',
      startDate: start,
      endDate: end,
      iosParams: const IOSParams(reminder: Duration(minutes: 30)),
      androidParams: const AndroidParams(emailInvites: []),
    );

    Add2Calendar.addEvent2Cal(event);
  }

  /// Bulk-adds all upcoming (non-Done) exams to the calendar.
  void _addAllExamsToCalendar(List<TimetableModel> exams) {
    final upcoming = exams.where((e) {
      if (e.examDate == null) return false;
      return _getDaysRemaining(e.examDate!) != 'Done';
    }).toList();

    if (upcoming.isEmpty) {
      DitaToast.show(context, 'No upcoming exams to add.');
      return;
    }

    for (final exam in upcoming) {
      _addExamToCalendar(exam);
    }

    DitaToast.show(
      context, 
      'Adding ${upcoming.length} exam${upcoming.length == 1 ? '' : 's'} to your calendar…',
      backgroundColor: const Color(0xFF003366),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STUDY PLAN & REMINDERS
  // ─────────────────────────────────────────────────────────────────────────

  void _scheduleExamReminders(List<TimetableModel> exams) {
    for (var exam in exams) {
      if (exam.examDate == null) continue;
      int notifId = (exam.code ?? exam.title).hashCode;
      _scheduleSpecificExamAlarm(notifId, exam.code ?? exam.title, exam.venue ?? 'Unknown', exam.examDate!);
    }
  }

  void _createStudyPlan(List<TimetableModel> exams) {
    if (exams.isEmpty) return;

    final examListStr = exams
        .map((e) => '- ${e.code ?? e.title}: ${e.examDate != null ? DateFormat('MMM d').format(e.examDate!) : 'Unknown Date'}')
        .join('\n');
    final prompt =
        'I have the following exams coming up:\n$examListStr\n\nPlease create a detailed 7-day study plan to help me prepare for these, prioritizing the ones happening soonest. Include break times.';

    ref.read(chatProvider.notifier).sendMessage(prompt);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen()));
  }

  Future<void> _scheduleSpecificExamAlarm(int id, String code, String venue, DateTime examTime) async {
    DateTime reminderTime = examTime.subtract(const Duration(minutes: 30));
    if (reminderTime.isBefore(DateTime.now())) {
      if (examTime.isAfter(DateTime.now())) {
        reminderTime = DateTime.now().add(const Duration(seconds: 5));
      } else {
        return;
      }
    }

    await NotificationService.scheduleTaskNotification(
      id: id,
      title: 'Exam: $code',
      deadline: examTime,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATUS HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _getDaysRemaining(DateTime examDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
    final diff = examDay.difference(today).inDays;

    if (diff < 0) return 'Done';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'in $diff Days';
  }

  Color _getStatusColor(String status, Color defaultColor) {
    if (status == 'Today' || status == 'Tomorrow') return _urgentRed;
    if (status == 'Done') return Colors.grey;
    return defaultColor;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    final timetableAsync = ref.watch(timetableProvider);
    final examsAsync = ref.watch(examsProvider);
    final isOffline = !ref.watch(isOnlineProvider);

    // Listen to timetable changes and fetch exams when it changes
    ref.listen<AsyncValue<List<TimetableModel>>>(timetableProvider, (previous, next) {
      next.whenData((items) {
        final codes = items
            .where((i) => i.isClass)
            .map((i) {
              final raw = i.code ?? i.title;
              return raw.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
            })
            .where((c) => c.isNotEmpty && c.length >= 3)
            .toSet()
            .toList();

        if (codes.isNotEmpty) {
          print('🔍 DEBUG: Listener searching exams for codes: $codes');
          ref.read(examsProvider.notifier).fetchExams(codes);
        } else {
          print('⚠️ DEBUG: No valid course codes found in timetable');
        }
      });
    });

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              backgroundColor: primaryColor,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: const Text(
                  'Exams',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF0F172A), const Color(0xFF003366)]
                              : [const Color(0xFF003366), const Color(0xFF003366)],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            TextField(
                              controller: _codeController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search by course code...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    ref.refresh(timetableProvider);
                    final items = ref.read(timetableProvider).value ?? [];
                    final codes = items
                        .where((i) => i.isClass)
                        .map((i) => i.code ?? '')
                        .where((c) => c.isNotEmpty)
                        .toSet()
                        .toList();
                    ref.read(examsProvider.notifier).fetchExams(codes);
                  },
                ),
              ],
            ),
          ];
        },
        body: Column(
          children: [
            // ── OFFLINE BANNER ──────────────────────────────────────────
            if (isOffline)
              Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFFFFF3CD),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, size: 16, color: Color(0xFF856404)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Offline — showing cached exams',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF856404),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── EXAM LIST ───────────────────────────────────────────────
            Expanded(
              child: examsAsync.when(
                loading: () => const TimetableSkeleton(),
                error: (err, stack) {
                  // Simplified error display to prevent DiagnosticsProperty crash
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 40),
                          const SizedBox(height: 10),
                          const Text('Unable to load exams', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text('There was a problem syncing your schedule.', 
                               textAlign: TextAlign.center, 
                               style: TextStyle(color: subTextColor)),
                        ],
                      ),
                    ),
                  );
                },
                data: (examsList) {
                  // Create a modifiable copy
                  var exams = List<TimetableModel>.from(examsList);

                  // Deduplicate (cleans up legacy cached items that had null keys)
                  final uniqueExams = <String, TimetableModel>{};
                  for (final e in exams) {
                    final key = '${e.title}_${e.examDate?.toIso8601String() ?? 'no-date'}';
                    uniqueExams[key] = e;
                  }
                  exams = uniqueExams.values.toList();

                  // Apply search filter
                  if (_codeController.text.isNotEmpty) {
                    final query = _codeController.text.toUpperCase();
                    exams = exams
                        .where((e) =>
                            (e.code?.toUpperCase().contains(query) ?? false) ||
                            (e.title.toUpperCase().contains(query)))
                        .toList();
                  }

                  if (exams.isEmpty) {
                    return EmptyStateWidget(
                      svgPath: 'assets/svgs/no_data.svg',
                      title: 'No Exams Found',
                      message: _codeController.text.isEmpty
                          ? 'Go to Timetable to sync your units first.'
                          : "No exams match your search for '${_codeController.text}'.",
                      actionLabel: 'Search',
                      onActionPressed: () {
                        if (_codeController.text.isNotEmpty) {
                          final cleanCode =
                              _codeController.text.trim().replaceAll(' ', '').toUpperCase();
                          ref.read(examsProvider.notifier).fetchExams([cleanCode]);
                        }
                      },
                    );
                  }

                  // Sort by date
                  exams.sort((a, b) {
                    final aDate = a.examDate ?? DateTime.now();
                    final bDate = b.examDate ?? DateTime.now();
                    return aDate.compareTo(bDate);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    itemCount: exams.length,
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      if (exam.examDate == null) return const SizedBox.shrink();

                      final date = exam.examDate!;
                      final status = _getDaysRemaining(date);
                      final baseColor = isDark ? _accentGold : primaryColor;
                      final statusColor = _getStatusColor(status, baseColor);
                      final bool isLast = index == exams.length - 1;
                      final bool isDone = status == 'Done';

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. DATE COLUMN
                            SizedBox(
                              width: 50,
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('MMM').format(date).toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor),
                                  ),
                                  Text(
                                    DateFormat('dd').format(date),
                                    style: TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                ],
                              ),
                            ),

                            // 2. TIMELINE LINE
                            Column(
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 10),
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.white,
                                    border: Border.all(color: statusColor, width: 3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                if (!isLast)
                                  Expanded(
                                      child: Container(
                                          width: 2,
                                          color: isDark ? Colors.white10 : Colors.grey[200])),
                              ],
                            ),

                            // 3. EXAM CARD
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5))
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // HEADER ROW
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white10
                                                    : primaryColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                exam.code ??
                                                    (exam.title.length > 3
                                                        ? exam.title.substring(0, 3).toUpperCase()
                                                        : 'EXAM'),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white : primaryColor),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                // ── CALENDAR ICON BUTTON ──
                                                if (!isDone)
                                                  GestureDetector(
                                                    onTap: () => _addExamToCalendar(exam),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(6),
                                                      margin: const EdgeInsets.only(right: 6),
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? Colors.white10
                                                            : _accentGold.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(
                                                        Icons.calendar_month_rounded,
                                                        size: 16,
                                                        color: _accentGold,
                                                      ),
                                                    ),
                                                  ),
                                                // STATUS BADGE
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 10,
                                                        color: statusColor),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          exam.title,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: textColor),
                                        ),
                                        const SizedBox(height: 8),

                                        // DETAILS ROW
                                        Row(
                                          children: [
                                            Icon(Icons.access_time, size: 14, color: subTextColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat('h:mm a').format(date.toLocal()),
                                              style: TextStyle(fontSize: 13, color: subTextColor),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(Icons.location_on,
                                                size: 14, color: _accentGold),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                exam.venue ?? 'N/A',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: subTextColor,
                                                    fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ── DUAL FABs ─────────────────────────────────────────────────────
      floatingActionButton: timetableAsync.maybeWhen(
        data: (_) {
          final exams = examsAsync.value ?? [];
          if (exams.isEmpty) return null;

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // FAB 1 — Add All to Calendar
              FloatingActionButton.extended(
                heroTag: 'fab_calendar',
                onPressed: () => _addAllExamsToCalendar(exams),
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _accentGold, width: 2),
                ),
                icon: Icon(Icons.calendar_month_rounded, color: _accentGold),
                label: Text(
                  'Add All',
                  style: TextStyle(color: _accentGold, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              // FAB 2 — AI Study Plan
              FloatingActionButton.extended(
                heroTag: 'fab_study',
                onPressed: () => _createStudyPlan(exams),
                backgroundColor: _accentGold,
                foregroundColor: Colors.black,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Study Plan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
        orElse: () => null,
      ),
    );
  }
}