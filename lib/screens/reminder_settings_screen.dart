import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/storage_keys.dart';
import '../services/notification.dart';
import '../utils/app_logger.dart';

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  ConsumerState<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen> {
  int _classLeadTime = 30;
  int _taskLeadTime = 15;
  bool _isNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _classLeadTime = LocalStorage.getItem<int>(StorageKeys.settingsBox, 'class_lead_time') ?? 30;
      _taskLeadTime = LocalStorage.getItem<int>(StorageKeys.settingsBox, 'task_lead_time') ?? 15;
      _isNotificationsEnabled = NotificationService.isEnabled;
    });
  }

  Future<void> _saveLeadTime(String key, int value) async {
    await LocalStorage.setItem(StorageKeys.settingsBox, key, value);
    AppLogger.info('Saved $key: $value mins');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Updated lead time to $value mins"), duration: const Duration(seconds: 1)),
    );
  }

  void _testNotification() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 999,
        channelKey: 'dita_planner_channel_v4',
        title: '🔔 Test Notification',
        body: 'Your reminder settings are working perfectly!',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reminder Settings"),
        actions: [
          IconButton(
            onPressed: _testNotification,
            icon: const Icon(Icons.notification_important_outlined),
            tooltip: "Test Notification",
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Global Settings"),
          SwitchListTile(
            title: const Text("Enable Notifications"),
            subtitle: const Text("Receive alerts for classes and tasks"),
            value: _isNotificationsEnabled,
            activeColor: Theme.of(context).primaryColor,
            onChanged: (val) async {
              setState(() => _isNotificationsEnabled = val);
              await NotificationService.toggleNotifications(val);
            },
          ),
          
          const Divider(height: 40),
          
          _buildSectionHeader("Class Reminders"),
          _buildLeadTimeSelector(
            title: "Notify me before class",
            currentValue: _classLeadTime,
            onChanged: (val) {
              setState(() => _classLeadTime = val!);
              _saveLeadTime('class_lead_time', val!);
            },
          ),
          
          const SizedBox(height: 30),
          
          _buildSectionHeader("Task & Exam Reminders"),
          _buildLeadTimeSelector(
            title: "Notify me before tasks",
            currentValue: _taskLeadTime,
            onChanged: (val) {
              setState(() => _taskLeadTime = val!);
              _saveLeadTime('task_lead_time', val!);
            },
          ),

          const SizedBox(height: 50),
          
          Card(
            color: Colors.blue.withOpacity(0.1),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: const Padding(
              padding: EdgeInsets.all(15.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "Updates apply to new schedules. Refresh your timetable to re-sync existing ones.",
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLeadTimeSelector({
    required String title,
    required int currentValue,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [10, 15, 30, 45, 60].map((mins) {
            final isSelected = mins == currentValue;
            return ChoiceChip(
              label: Text("$mins mins"),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) onChanged(mins);
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
