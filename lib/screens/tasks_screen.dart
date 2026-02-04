import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dita_app/widgets/dita_loader.dart';
import 'package:dita_app/widgets/skeleton_loader.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:dita_app/providers/task_provider.dart';
import 'package:dita_app/data/models/task_model.dart';
import '../services/notification.dart';
import 'timer_screen.dart';
import '../providers/auth_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final Color _accentGold = const Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    NotificationService.requestLocalPermissions();
    // Tasks are loaded automatically by the provider on init
  }

  Future<void> _addTask(String title, DateTime date) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final success = await ref.read(taskProvider.notifier).createTask({
      "user_id": user.id,
      "title": title,
      "due_date": date.toIso8601String(),
      "is_completed": false
    });

    if (success && mounted) {
      // Find the created task to get its ID for notification
      // This is a slight limitation of the current create flow return type
      // But we can approximate using the latest task or handle it in provider
      // For now, simpler notification handling:
       try {
          // Just use hashcode of title+date as ID for now, or improve provider to return ID
          int notificationId = (title.hashCode + date.millisecondsSinceEpoch).abs() % 100000;
          await NotificationService.scheduleTaskNotification(
            id: notificationId, 
            title: title, 
            deadline: date
          );
        } catch (e) { 
           // ignore error
        }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save task")),
      );
    }
  }

  Future<void> _toggleTask(TaskModel task) async {
    await ref.read(taskProvider.notifier).updateTask(
      task.id, 
      {"is_completed": !task.isCompleted}
    );
  }
  
  Future<void> _deleteTask(int id) async {
    await NotificationService.cancelNotification(id);
    await ref.read(taskProvider.notifier).deleteTask(id);
  }

  // --- UI DIALOG ---
  void _showAddTaskSheet() {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final sheetColor = Theme.of(context).cardColor;
          final primaryColor = Theme.of(context).primaryColor;
          final inputFill = isDark ? Colors.white10 : const Color(0xFFF4F6F9);
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 25, left: 25, right: 25
            ),
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: primaryColor, size: 28),
                    const SizedBox(width: 10),
                    Text("New Assignment", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
                  ],
                ),
                const SizedBox(height: 20),
                
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                  decoration: InputDecoration(
                    hintText: "What needs to be done?",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.task_alt_rounded, color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.all(18),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Date Picker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.withOpacity(0.1))
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.alarm_rounded, color: _accentGold),
                          const SizedBox(width: 10),
                          Text("Due Date", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.black54)),
                        ],
                      ),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context, 
                            firstDate: DateTime.now(), 
                            initialDate: selectedDate, 
                            lastDate: DateTime(2030),
                            builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Theme.of(context).primaryColor, onPrimary: Colors.white)), child: child!)
                          );
                          if (date != null) {
                            final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
                            if (time != null) {
                               setSheetState(() => selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.white,
                              borderRadius: BorderRadius.circular(10), 
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
                          ),
                          child: Text(DateFormat('MMM d, h:mm a').format(selectedDate), 
                              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor)),
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleController.text.isEmpty) return;

                      if (selectedDate.isBefore(DateTime.now())) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            title: const Text("Invalid Time"),
                            content: const Text("You cannot schedule a task in the past! Please select a future time."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
                              )
                            ],
                          )
                        );
                        return;
                      }

                      _addTask(titleController.text, selectedDate);
                      Navigator.pop(context);
                    },
                   style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    child: const Text("Save Task", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    final tasksAsync = ref.watch(taskProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("Student Planner", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // TIMER SHORTCUT
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: "Study Timer",
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const TimerScreen())
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: () {
              ref.read(taskProvider.notifier).refresh();
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
        backgroundColor: _accentGold,
        icon: const Icon(Icons.add_task_rounded, color: Colors.black),
        label: const Text("New Task", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: tasksAsync.when(
        loading: () => const SkeletonList(
          padding: EdgeInsets.all(20),
          skeleton: TaskSkeleton(),
          itemCount: 8,
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return EmptyStateWidget(
              svgPath: 'assets/svgs/no_task.svg', 
              title: "All Caught Up!",
              message: "You have zero pending tasks. Enjoy your free time or plan ahead.",
              actionLabel: "Add New Task",
              onActionPressed: _showAddTaskSheet, 
            );
          }

          // Sort by date
          final sortedTasks = List<TaskModel>.from(tasks)..sort((a, b) => a.dueDate.compareTo(b.dueDate));

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: sortedTasks.length,
            itemBuilder: (context, index) {
              final task = sortedTasks[index];
              final isDone = task.isCompleted;
              
              return Dismissible(
                key: Key(task.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteTask(task.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                    border: Border.all(color: isDone ? Colors.green.withOpacity(0.3) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      // 1. TOGGLE BUTTON
                      Semantics(
                        label: isDone ? "Mark as incomplete" : "Mark as complete",
                        button: true,
                        child: GestureDetector(
                          onTap: () => _toggleTask(task),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: isDone ? Colors.green : (isDark ? Colors.white10 : const Color(0xFFF4F6F9)),
                              shape: BoxShape.circle,
                              border: Border.all(color: isDone ? Colors.green : Colors.grey[300]!, width: 2)
                            ),
                            child: isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      
                      // 2. TEXT INFO
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _toggleTask(task),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title, 
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  color: isDone ? Colors.grey[400] : textColor
                                )
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 14, color: isDone ? Colors.grey[300] : Colors.red[300]),
                                  const SizedBox(width: 5),
                                  Text(
                                    DateFormat('MMM d, h:mm a').format(task.dueDate),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDone ? Colors.grey[400] : Colors.grey[600]),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      ),

                      // 3. VISIBLE DELETE BUTTON
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deleteTask(task.id),
                        tooltip: "Delete Task",
                      )
                    ],
                  ),
                ),
              );
            },
          );
        }
      ),
    );
  }
}