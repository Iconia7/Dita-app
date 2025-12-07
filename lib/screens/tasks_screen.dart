import 'dart:convert';
import 'package:dita_app/widgets/dita_loader.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification.dart'; 

class TasksScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const TasksScreen({super.key, required this.user});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final Color _accentGold = const Color(0xFFFFD700);
  
  bool _isLoading = true;
  List<dynamic> _tasks = [];

  @override
  void initState() {
    super.initState();
    NotificationService.requestLocalPermissions();
    _initData();
  }

  void _initData() async {
    await _loadTasksLocally();
    await _fetchTasks();
  }

  // --- DATA LOGIC ---
  Future<void> _loadTasksLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedData = prefs.getString('cached_tasks_${widget.user['id']}');
    
    if (cachedData != null && mounted) {
      setState(() {
        _tasks = json.decode(cachedData);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTasksLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_tasks_${widget.user['id']}', json.encode(_tasks));
  }

  Future<void> _fetchTasks() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tasks/?user_id=${widget.user['id']}'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final serverTasks = json.decode(response.body);
        setState(() {
          _tasks = serverTasks;
          _isLoading = false;
        });
        _saveTasksLocally();
      }
    } catch (e) {
      print("Network Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Offline Mode"), duration: Duration(seconds: 1))
        );
      }
    }
  }

  Future<void> _addTask(String title, DateTime date) async {
    // Use seconds for ID to be safe with Notifications
    int tempId = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    
    final data = {
      "id": tempId,
      "user_id": widget.user['id'],
      "title": title,
      "due_date": date.toIso8601String(),
      "is_completed": false
    };

    setState(() {
      _tasks.add(data);
      _tasks.sort((a, b) => a['due_date'].compareTo(b['due_date']));
    });
    _saveTasksLocally();

    try {
      await NotificationService.scheduleTaskNotification(
        id: tempId, 
        title: title, 
        deadline: date
      );
    } catch (e) { print("Notify Error: $e"); }

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/tasks/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": widget.user['id'],
          "title": title,
          "due_date": date.toIso8601String(),
          "is_completed": false
        }),
      );

      if (response.statusCode == 201) {
        final newTask = json.decode(response.body);
        // Swap Temp ID with Real ID
        setState(() {
          int index = _tasks.indexWhere((t) => t['id'] == tempId);
          if(index != -1) _tasks[index]['id'] = newTask['id'];
        });
        _saveTasksLocally();
        
        await NotificationService.cancelNotification(tempId);
        try {
           await NotificationService.scheduleTaskNotification(
             id: newTask['id'], title: title, deadline: date
           );
        } catch (e) { print("Reschedule error: $e"); }
      }
    } catch (e) {
      print("Saved offline.");
    }
  }

  Future<void> _toggleTask(int id, bool currentStatus) async {
    // 1. Optimistic Update
    int index = _tasks.indexWhere((t) => t['id'] == id);
    if(index != -1) {
        setState(() {
            _tasks[index]['is_completed'] = !currentStatus;
        });
        _saveTasksLocally();
    }

    // 2. Send to Server
    try {
      print("Attempting PATCH for task ID: $id to status: ${!currentStatus}");
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/tasks/$id/?user_id=${widget.user['id']}'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"is_completed": !currentStatus}),
      );
      print("PATCH Response: ${response.statusCode} - ${response.body}");
    } catch (e) {
       print("Error updating task: $e");
    }
  }
  
  Future<void> _deleteTask(int id) async {
      // Cancel Notification
      await NotificationService.cancelNotification(id);
      
      // Remove UI
      setState(() {
          _tasks.removeWhere((t) => t['id'] == id);
      });
      _saveTasksLocally();
      
      // Remove Server
      try {
        await http.delete(Uri.parse('${ApiService.baseUrl}/tasks/$id/?user_id=${widget.user['id']}')
      );
      } catch (e) {
        print("Error deleting task: $e");
      }
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
          // 🟢 Theme Helpers (Inside Builder)
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
              color: sheetColor, // 🟢 Dynamic BG
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: primaryColor, size: 28), // 🟢
                    const SizedBox(width: 10),
                    Text("New Assignment", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)), // 🟢
                  ],
                ),
                const SizedBox(height: 20),
                
                // Stylish Input
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor), // 🟢
                  decoration: InputDecoration(
                    hintText: "What needs to be done?",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.task_alt_rounded, color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: inputFill, // 🟢
                    contentPadding: const EdgeInsets.all(18),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Date Picker Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  decoration: BoxDecoration(
                    color: inputFill, // 🟢
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
                          Text("Due Date", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.black54)), // 🟢
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
                              color: isDark ? Colors.white10 : Colors.white, // 🟢
                              borderRadius: BorderRadius.circular(10), 
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
                          ),
                          child: Text(DateFormat('MMM d, h:mm a').format(selectedDate), 
                              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor)), // 🟢
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                
                // --- SAVE BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleController.text.isEmpty) return;

                      // 1. VALIDATION CHECK
                      if (selectedDate.isBefore(DateTime.now())) {
                        // Show Alert Dialog ABOVE the sheet
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
                        return; // Stop here
                      }

                      // 2. Proceed if valid
                      _addTask(titleController.text, selectedDate);
                      Navigator.pop(context);
                    },
                   style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor, // 🟢
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
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: scaffoldBg, // 🟢 Dynamic BG
      appBar: AppBar(
        title: const Text("Student Planner", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white), // Ensure back button is white
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchTasks();
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
        backgroundColor: _accentGold,
        icon: const Icon(Icons.add_task_rounded, color: Colors.black), // Gold BG -> Black Icon
        label: const Text("New Task", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading && _tasks.isEmpty 
        ? const Center(child: DaystarSpinner(size: 120))
        : _tasks.isEmpty 
          ? EmptyStateWidget(
              svgPath: 'assets/svgs/no_task.svg', 
              title: "All Caught Up!",
              message: "You have zero pending tasks. Enjoy your free time or plan ahead.",
              actionLabel: "Add New Task",
              onActionPressed: _showAddTaskSheet, 
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                bool isDone = task['is_completed'] ?? false;
                
                return Dismissible(
                  key: Key(task['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteTask(task['id']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: cardColor, // 🟢 Dynamic Card Color
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                      border: Border.all(color: isDone ? Colors.green.withOpacity(0.3) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        // 1. TOGGLE BUTTON
                        GestureDetector(
                          onTap: () => _toggleTask(task['id'], isDone),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: isDone ? Colors.green : (isDark ? Colors.white10 : const Color(0xFFF4F6F9)), // 🟢 Dynamic Checkbox BG
                              shape: BoxShape.circle,
                              border: Border.all(color: isDone ? Colors.green : Colors.grey[300]!, width: 2)
                            ),
                            child: isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        ),
                        const SizedBox(width: 15),
                        
                        // 2. TEXT INFO
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _toggleTask(task['id'], isDone),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['title'], 
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold,
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                    color: isDone ? Colors.grey[400] : textColor // 🟢 Dynamic Text
                                  )
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 14, color: isDone ? Colors.grey[300] : Colors.red[300]),
                                    const SizedBox(width: 5),
                                    Text(
                                      DateFormat('MMM d, h:mm a').format(DateTime.parse(task['due_date'])),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDone ? Colors.grey[400] : Colors.grey[600]), // Grey is fine here
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
                          onPressed: () => _deleteTask(task['id']),
                          tooltip: "Delete Task",
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}