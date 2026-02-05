import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/study_group_provider.dart';
import 'study_group_chat_screen.dart';

class StudyGroupsScreen extends ConsumerStatefulWidget {
  const StudyGroupsScreen({super.key});

  @override
  ConsumerState<StudyGroupsScreen> createState() => _StudyGroupsScreenState();
}

class _StudyGroupsScreenState extends ConsumerState<StudyGroupsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StudyGroupModel> _filterGroups(List<StudyGroupModel> groups) {
    if (_searchQuery.isEmpty) return groups;
    
    final query = _searchQuery.toLowerCase();
    return groups.where((group) {
      return group.name.toLowerCase().contains(query) ||
             group.courseCode.toLowerCase().contains(query) ||
             group.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(studyGroupsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Study Groups 📚", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
         decoration: BoxDecoration(
           color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
         ),
         child: Column(
           children: [
             // Functional Search Bar
             Container(
               padding: const EdgeInsets.fromLTRB(16, 110, 16, 16), // Top padding for transparent app bar
               decoration: BoxDecoration(
                 color: Theme.of(context).primaryColor.withOpacity(0.05),
                 borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
               ),
               child: TextField(
                 controller: _searchController,
                 onChanged: (value) {
                   setState(() {
                     _searchQuery = value;
                   });
                 },
                 decoration: InputDecoration(
                   hintText: "Search groups...",
                   prefixIcon: const Icon(Icons.search),
                   suffixIcon: _searchQuery.isNotEmpty
                       ? IconButton(
                           icon: const Icon(Icons.clear),
                           onPressed: () {
                             setState(() {
                               _searchController.clear();
                               _searchQuery = '';
                             });
                           },
                         )
                       : null,
                   filled: true,
                   fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                   contentPadding: const EdgeInsets.symmetric(vertical: 0),
                 ),
               ),
             ),
             Expanded(
               child: groupsAsync.when(
                 data: (groups) {
                   final filteredGroups = _filterGroups(groups);
                   
                   if (filteredGroups.isEmpty) {
                     return Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                           const SizedBox(height: 16),
                           Text(
                             _searchQuery.isEmpty ? 'No study groups yet' : 'No groups found',
                             style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                           ),
                           if (_searchQuery.isNotEmpty) ...[
                             const SizedBox(height: 8),
                             Text(
                               'Try searching with different keywords',
                               style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                             ),
                           ],
                         ],
                       ),
                     );
                   }
                   
                   return RefreshIndicator(
                     onRefresh: () => ref.read(studyGroupsProvider.notifier).loadGroups(),
                     child: ListView.builder(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       itemCount: filteredGroups.length,
                       itemBuilder: (context, index) {
                         final group = filteredGroups[index];
                         return Container(
                           margin: const EdgeInsets.only(bottom: 16),
                           decoration: BoxDecoration(
                             color: isDark ? const Color(0xFF1F2937) : Colors.white,
                             borderRadius: BorderRadius.circular(20),
                             boxShadow: [
                               BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
                             ],
                           ),
                           child: Material(
                             color: Colors.transparent,
                             child: InkWell(
                               borderRadius: BorderRadius.circular(20),
                               onTap: group.isMember ? () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => StudyGroupChatScreen(group: group)));
                               } : null,
                               child: Padding(
                                 padding: const EdgeInsets.all(16),
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Row(
                                       children: [
                                         Container(
                                           padding: const EdgeInsets.all(12),
                                           decoration: BoxDecoration(
                                             gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                                             borderRadius: BorderRadius.circular(15),
                                             boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                                           ),
                                           child: Text(
                                             group.courseCode, 
                                             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                           ),
                                         ),
                                         const SizedBox(width: 12),
                                         Expanded(
                                           child: Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                               Text(
                                                 group.name,
                                                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                 maxLines: 1, overflow: TextOverflow.ellipsis,
                                               ),
                                               const SizedBox(height: 4),
                                               Row(
                                                 children: [
                                                   Icon(Icons.people_rounded, size: 14, color: Colors.grey[500]),
                                                   const SizedBox(width: 4),
                                                   Text("${group.memberCount} members", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                                 ],
                                               ),
                                             ],
                                           ),
                                         ),
                                         if (group.isMember)
                                            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                                       ],
                                     ),
                                     if (group.description.isNotEmpty) ...[ 
                                       const SizedBox(height: 12),
                                       Text(
                                         group.description,
                                         maxLines: 2,
                                         overflow: TextOverflow.ellipsis,
                                         style: const TextStyle(color: Colors.grey, fontSize: 13),
                                       ),
                                     ],
                                     if (!group.isMember) ...[
                                       const SizedBox(height: 16),
                                       SizedBox(
                                         width: double.infinity,
                                         child: ElevatedButton(
                                           style: ElevatedButton.styleFrom(
                                             backgroundColor: Theme.of(context).primaryColor,
                                             foregroundColor: Colors.white,
                                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                             padding: const EdgeInsets.symmetric(vertical: 12),
                                           ),
                                           onPressed: () {
                                             ref.read(studyGroupsProvider.notifier).joinGroup(group.id);
                                           },
                                           child: const Text("Join Group", style: TextStyle(fontWeight: FontWeight.bold)),
                                         ),
                                       ),
                                     ]
                                   ],
                                 ),
                               ),
                             ),
                           ),
                         );
                       },
                     ),
                   );
                 },
                 loading: () => const Center(child: CircularProgressIndicator()),
                 error: (err, stack) => Center(child: Text("Error: $err")),
               ),
             ),
           ],
         ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroupDialog(context, ref),
        label: const Text("Create Group", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 4,
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
