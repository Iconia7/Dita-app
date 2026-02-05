import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dita_app/widgets/dita_loader.dart';
import 'package:dita_app/widgets/skeleton_loader.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:dita_app/providers/timetable_provider.dart';
import 'package:dita_app/data/models/timetable_model.dart';
import '../services/notification.dart';
import '../providers/ai_provider.dart';
import 'ai_assistant_screen.dart';

class ExamTimetableScreen extends ConsumerStatefulWidget {
  const ExamTimetableScreen({super.key});

  @override
  ConsumerState<ExamTimetableScreen> createState() => _ExamTimetableScreenState();
}

class _ExamTimetableScreenState extends ConsumerState<ExamTimetableScreen> { 
  final Color _accentGold = const Color(0xFFFFD700);
  final Color _urgentRed = const Color(0xFFEF4444);

  final TextEditingController _codeController = TextEditingController();
  // Filter list (optional usage if we want to filter the provider data)
  List<String> _filterCodes = [];

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _scheduleExamReminders(List<TimetableModel> exams) {
    for (var exam in exams) {
      if (exam.examDate == null) continue;
      
      int notifId = (exam.code ?? exam.title).hashCode; 
      _scheduleSpecificExamAlarm(notifId, exam.code ?? exam.title, exam.venue ?? 'Unknown', exam.examDate!);
    }
  }

  void _createStudyPlan(List<TimetableModel> exams) {
    if (exams.isEmpty) return;

    final examListStr = exams.map((e) => "- ${e.code ?? e.title}: ${e.examDate != null ? DateFormat('MMM d').format(e.examDate!) : 'Unknown Date'}").join("\n");
    final prompt = "I have the following exams coming up:\n$examListStr\n\nPlease create a detailed 7-day study plan to help me prepare for these, prioritizing the ones happening soonest. Include break times.";

    // Send prompt to AI
    ref.read(chatProvider.notifier).sendMessage(prompt);

    // Navigate to AI screen
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const AiAssistantScreen())
    );
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
         title: "Exam: $code",
         deadline: examTime, 
         // venue: venue, // Pass venue if service supports it
      );
  }

  String _getDaysRemaining(DateTime examDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
    final diff = examDay.difference(today).inDays;

    if (diff < 0) return "Done";
    if (diff == 0) return "Today";
    if (diff == 1) return "Tomorrow";
    return "in $diff Days";
  }

  Color _getStatusColor(String status, Color defaultColor) {
    if (status == "Today" || status == "Tomorrow") return _urgentRed;
    if (status == "Done") return Colors.grey;
    return defaultColor; 
  }

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

    // Listen to timetable changes and fetch exams when it changes
    ref.listen<AsyncValue<List<TimetableModel>>>(timetableProvider, (previous, next) {
      next.whenData((items) {
        final codes = items
            .where((i) => i.isClass)
            .map((i) => i.code ?? "")
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        
        if (codes.isNotEmpty) {
          ref.read(examsProvider.notifier).fetchExams(codes);
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
                title: const Text("Exams", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
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
                                hintText: "Search by course code...",
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
                    // Refresh both classes and exams
                    ref.refresh(timetableProvider);
                    final items = ref.read(timetableProvider).value ?? [];
                    final codes = items.where((i) => i.isClass).map((i) => i.code ?? "").where((c) => c.isNotEmpty).toSet().toList();
                    ref.read(examsProvider.notifier).fetchExams(codes);
                  }
                )
              ],
            ),
          ];
        },
        body: examsAsync.when(
          loading: () => const TimetableSkeleton(),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (exams) {
            // Apply filtering if user is searching manually
            if (_codeController.text.isNotEmpty) {
              final query = _codeController.text.toUpperCase();
              exams = exams.where((e) => 
                (e.code?.toUpperCase().contains(query) ?? false) || 
                (e.title?.toUpperCase().contains(query) ?? false)
              ).toList();
            }

            if (exams.isEmpty) {
              return EmptyStateWidget(
                svgPath: 'assets/svgs/no_results.svg',
                title: "No Exams Found",
                message: _codeController.text.isEmpty 
                    ? "Go to Timetable to sync your units first." 
                    : "No exams match your search for '${_codeController.text}'.",
                actionLabel: "Search",
                onActionPressed: () {
                  if (_codeController.text.isNotEmpty) {
                    ref.read(examsProvider.notifier).fetchExams([_codeController.text]);
                  }
                },
              );
            }

            // Sort by date
            exams.sort((a, b) => (a.examDate ?? DateTime.now()).compareTo(b.examDate ?? DateTime.now()));

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              itemCount: exams.length,
              itemBuilder: (context, index) {
                final exam = exams[index];
                if (exam.examDate == null) return const SizedBox.shrink();

                final date = exam.examDate!;
                final status = _getDaysRemaining(date);
                final statusColor = _getStatusColor(status, primaryColor);
                final bool isLast = index == exams.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. DATE COLUMN
                      SizedBox(
                        width: 50,
                        child: Column(
                          children: [
                            Text(DateFormat('MMM').format(date).toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor)),
                            Text(DateFormat('dd').format(date), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
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
                            Expanded(child: Container(width: 2, color: isDark ? Colors.white10 : Colors.grey[200])),
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
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // HEADER
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6)
                                        ),
                                        child: Text(
                                          exam.code ?? exam.title.substring(0, 3).toUpperCase(), 
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, 
                                             color: isDark ? Colors.white : primaryColor)
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6)
                                        ),
                                        child: Text(status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(exam.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                  const SizedBox(height: 8),
                                  
                                  // DETAILS
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 14, color: subTextColor),
                                      const SizedBox(width: 4),
                                      Text(DateFormat('h:mm a').format(date), style: TextStyle(fontSize: 13, color: subTextColor)),
                                      const SizedBox(width: 15),
                                      Icon(Icons.location_on, size: 14, color: _accentGold),
                                      const SizedBox(width: 4),
                                      Text(exam.venue ?? 'N/A', style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500)),
                                    ],
                                  )
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
          }
        ),

      ),
      floatingActionButton: timetableAsync.maybeWhen(
        data: (data) {
           final exams = examsAsync.value ?? [];
           if (exams.isEmpty) return null;
           return FloatingActionButton.extended(
             onPressed: () {
                final exams = examsAsync.value ?? [];
                _createStudyPlan(exams);
              },
             backgroundColor: _accentGold,
             foregroundColor: Colors.black, // Dark text on gold
             icon: const Icon(Icons.auto_awesome),
             label: const Text("Study Plan", style: TextStyle(fontWeight: FontWeight.bold)),
           );
        },
        orElse: () => null,
      ),
    );
  }
}