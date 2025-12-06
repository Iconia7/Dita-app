import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/dita_loader.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final Color _primaryDark = const Color(0xFF003366);
  final Color _accentGold = const Color(0xFFFFD700);

  // For Filter
  String _selectedCategory = 'ALL';

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostSheet(),
    ).then((val) {
      if (val == true) setState(() {}); // Refresh if posted
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Community Hub 💬", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All'),
                const SizedBox(width: 10),
                _buildFilterChip('ACADEMIC', 'Academic 📚'),
                const SizedBox(width: 10),
                _buildFilterChip('GENERAL', 'General 📢'),
                const SizedBox(width: 10),
                _buildFilterChip('MARKET', 'Market 💼'),
              ],
            ),
          ),

          // Feed
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: ApiService.getCommunityPosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: DaystarSpinner());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
  return EmptyStateWidget(
    svgPath: 'assets/svgs/no_post.svg', // Or a new chat.svg
    title: "Quiet in here...",
    message: "Be the first to start a conversation! Ask a question or share some news.",
    actionLabel: "Create Post",
    onActionPressed: _showCreatePostSheet,
  );
}

                var posts = snapshot.data!;
                if (_selectedCategory != 'ALL') {
                  posts = posts.where((p) => p['category'] == _selectedCategory).toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return _PostCard(post: posts[index], primaryDark: _primaryDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostSheet,
        backgroundColor: _accentGold,
        foregroundColor: _primaryDark,
        icon: const Icon(Icons.edit),
        label: const Text("New Post"),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    bool isSelected = _selectedCategory == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedCategory = key),
      selectedColor: _primaryDark,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
      backgroundColor: Colors.white,
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final Color primaryDark;

  const _PostCard({required this.post, required this.primaryDark});

  @override
  Widget build(BuildContext context) {
    bool isAnon = post['is_anonymous'] ?? false;
    Color badgeColor;
    switch (post['category']) {
      case 'ACADEMIC':
        badgeColor = Colors.blue;
        break;
      case 'MARKET':
        badgeColor = Colors.green;
        break;
      default:
        badgeColor = Colors.orange;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isAnon ? Colors.grey[300] : primaryDark.withOpacity(0.1),
                  backgroundImage: (post['avatar'] != null && !isAnon) ? NetworkImage(post['avatar']) : null,
                  child: (post['avatar'] == null || isAnon) 
                    ? Icon(isAnon ? Icons.visibility_off : Icons.person, color: isAnon ? Colors.grey : primaryDark) 
                    : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      DateFormat('MMM d, h:mm a').format(DateTime.parse(post['created_at'])),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                  child: Text(post['category'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
                )
              ],
            ),
            const SizedBox(height: 12),
            
            // Content
            Text(post['content'], style: const TextStyle(fontSize: 15, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis,),
            const SizedBox(height: 15),
            
            const Divider(),
            
            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionBtn(
                  icon: Icons.thumb_up_alt_outlined, 
                  label: "${post['likes']} Likes", 
                  onTap: () async {
                    await ApiService.likePost(post['id']);
                    // Ideally refresh state locally, but for v1 just api call
                  }
                ),
                _ActionBtn(
                  icon: Icons.chat_bubble_outline, 
                  label: "${post['comment_count']} Comments", 
                  onTap: () {
                    // Open Comments Sheet
                    showModalBottomSheet(
                      context: context, 
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CommentsSheet(postId: post['id'], primaryDark: primaryDark)
                    );
                  }
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(children: [Icon(icon, size: 18, color: Colors.grey[600]), const SizedBox(width: 5), Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))]),
      ),
    );
  }
}

// --- CREATE POST SHEET ---
class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _contentController = TextEditingController();
  String _category = 'GENERAL';
  bool _isAnon = false;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_contentController.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    bool success = await ApiService.createPost({
      'content': _contentController.text,
      'category': _category,
      'is_anonymous': _isAnon
    });

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) Navigator.pop(context, true); // Return true to refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("New Post", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              filled: true,
              fillColor: const Color(0xFFF5F7FA)
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              DropdownButton<String>(
                value: _category,
                items: const [
                  DropdownMenuItem(value: 'GENERAL', child: Text("General 📢")),
                  DropdownMenuItem(value: 'ACADEMIC', child: Text("Academic 📚")),
                  DropdownMenuItem(value: 'MARKET', child: Text("Market 💼")),
                ], 
                onChanged: (v) => setState(() => _category = v!)
              ),
              const Spacer(),
              Row(
                children: [
                  Checkbox(value: _isAnon, onChanged: (v) => setState(() => _isAnon = v!)),
                  const Text("Anonymous")
                ],
              )
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003366), foregroundColor: Colors.white),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("POST"),
            ),
          )
        ],
      ),
    );
  }
}

// --- COMMENTS SHEET ---
class CommentsSheet extends StatefulWidget {
  final int postId;
  final Color primaryDark;
  const CommentsSheet({super.key, required this.postId, required this.primaryDark});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final data = await ApiService.getComments(widget.postId);
    if(mounted) setState(() { _comments = data; _loading = false; });
  }

  Future<void> _postComment() async {
    if (_commentController.text.isEmpty) return;
    bool success = await ApiService.postComment(widget.postId, _commentController.text);
    if (success) {
      _commentController.clear();
      _loadComments(); // Refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.primaryDark)),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading 
              ? const Center(child: DaystarSpinner())
              : _comments.isEmpty 
                ? const Center(child: Text("No comments yet."))
                : ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final c = _comments[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: c['avatar'] != null ? NetworkImage(c['avatar']) : null,
                          child: c['avatar'] == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(c['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(c['text']),
                        trailing: Text(DateFormat('h:mm a').format(DateTime.parse(c['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(15, 10, 15, MediaQuery.of(context).viewInsets.bottom + 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15)
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _postComment, 
                  icon: Icon(Icons.send, color: widget.primaryDark),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}