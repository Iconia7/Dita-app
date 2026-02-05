import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart';
import '../providers/stories_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class StoriesSection extends ConsumerWidget {
  const StoriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyGroups = ref.watch(storiesProvider);

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: storyGroups.length + 1, // +1 for "Add Story"
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddStory(context, ref);
          }
          final group = storyGroups[index - 1];
          return _buildGroupCircle(context, ref, group, storyGroups);
        },
      ),
    );
  }

  Widget _buildAddStory(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final ImagePicker picker = ImagePicker();
        
        // Show selection between Image and Video
        final type = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text("Photo"),
                onTap: () => Navigator.pop(context, "image"),
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text("Video (max 30s)"),
                onTap: () => Navigator.pop(context, "video"),
              ),
            ],
          ),
        );

        if (type == null) return;

        XFile? file;
        if (type == "image") {
          file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
        } else {
          file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
        }

        if (file != null && context.mounted) {
          // Show upload progress dialog
          _showUploadProgressDialog(context, file.path.split('/').last);
          
          try {
            final success = await ref.read(storiesProvider.notifier).addStory(
              File(file.path), 
              null,
            );

            // Close progress dialog
            if (context.mounted) Navigator.pop(context);

            if (context.mounted) {
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text("Story uploaded successfully!"),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(child: Text("Upload failed. Please try again.")),
                      ],
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          } catch (e) {
            // Close progress dialog if still open
            if (context.mounted) {
              Navigator.pop(context);
              
              // Determine error type and show specific message
              String errorMessage = "Upload failed: ";
              if (e.toString().contains('Network') || e.toString().contains('Socket')) {
                errorMessage += "No internet connection";
              } else if (e.toString().contains('Timeout')) {
                errorMessage += "Connection timed out";
              } else if (e.toString().contains('File too large')) {
                errorMessage += "File is too large";
              } else {
                errorMessage += "Please try again";
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text(errorMessage)),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'RETRY',
                    textColor: Colors.white,
                    onPressed: () {
                      // Could implement retry logic here
                    },
                  ),
                ),
              );
            }
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: const AssetImage('assets/images/user_placeholder.png'), // Replace with actual user avatar
                  backgroundColor: Colors.grey[200],
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.add_circle, color: Colors.blue, size: 20),
                  ),
                )
              ],
            ),
            const SizedBox(height: 5),
            const Text("Your Story", style: TextStyle(fontSize: 12))
          ],
        ),
      ),
    );
  }

  void _showUploadProgressDialog(BuildContext context, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF1E1E1E) 
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  "Uploading Story...",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  fileName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Please wait",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCircle(BuildContext context, WidgetRef ref, UserStoryGroup group, List<UserStoryGroup> allGroups) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _StoryViewer(
            initialGroupIndex: allGroups.indexOf(group),
            storyGroups: allGroups,
          ))
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: group.hasUnviewed ? Colors.blue : Colors.grey,
                      width: 2,
                    ),
                    gradient: group.hasUnviewed ? const LinearGradient(
                      colors: [Colors.purple, Colors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ) : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: group.userAvatar != null
                          ? CachedNetworkImageProvider(group.userAvatar!)
                          : const CachedNetworkImageProvider('https://via.placeholder.com/150'),
                    ),
                  ),
                ),
                // Story count badge
                if (group.storyCount > 1)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '${group.storyCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              group.username.split(' ')[0], 
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            )
          ],
        ),
      ),
    );
  }

}

class _StoryViewer extends ConsumerStatefulWidget {
  final List<UserStoryGroup> storyGroups;
  final int initialGroupIndex;
  const _StoryViewer({required this.storyGroups, this.initialGroupIndex = 0});

  @override
  ConsumerState<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends ConsumerState<_StoryViewer> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isVideoInitialized = false;
  late int _currentGroupIndex;
  late int _currentStoryIndexInGroup;
  final TextEditingController _commentController = TextEditingController(); // Controller for comment input
  final FocusNode _commentFocusNode = FocusNode();

  // Reactive getter for build()
  StoryModel get _currentStory => _getStory(watch: true);

  // Non-reactive helper for logic (initState, handlers)
  StoryModel _getStory({required bool watch}) {
    final liveStoryGroups = watch ? ref.watch(storiesProvider) : ref.read(storiesProvider);
    
    // Get current group and story
    if (_currentGroupIndex >= widget.storyGroups.length) {
      final lastGroup = widget.storyGroups.last;
      return lastGroup.stories.last;
    }
    
    final currentGroup = widget.storyGroups[_currentGroupIndex];
    if (_currentStoryIndexInGroup >= currentGroup.stories.length) {
      return currentGroup.stories.last;
    }
    
    final staticStory = currentGroup.stories[_currentStoryIndexInGroup];
    
    // Find in live data
    for (var group in liveStoryGroups) {
      final found = group.stories.cast<StoryModel?>().firstWhere(
        (s) => s?.id == staticStory.id,
        orElse: () => null,
      );
      if (found != null) return found;
    }
    
    return staticStory;
  }

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;
    _currentStoryIndexInGroup = 0;
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    
    _animController.addStatusListener(_onAnimationStatus);

    // Pause when typing comment
    _commentFocusNode.addListener(() {
      if (_commentFocusNode.hasFocus) {
        _animController.stop();
        _videoController?.pause();
      } else {
        _animController.forward();
        _videoController?.play();
      }
    });

    _initMedia();

    // Mark as viewed on backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markCurrentAsViewed();
    });
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _nextStory();
    }
  }

  void _markCurrentAsViewed() {
    final story = _getStory(watch: false);
    ref.read(storiesProvider.notifier).markAsViewed(story.id);
  }

  Future<void> _initMedia() async {
    _animController.stop();
    _animController.reset();
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;

    final story = _getStory(watch: false);

    // 1. VIDEO INITIALIZATION
    if (story.videoUrl != null && story.videoUrl!.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(story.videoUrl!))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _isVideoInitialized = true;
            // Set animation duration to video duration (max 30s)
            final duration = _videoController!.value.duration;
            _animController.duration = duration.inSeconds > 30 
                ? const Duration(seconds: 30) 
                : duration;
            _videoController!.play();
            _animController.forward();
          });
        });
    } else {
      // IMAGE INITIALIZATION (Default 5s)
      _animController.duration = const Duration(seconds: 5);
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _videoController?.dispose();
    _audioPlayer.dispose();
    _commentController.dispose(); // Dispose controller
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _nextStory() {
    final currentGroup = widget.storyGroups[_currentGroupIndex];
    
    // Check if there are more stories in current group
    if (_currentStoryIndexInGroup < currentGroup.stories.length - 1) {
      // Move to next story in same group
      setState(() => _currentStoryIndexInGroup++);
      _initMedia();
      _markCurrentAsViewed();
    } else if (_currentGroupIndex < widget.storyGroups.length - 1) {
      // Move to next group (next user's stories)
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndexInGroup = 0;
      });
      _initMedia();
      _markCurrentAsViewed();
    } else {
      // End of all stories
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_currentStoryIndexInGroup > 0) {
      // Go to previous story in same group
      setState(() => _currentStoryIndexInGroup--);
      _initMedia();
    } else if (_currentGroupIndex > 0) {
      // Go to previous group's last story
      setState(() {
        _currentGroupIndex--;
        _currentStoryIndexInGroup = widget.storyGroups[_currentGroupIndex].stories.length - 1;
      });
      _initMedia();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch stories to trigger rebuild on like/comment updates
    ref.watch(storiesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // MEDIA DISPLAY (Image or Video)
            Center(
               child: _currentStory.videoUrl != null && _isVideoInitialized
                   ? AspectRatio(
                       aspectRatio: _videoController!.value.aspectRatio,
                       child: VideoPlayer(_videoController!),
                     )
                   : (_currentStory.imageUrl != null 
                       ? CachedNetworkImage(
                           imageUrl: _currentStory.imageUrl!,
                           fit: BoxFit.contain,
                           placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                         )
                       : const Icon(Icons.broken_image, color: Colors.white, size: 50)),
            ),
          
            // Progress Bar (Multi-notch)
            Positioned(
              top: 50,
              left: 10, right: 10,
              child: Row(
                children: widget.storyGroups[_currentGroupIndex].stories.asMap().entries.map((entry) {
                   final idx = entry.key;
                   return Expanded(
                     child: Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 2),
                       child: AnimatedBuilder(
                         animation: _animController,
                         builder: (context, child) {
                           double value = 0;
                           if (idx < _currentStoryIndexInGroup) value = 1;
                           else if (idx == _currentStoryIndexInGroup) value = _animController.value;
                           
                           return LinearProgressIndicator(
                             value: value,
                             backgroundColor: Colors.white30,
                             valueColor: const AlwaysStoppedAnimation(Colors.white),
                             minHeight: 2,
                           );
                         },
                       ),
                     ),
                   );
                }).toList(),
              ),
            ),

          // User Info
            Positioned(
              top: 70,
              left: 20,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: CachedNetworkImageProvider(
                      _currentStory.userAvatar ?? (_currentStory.imageUrl ?? "")
                    ), 
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _currentStory.username, 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _getTimeAgo(_currentStory.createdAt),
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  )
                ],
              ),
            ),

            // Caption
            if (_currentStory.caption != null)
              Positioned(
                bottom: 100, // Moved up to make room for comments
                left: 20, right: 20,
                child: Text(
                   _currentStory.caption!,
                   style: const TextStyle(color: Colors.white, fontSize: 18),
                   textAlign: TextAlign.center,
                ),
              ),

          // Close Button
          Positioned(
            top: 60,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Bottom Interactions (Likes & Comments)
          Positioned(
            bottom: 30,
            left: 20, right: 20,
            child: Row(
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        _currentStory.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _currentStory.isLiked ? Colors.red : Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        ref.read(storiesProvider.notifier).toggleLike(_currentStory.id);
                      },
                    ),
                    Text("${_currentStory.likes}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 20),
                // comment icon
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _commentController, // Attach controller
                      focusNode: _commentFocusNode, // Attach FocusNode
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Send a message...",
                        hintStyle: const TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        suffixIcon: IconButton( // Send button
                          icon: const Icon(Icons.send, color: Colors.blueAccent),
                          onPressed: () {
                             final text = _commentController.text.trim();
                             if (text.isNotEmpty) {
                                 final user = ref.read(currentUserProvider);
                                
                                if (user != null) {
                                  // Optimistic Update via new provider
                                  ref.read(storyCommentsProvider(_currentStory.id).notifier)
                                     .addLocalComment(text, user.username, user.avatar);
                                } else {
                                  // Fallback
                                  ref.read(storiesProvider.notifier).addComment(_currentStory.id, text);
                                }

                                _commentController.clear(); // Clear field
                                _commentFocusNode.unfocus(); // Close keyboard and resume story
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Comment added!")),
                                );
                             }
                          },
                        ),
                      ),
                      onSubmitted: (text) {
                        if (text.isNotEmpty) {
                           final user = ref.read(currentUserProvider);
                           
                           if (user != null) {
                             ref.read(storyCommentsProvider(_currentStory.id).notifier)
                                .addLocalComment(text, user.username, user.avatar);
                           } else {
                             ref.read(storiesProvider.notifier).addComment(_currentStory.id, text);
                           }
                           
                          _commentController.clear();
                          _commentFocusNode.unfocus(); // Close keyboard and resume story
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Comment added!")),
                          );
                        }
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  onPressed: () => _showCommentsBottomSheet(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  void _showCommentsBottomSheet() {
    _animController.stop();
    _videoController?.pause();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StoryCommentsSheet(storyId: _currentStory.id),
    ).then((_) {
      // Resume when sheet closes
      _animController.forward(from: _animController.value);
      _videoController?.play();
    });
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m";
    return "now";
  }
}

// --- 🆕 COMMENTS PROVIDER (Local State for Immediate Updates) ---
final storyCommentsProvider = StateNotifierProvider.family.autoDispose<StoryCommentsNotifier, AsyncValue<List<dynamic>>, String>((ref, storyId) {
  return StoryCommentsNotifier(storyId);
});

class StoryCommentsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final String storyId;
  
  StoryCommentsNotifier(this.storyId) : super(const AsyncValue.loading()) {
    fetchComments();
  }

  Future<void> fetchComments() async {
    try {
      // Use the correct endpoint: story-comments with query parameter
      final finalData = await ApiService.get('story-comments/?story_id=$storyId');
      if (!mounted) return;
      if (finalData is List) {
        state = AsyncValue.data(finalData);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> addLocalComment(String text, String username, String? avatar) async {
    // 1. Optimistic Update
    final newComment = {
      'id': DateTime.now().millisecondsSinceEpoch, // Temp ID
      'username': username,
      'avatar': avatar,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    };

    state.whenData((current) {
      state = AsyncValue.data([newComment, ...current]);
    });

    // 2. Actual API Call
    try {
      final result = await ApiService.post('stories/$storyId/comment/', {'text': text});
      if (result == false) { // post returns bool
        // Revert if failed (optional, simplified here)
        fetchComments(); 
      }
    } catch (e) {
      // Revert or show error
      fetchComments(); 
    }
  }
}


class StoryCommentsSheet extends ConsumerWidget {
  final String storyId;
  const StoryCommentsSheet({super.key, required this.storyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use int for the provider family to match the provider definition above if we didn't change it.
    // Wait, I am changing the provider definition below to String to avoid the int parsing issues.
    // But I can't change the definition in the same tool call easily without a large replace.
    // Let's stick to int for the family KEY if the provider definition uses int, but the notifier logic uses string.
    // Actually, I will replace the provider definition too.
    
    // Changing the provider family type in the replace block:
    
    // For now, let's keep the provider family as `int` in this specific block if I can't change the definition line (543).
    // StartLine 543 is included.
    
    // Wait, the id passed from UI is String. If I parse to int and it fails (UUID), it becomes 0.
    // So I MUST change the provider family type to String.
    
    final commentsAsync = ref.watch(storyCommentsProvider(storyId));
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.95), // Dark premium background
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
          ]
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 40, height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(5)),
            ),
            const Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            Expanded(
              child: commentsAsync.when(
                data: (comments) {
                   if (comments.isEmpty) {
                    return const Center(child: Text("No comments yet. Be the first!", style: TextStyle(color: Colors.grey)));
                   }
                   return ListView.separated(
                    controller: controller,
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: comment['avatar'] != null 
                              ? CachedNetworkImageProvider(comment['avatar'])
                              : null,
                          backgroundColor: Colors.grey[800],
                          child: comment['avatar'] == null ? const Icon(Icons.person, color: Colors.white70) : null,
                        ),
                        title: Text(comment['username'] ?? "Anonymous", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: Text(comment['text'] ?? "", style: const TextStyle(color: Colors.white70)),
                        trailing: Text(
                          _getTimeAgoFromStr(comment['created_at']),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                error: (err, _) => Center(child: Text("Failed to load comments", style: TextStyle(color: Colors.red))),
              )
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgoFromStr(String? dateStr) {
    if (dateStr == null) return "";
    final date = DateTime.tryParse(dateStr);
    if (date == null) return "";
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m";
    return "now";
  }
}
