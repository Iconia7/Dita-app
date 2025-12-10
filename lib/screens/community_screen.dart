import 'dart:io';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Ensure this is in pubspec.yaml
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/dita_loader.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
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
    // Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final borderColor = isDark ? Colors.white10 : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          "Community", 
          style: TextStyle(
            fontWeight: FontWeight.w900, 
            fontSize: 24, 
            color: textColor,
            letterSpacing: -0.5
          )
        ),
        backgroundColor: scaffoldBg,
        foregroundColor: textColor,
        elevation: 0,
        surfaceTintColor: scaffoldBg,
        centerTitle: false, 
        actions: [
          IconButton(
            onPressed: _showCreatePostSheet,
            icon: Icon(Icons.add_box_outlined, size: 28, color: textColor),
            tooltip: "New Post",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor))
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
                  return const Center(child: DaystarSpinner(size: 120,)); 
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
                  color: primaryColor,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100), 
                    itemCount: posts.length,
                    separatorBuilder: (c, i) => Divider(height: 1, color: borderColor),
                    itemBuilder: (context, index) {
                      return _PostItem(
                        post: posts[index], 
                        primaryDark: primaryColor,
                        onPostDeleted: () => setState((){}),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    bool isSelected = _selectedCategory == key;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? primaryColor 
              : (isDark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: isDark ? Colors.transparent : Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected 
                  ? Colors.white 
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: FontWeight.bold,
              fontSize: 13
            ),
          ),
        ),
      ),
    );
  }
}

// --- POST ITEM ---
class _PostItem extends StatefulWidget {
  final Map<String, dynamic> post;
  final Color primaryDark;
  final VoidCallback onPostDeleted;

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
    isLiked = widget.post['is_liked'] ?? false;
    likeCount = widget.post['likes'] ?? 0;
    displayContent = widget.post['content'];
    displayCategory = widget.post['category'];
  }

  void _handleLike() async {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    final result = await ApiService.likePost(widget.post['id']);
    if (result != null) {
      setState(() {
        likeCount = result['likes'];
        isLiked = result['is_liked'];
      });
    }
  }

  void _editPost() async {
    // Note: Edit currently only supports text updates for simplicity
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
        backgroundColor: Theme.of(context).cardColor,
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
        widget.onPostDeleted();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    bool isAnon = widget.post['is_anonymous'] ?? false;
    
    Color badgeColor;
    switch (displayCategory) {
      case 'ACADEMIC': badgeColor = Colors.orange; break;
      case 'MARKET': badgeColor = Colors.green; break;
      default: badgeColor = Colors.blue;
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
                        Text(widget.post['username'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                        const SizedBox(width: 5),
                        if (widget.post['category'] != 'GENERAL')
                          Text("• $displayCategory", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
                      ],
                    ),
                    Text(
                      DateFormat('MMM d').format(DateTime.parse(widget.post['created_at'])),
                      style: TextStyle(color: subTextColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (widget.post['is_owner'] ?? false)
                PopupMenuButton(
                  icon: Icon(Icons.more_horiz, color: subTextColor),
                  color: Theme.of(context).cardColor,
                  onSelected: (val) {
                    if (val == 'delete') _deletePost();
                    if (val == 'edit') _editPost(); 
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 10), Text("Edit")])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 10), Text("Delete", style: TextStyle(color: Colors.red))])),
                  ],
                )
            ],
          ),

          // CONTENT
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Text(
              displayContent, 
              style: TextStyle(fontSize: 15, height: 1.4, color: textColor),
            ),
          ),
          
          // DISPLAY IMAGE IF EXISTS
          if (widget.post['image'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.post['image'],
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const SizedBox.shrink(),
                ),
              ),
            ),

          // ACTION BAR
          Row(
            children: [
              GestureDetector(
                onTap: _handleLike,
                child: Row(
                  children: [
                    Icon(isLiked ? Icons.favorite : Icons.favorite_border_rounded, size: 26, color: isLiked ? Colors.red : textColor),
                    const SizedBox(width: 6),
                    if (likeCount > 0) 
                      Text("$likeCount", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              _IconAction(
                icon: Icons.chat_bubble_outline_rounded, 
                label: "${widget.post['comment_count']}",
                color: textColor!,
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
              Icon(Icons.bookmark_border_rounded, size: 24, color: subTextColor),
            ],
          ),
        ],
      ),
    );
  }
}

// ... (_IconAction Helper stays same) ...
class _IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color; 

  const _IconAction({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(width: 6),
          if (label != "0") 
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
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
  File? _selectedImage; 

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<void> _submit() async {
    if (_contentController.text.isEmpty && _selectedImage == null) return;
    setState(() => _isLoading = true);
    
    // UPDATED: Use createPost to handle multipart upload
    bool success = await ApiService.createPost({
      'content': _contentController.text,
      'category': _category,
      'is_anonymous': _isAnon.toString(),
    }, _selectedImage);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = Theme.of(context).cardColor;
    final inputColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(color: sheetColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("New Post", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 15),
          
          TextField(
            controller: _contentController,
            maxLines: 4,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              filled: true,
              fillColor: inputColor,
            ),
          ),
          const SizedBox(height: 15),
          
          // IMAGE PICKER ROW
          Row(
            children: [
              IconButton(
                onPressed: _pickImage,
                icon: Icon(Icons.image, color: primaryColor),
                tooltip: "Add Image",
              ),
              if (_selectedImage != null)
                Expanded(
                  child: Text(
                    "Image selected", 
                    style: TextStyle(color: Colors.green, fontSize: 12),
                    overflow: TextOverflow.ellipsis
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),
          
          Row(
            children: [
              DropdownButton<String>(
                value: _category,
                dropdownColor: sheetColor,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
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
                  Checkbox(
                    value: _isAnon, 
                    activeColor: primaryColor,
                    onChanged: (v) => setState(() => _isAnon = v!)
                  ),
                  Text("Anonymous", style: TextStyle(color: textColor))
                ],
              )
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("POST"),
            ),
          )
        ],
      ),
    );
  }
}

// ... (EditPostSheet & CommentsSheet remain largely the same, edit doesn't usually support image change in v1) ...
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
        Navigator.pop(context, data); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post updated!"), backgroundColor: Colors.green)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = Theme.of(context).cardColor;
    final inputColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(color: sheetColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit Post", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 15),
          TextField(
            controller: _contentController,
            maxLines: 4,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              filled: true,
              fillColor: inputColor,
            ),
          ),
          const SizedBox(height: 15),
          DropdownButton<String>(
            value: _category,
            dropdownColor: sheetColor,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
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
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE CHANGES"),
            ),
          )
        ],
      ),
    );
  }
}

// ... (CommentsSheet remains unchanged) ...
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
      _loadComments(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = Theme.of(context).cardColor;
    final inputColor = isDark ? const Color(0xFF0F172A) : Colors.grey[100];
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(color: sheetColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading 
              ? const Center(child: DaystarSpinner(size: 120,))
              : _comments.isEmpty 
                ? Center(child: Text("No comments yet.", style: TextStyle(color: subTextColor)))
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
                        title: Text(c['username'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                        subtitle: Text(c['text'], style: TextStyle(color: textColor)),
                        trailing: isOwner 
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              onPressed: () async {
                                 bool success = await ApiService.deleteComment(c['id']);
                                 if (success) _loadComments(); 
                              },
                            )
                          : Text(DateFormat('h:mm a').format(DateTime.parse(c['created_at'])), style: TextStyle(fontSize: 10, color: subTextColor)),
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
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      hintStyle: TextStyle(color: subTextColor),
                      filled: true,
                      fillColor: inputColor,
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