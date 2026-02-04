import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/study_group_provider.dart';
import 'study_group_chat_screen.dart';

class StudyGroupsScreen extends ConsumerWidget {
  const StudyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(studyGroupsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Study Groups 📚", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: groupsAsync.when(
        data: (groups) => RefreshIndicator(
          onRefresh: () => ref.read(studyGroupsProvider.notifier).loadGroups(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    "${group.courseCode}: ${group.name}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(group.description),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.people, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text("${group.memberCount} members", style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: group.isMember ? Colors.grey : const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      if (group.isMember) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudyGroupChatScreen(group: group),
                          ),
                        );
                      } else {
                        ref.read(studyGroupsProvider.notifier).joinGroup(group.id);
                      }
                    },
                    child: Text(group.isMember ? "Chat" : "Join"),
                  ),
                  onTap: group.isMember ? () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudyGroupChatScreen(group: group),
                      ),
                    );
                  } : null,
                ),
              );
            },
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroupDialog(context, ref),
        label: const Text("Create Group", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.black),
        backgroundColor: const Color(0xFFFFD700),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create Study Group"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: "Course Code (e.g. SMA 202)"),
                textCapitalization: TextCapitalization.characters,
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Group Name"),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && codeController.text.isNotEmpty) {
                ref.read(studyGroupsProvider.notifier).createGroup(
                  nameController.text.trim(),
                  codeController.text.trim(),
                  descController.text.trim(),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Creating group...")),
                );
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}
