import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:intl/intl.dart';
import '../data/models/post_model.dart';
import '../data/models/comment_model.dart';
import '../providers/community_provider.dart';
import '../widgets/dita_loader.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/stories_section.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _selectedCategory = 'ALL';
  final ScrollController _scrollController = ScrollController(); 

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(communityProvider.notifier).loadMore();
    }
  }

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostSheet(),
    ).then((val) {
      if (val == true) setState(() {}); 
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
    // ❌ REMOVED: floatingActionButton to avoid overlap with AI Assistant
    
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
      elevation: 0,
      centerTitle: false, 
      actions: [
        // 🆕 NEW: A "Pill" button in the header instead of a FAB
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: SizedBox(
            height: 36, // Compact height
            child: ElevatedButton.icon(
              onPressed: _showCreatePostSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text(
                "Post", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
              ),
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        // Filter Chips (Same as before)
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
          child: Consumer(
            builder: (context, ref, child) {
              final postsAsync = ref.watch(communityProvider);
              
              return postsAsync.when(
                data: (communityState) {
                  final allPosts = communityState.posts;
                  if (allPosts.isEmpty) {
                    return SingleChildScrollView(
                      child: EmptyStateWidget(
                        svgPath: 'assets/svgs/no_post.svg', 
                        title: "Start the conversation",
                        message: "The feed is empty. Be the first to post!",
                        actionLabel: "Create First Post",
                        onActionPressed: _showCreatePostSheet,
                      ),
                    );
                  }

                  // Filter posts by category
                  final posts = _selectedCategory == 'ALL' 
                    ? allPosts 
                    : allPosts.where((p) => p.category == _selectedCategory).toList();

                  return RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(communityProvider.notifier).refresh();
                    },
                    color: primaryColor,
                    child: _selectedCategory == 'MARKET'
                      // MARKETPLACE MODE
                      ? GridView.builder(
                          padding: const EdgeInsets.all(10),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            return _MarketPostCard(
                              post: posts[index],
                              onPostDeleted: () => ref.read(communityProvider.notifier).refresh(),
                            );
                          },
                        )
                      // STANDARD FEED MODE
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 100), 
                          // +1 for Stories, +1 for Loader if hasMore
                          itemCount: 1 + posts.length + (communityState.hasMore ? 1 : 0),
                          separatorBuilder: (c, i) => i == 0 ? const SizedBox(height: 10) : Divider(height: 1, color: borderColor),
                          itemBuilder: (context, index) {
                            // 1. Stories Section at the top
                            if (index == 0) {
                              return const StoriesSection();
                            }
                            
                            // 2. Loading Indicator at the bottom
                            if (index == posts.length + 1) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            // 3. Post Item
                            final post = posts[index - 1]; // Shift index back by 1
                            return _PostItem(
                              post: post, 
                              primaryDark: primaryColor,
                              onPostDeleted: () => ref.read(communityProvider.notifier).refresh(),
                            );
                          },
                        ),
                  );
                },
                loading: () => const SkeletonList(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  skeleton: PostSkeleton(),
                  itemCount: 3,
                ), 
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load posts',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(communityProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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

// 🆕 NEW COMPONENT: MARKET CARD (Grid Style)
class _MarketPostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onPostDeleted;

  const _MarketPostCard({required this.post, required this.onPostDeleted});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: post.image != null
                ? CachedNetworkImage(
                    imageUrl: post.image!,
                    placeholder: (context, url) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: Center(child: Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey[400])),
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundImage: post.authorAvatar != null ? NetworkImage(post.authorAvatar!) : null,
                      child: post.authorAvatar == null ? const Icon(Icons.person, size: 10) : null,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.authorName, 
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      )
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- STANDARD POST ITEM ---
class _PostItem extends ConsumerStatefulWidget {
  final PostModel post;
  final Color primaryDark;
  final VoidCallback onPostDeleted;

  const _PostItem({
    required this.post, 
    required this.primaryDark,
    required this.onPostDeleted
  });

  @override
  ConsumerState<_PostItem> createState() => _PostItemState();
}

class _PostItemState extends ConsumerState<_PostItem> with SingleTickerProviderStateMixin {
  late bool isLiked;
  late int likeCount;
  
  // 🆕 Animation Controllers for Double Tap
  late AnimationController _heartAnimController;
  late Animation<double> _heartAnimation;
  bool _showHeartOverlay = false;

  @override
 void initState() {
    super.initState();
    isLiked = widget.post.hasLiked;
    likeCount = widget.post.likeCount;
    
    // Note: category and isAnonymous are now in Model
    
    // bool isAnon = widget.post.isAnonymous; 
    // String category = widget.post.category;

    // Fixed: logic was misplaced here before
    
    _heartAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _heartAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _heartAnimController, curve: Curves.elasticOut)
    );

    _heartAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if(mounted) setState(() => _showHeartOverlay = false);
          _heartAnimController.reset();
        });
      }
    });
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
  }

  void _handleLike({bool isDoubleTap = false}) async {
    if (isDoubleTap) {
      setState(() => _showHeartOverlay = true);
      _heartAnimController.forward();
      if (isLiked) return; // Already liked, just show animation
    }

    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    // Use provider to like post
    await ref.read(communityProvider.notifier).likePost(widget.post.id);
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
      await ref.read(communityProvider.notifier).deletePost(widget.post.id);
      widget.onPostDeleted();
    }
  }

  void _editPost() async {
     // Note: Edit currently only supports text updates for simplicity
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPostSheet(
        initialContent: widget.post.content,
        initialCategory: 'GENERAL', // widget.post.category placeholder
        postId: widget.post.id,
      ),
    );

    if (result != null && mounted) {
      widget.onPostDeleted(); // Trigger refresh
    }
  }


  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    bool isAnon = widget.post.isAnonymous; 
    
    Color badgeColor;
    switch (widget.post.category) {
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
                backgroundImage: (widget.post.authorAvatar != null && !isAnon) ? NetworkImage(widget.post.authorAvatar!) : null,
                child: (widget.post.authorAvatar == null || isAnon) 
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
                        Text(widget.post.authorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                        const SizedBox(width: 5),
                        if (widget.post.category != 'GENERAL')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(widget.post.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
                          ),
                      ],
                    ),
                    Text(
                      DateFormat('MMM d').format(widget.post.createdAt),
                      style: TextStyle(color: subTextColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (widget.post.isOwner)
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
              widget.post.content, 
              style: TextStyle(fontSize: 15, height: 1.4, color: textColor),
            ),
          ),
          
          // 🆕 IMAGE WITH DOUBLE TAP & HEART OVERLAY
          if (widget.post.image != null)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                      imageUrl: widget.post.image!,
                      heroTag: 'post_img_${widget.post.id}',
                    ),
                  ),
                );
              },
              onDoubleTap: () => _handleLike(isDoubleTap: true),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: 'post_img_${widget.post.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: widget.post.image!,
                        placeholder: (context, url) => Container(
                          height: 200,
                          width: double.infinity,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                        ), // Removed spinner to avoid jarring layout changes during hero
                        errorWidget: (context, url, error) => const SizedBox.shrink(),
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (_showHeartOverlay)
                    ScaleTransition(
                      scale: _heartAnimation,
                      child: const Icon(Icons.favorite, color: Colors.white, size: 80, shadows: [BoxShadow(blurRadius: 10, color: Colors.black26)]),
                    ),
                ],
              ),
            ),
          
          if (widget.post.image != null) const SizedBox(height: 10),

          // ACTION BAR
          Row(
            children: [
              Semantics(
                label: isLiked ? "Unlike post" : "Like post",
                button: true,
                child: BouncingButton(
                  onTap: _handleLike,
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border_rounded, 
                          key: ValueKey(isLiked),
                          size: 26, 
                          color: isLiked ? Colors.red : textColor
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (likeCount > 0) 
                        Text("$likeCount", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              _IconAction(
                icon: Icons.chat_bubble_outline_rounded, 
                label: "${widget.post.commentCount}",
                color: textColor!,
                onTap: () {
                  showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CommentsSheet(postId: widget.post.id, primaryDark: widget.primaryDark)
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
class CreatePostSheet extends ConsumerStatefulWidget {
  const CreatePostSheet({super.key});

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
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
    
    // Use provider to create post
    final success = await ref.read(communityProvider.notifier).createPost(
      {'content': _contentController.text, 'category': _category},
      _selectedImage
    );


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
class EditPostSheet extends ConsumerStatefulWidget {
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
  ConsumerState<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<EditPostSheet> {
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

    // Use provider to edit post
    final success = await ref.read(communityProvider.notifier).editPost(
      widget.postId,
      {'content': _contentController.text}
    );


    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, {'content': _contentController.text, 'category': _category}); 
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
class CommentsSheet extends ConsumerStatefulWidget {
  final int postId;
  final Color primaryDark;
  const CommentsSheet({super.key, required this.postId, required this.primaryDark});

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _commentController = TextEditingController();

  Future<void> _postComment() async {
    if (_commentController.text.isEmpty) return;
    
    await ref.read(commentsProvider(widget.postId).notifier).postComment(_commentController.text);
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = Theme.of(context).cardColor;
    final inputColor = isDark ? const Color(0xFF0F172A) : Colors.grey[100];
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;

    final commentsAsync = ref.watch(commentsProvider(widget.postId));

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
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return Center(child: Text("No comments yet.", style: TextStyle(color: subTextColor)));
                }
                
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final c = comments[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundImage: c.authorAvatar != null ? NetworkImage(c.authorAvatar!) : null,
                        child: c.authorAvatar == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(c.authorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      subtitle: Text(c.content, style: TextStyle(color: textColor)), 
                      trailing: c.isOwner 
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () async {
                              await ref.read(commentsProvider(widget.postId).notifier).deleteComment(c.id);
                            },
                          )
                        : Text(DateFormat('h:mm a').format(c.createdAt), style: TextStyle(fontSize: 10, color: subTextColor)),
                    );
                  },
                );
              },
              loading: () => const SkeletonList(
                padding: EdgeInsets.symmetric(vertical: 8),
                skeleton: CommentSkeleton(),
                itemCount: 5,
              ),
              error: (error, stack) => Center(
                child: Text("Failed to load comments", style: TextStyle(color: subTextColor)),
              ),
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