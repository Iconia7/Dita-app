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
  // Instagram/Threads Style Colors
  final Color _primaryDark = const Color(0xFF003366);
  
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
      backgroundColor: Colors.white, // Clean white background
      appBar: AppBar(
        // Instagram Style Header
        title: Text(
          "Community", 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: _primaryDark, letterSpacing: -0.5)
        ),
        backgroundColor: Colors.white,
        foregroundColor: _primaryDark,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: false, // Left align title
        actions: [
          // 🚀 SOLVED: "New Post" button moved here to avoid AI button conflict
          IconButton(
            onPressed: _showCreatePostSheet,
            icon: const Icon(Icons.add_box_outlined, size: 28),
            tooltip: "New Post",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips (Stories Style)
          Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[100]!))
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              children: [
                _buildFilterChip('ALL', 'For You'),
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
                  return const Center(child: DaystarSpinner()); // Your loader
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return SingleChildScrollView(
                    child: EmptyStateWidget(
                      svgPath: 'assets/svgs/no_post.svg', 
                      title: "Start the conversation",
                      message: "The feed is empty. Tap the + button to share something with the campus!",
                      actionLabel: "Create First Post",
                      onActionPressed: _showCreatePostSheet,
                    ),
                  );
                }

                var posts = snapshot.data!;
                if (_selectedCategory != 'ALL') {
                  posts = posts.where((p) => p['category'] == _selectedCategory).toList();
                }

                return RefreshIndicator(
                  onRefresh: () async { setState(() {}); },
                  color: _primaryDark,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100), // Space for bottom nav
                    itemCount: posts.length,
                    separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey[100]),
                    itemBuilder: (context, index) {
                      return _PostItem(post: posts[index], primaryDark: _primaryDark,onPostDeleted: () {
    setState(() {}); // Refresh the list to remove the deleted post
  },);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // NO FLOATING ACTION BUTTON HERE (It's now in AppBar)
    );
  }

  Widget _buildFilterChip(String key, String label) {
    bool isSelected = _selectedCategory == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryDark : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 13
            ),
          ),
        ),
      ),
    );
  }
}

// --- INSTAGRAM STYLE POST ITEM ---
// ... Imports ...

// --- INSTAGRAM STYLE POST ITEM (STATEFUL FOR OPTIMISTIC LIKE) ---
class _PostItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final Color primaryDark;
  final VoidCallback onPostDeleted; // Callback to refresh list

  const _PostItem({
    required this.post, 
    required this.primaryDark,
    required this.onPostDeleted
  });

  @override
  State<_PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<_PostItem> {
  late bool isLiked;
  late int likeCount;
  late String displayContent;
  late String displayCategory;

  @override
  void initState() {
    super.initState();
    // Initialize local state from API data
    isLiked = widget.post['is_liked'] ?? false;
    likeCount = widget.post['likes'] ?? 0;
    displayContent = widget.post['content'];
    displayCategory = widget.post['category'];
  }

  void _handleLike() async {
    // 1. Optimistic Update (Instant feedback)
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    // 2. Network Request
    final result = await ApiService.likePost(widget.post['id']);

    // 3. Correction (if server disagrees)
    if (result != null) {
      setState(() {
        likeCount = result['likes'];
        isLiked = result['is_liked'];
      });
    }
  }

  void _editPost() async {
    // Open the sheet and wait for the result (the new text/category)
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPostSheet(
        initialContent: displayContent,
        initialCategory: displayCategory,
        postId: widget.post['id'],
      ),
    );

    // If the user saved changes, update the UI instantly
    if (result != null && mounted) {
      setState(() {
        displayContent = result['content'];
        displayCategory = result['category'];
      });
    }
  }

  void _deletePost() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      bool success = await ApiService.deletePost(widget.post['id']);
      if (success) {
        widget.onPostDeleted(); // Tell parent to remove from list
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAnon = widget.post['is_anonymous'] ?? false;
    
    Color badgeColor;
    switch (displayCategory) {
      case 'ACADEMIC': badgeColor = Colors.blueAccent; break;
      case 'MARKET': badgeColor = Colors.green; break;
      default: badgeColor = Colors.orangeAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isAnon ? Colors.grey[200] : widget.primaryDark.withOpacity(0.1),
                backgroundImage: (widget.post['avatar'] != null && !isAnon) ? NetworkImage(widget.post['avatar']) : null,
                child: (widget.post['avatar'] == null || isAnon) 
                  ? Icon(isAnon ? Icons.visibility_off : Icons.person, size: 18, color: isAnon ? Colors.grey : widget.primaryDark) 
                  : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(widget.post['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 5),
                        if (widget.post['category'] != 'GENERAL')
                          Text("• $displayCategory", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
                      ],
                    ),
                    Text(
                      DateFormat('MMM d').format(DateTime.parse(widget.post['created_at'])),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              // DELETE OPTION (Only for Owner)
              if (widget.post['is_owner'] ?? false) // Check ownership
                PopupMenuButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'delete') _deletePost();
                    if (val == 'edit') _editPost(); // 🟢 HANDLE EDIT
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 10), Text("Edit")]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 10), Text("Delete", style: TextStyle(color: Colors.red))]),
                    ),
                  ],
                )
            ],
          ),

          // CONTENT
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Text(
              displayContent, 
              style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF262626)),
            ),
          ),

          // ACTION BAR
          Row(
            children: [
              GestureDetector(
                onTap: _handleLike,
                child: Row(
                  children: [
                    Icon(isLiked ? Icons.favorite : Icons.favorite_border_rounded, size: 26, color: isLiked ? Colors.red : Colors.black87),
                    const SizedBox(width: 6),
                    if (likeCount > 0) 
                      Text("$likeCount", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              _IconAction(
                icon: Icons.chat_bubble_outline_rounded, 
                label: "${widget.post['comment_count']}",
                onTap: () {
                  showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CommentsSheet(postId: widget.post['id'], primaryDark: widget.primaryDark)
                  );
                },
              ),
              const Spacer(),
              const Icon(Icons.bookmark_border_rounded, size: 24, color: Colors.black54),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IconAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 26, color: Colors.black87),
          const SizedBox(width: 6),
          if (label != "0") 
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
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


class EditPostSheet extends StatefulWidget {
  final String initialContent;
  final String initialCategory;
  final int postId;

  const EditPostSheet({
    super.key,
    required this.initialContent,
    required this.initialCategory,
    required this.postId,
  });

  @override
  State<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<EditPostSheet> {
  late TextEditingController _contentController;
  late String _category;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _category = widget.initialCategory;
  }

  Future<void> _submit() async {
    if (_contentController.text.isEmpty) return;
    setState(() => _isLoading = true);

    Map<String, dynamic> data = {
      'content': _contentController.text,
      'category': _category,
    };

    bool success = await ApiService.editPost(widget.postId, data);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Return the new data to the parent so it can update the UI
        Navigator.pop(context, data); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post updated!"), backgroundColor: Colors.green)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Edit Post", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
            ),
          ),
          const SizedBox(height: 15),
          DropdownButton<String>(
            value: _category,
            items: const [
              DropdownMenuItem(value: 'GENERAL', child: Text("General 📢")),
              DropdownMenuItem(value: 'ACADEMIC', child: Text("Academic 📚")),
              DropdownMenuItem(value: 'MARKET', child: Text("Market 💼")),
            ],
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003366), foregroundColor: Colors.white),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE CHANGES"),
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
                      bool isOwner = c['is_owner'] ?? false;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: c['avatar'] != null ? NetworkImage(c['avatar']) : null,
                          child: c['avatar'] == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(c['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(c['text']),
                        trailing: isOwner 
      ? IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
          onPressed: () async {
             // Delete Logic
             bool success = await ApiService.deleteComment(c['id']);
             if (success) _loadComments(); // Refresh list
          },
        )
      : Text(DateFormat('h:mm a').format(DateTime.parse(c['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
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