import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart';
import '../providers/stories_provider.dart';
import '../services/api_service.dart';

class StoriesSection extends ConsumerWidget {
  const StoriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(storiesProvider);

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: stories.length + 1, // +1 for "Add Story"
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddStory(context, ref);
          }
          final story = stories[index - 1];
          return _buildStoryCircle(context, ref, story, stories);
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
                title: const Text("Video (max 15s)"),
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
          file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 15));
        }

        if (file != null) {
          // Verify duration if it's a video (Extra safety)
          if (type == "video") {
             // In a real app, you'd use a package like video_player to check duration before upload
             // For now we rely on pickVideo's maxDuration
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Uploading story...")),
          );
          
          final success = await ref.read(storiesProvider.notifier).addStory(
            File(file.path), 
            null,
          );

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Story uploaded successfully!")),
            );
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

  Widget _buildStoryCircle(BuildContext context, WidgetRef ref, StoryModel story, List<StoryModel> stories) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StoryViewer(stories: stories, initialIndex: stories.indexOf(story)))
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: story.isViewed ? Colors.grey : Colors.blue,
                  width: 2,
                ),
                gradient: !story.isViewed ? const LinearGradient(
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
                  backgroundImage: CachedNetworkImageProvider(_getUserAvatar(story)),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              story.username.split(' ')[0], 
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            )
          ],
        ),
      ),
    );
  }

  // --- MOCK USER AVATAR (Returns image URL as fallback) ---
  String _getUserAvatar(StoryModel story) {
    if (story.userAvatar != null && story.userAvatar!.isNotEmpty) return story.userAvatar!;
    if (story.imageUrl != null && story.imageUrl!.isNotEmpty) return story.imageUrl!;
    return "https://via.placeholder.com/150"; // Fallback placeholder
  }
}

class StoryViewer extends ConsumerStatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;
  const StoryViewer({super.key, required this.stories, this.initialIndex = 0});

  @override
  ConsumerState<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends ConsumerState<StoryViewer> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isVideoInitialized = false;
  late int _currentIndex;
  final TextEditingController _commentController = TextEditingController(); // Controller for comment input

  // Use the ID to find the latest version of the story from the provider
  StoryModel get _currentStory {
    final liveStories = ref.watch(storiesProvider);
    // Fallback to widget.stories if not found (e.g. filtered list)
    if (_currentIndex >= widget.stories.length) return widget.stories.last;
    
    final staticStory = widget.stories[_currentIndex];
    return liveStories.firstWhere(
      (s) => s.id == staticStory.id, 
      orElse: () => staticStory
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    
    _animController.addStatusListener(_onAnimationStatus);

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
    ref.read(storiesProvider.notifier).markAsViewed(_currentStory.id);
  }

  Future<void> _initMedia() async {
    _animController.stop();
    _animController.reset();
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;

    // 1. VIDEO INITIALIZATION
    if (_currentStory.videoUrl != null && _currentStory.videoUrl!.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(_currentStory.videoUrl!))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _isVideoInitialized = true;
            // Set animation duration to video duration (max 15s)
            final duration = _videoController!.value.duration;
            _animController.duration = duration.inSeconds > 15 
                ? const Duration(seconds: 15) 
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

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _initMedia();
      _markCurrentAsViewed();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _initMedia();
      _markCurrentAsViewed();
    } else {
      // Restart current story if it's the first one
      _animController.reset();
      _animController.forward();
    }
  }

  @override
    _animController.dispose();
    _videoController?.dispose();
    _audioPlayer.dispose();
    _commentController.dispose(); // Dispose controller
    super.dispose();
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
                children: widget.stories.asMap().entries.map((entry) {
                   final idx = entry.key;
                   return Expanded(
                     child: Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 2),
                       child: AnimatedBuilder(
                         animation: _animController,
                         builder: (context, child) {
                           double value = 0;
                           if (idx < _currentIndex) value = 1;
                           else if (idx == _currentIndex) value = _animController.value;
                           
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
                                ref.read(storiesProvider.notifier).addComment(_currentStory.id, text);
                                _commentController.clear(); // Clear field
                                FocusScope.of(context).unfocus(); // Close keyboard
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Comment added!")),
                                );
                             }
                          },
                        ),
                      ),
                      onSubmitted: (text) {
                        if (text.isNotEmpty) {
                          ref.read(storiesProvider.notifier).addComment(_currentStory.id, text);
                          _commentController.clear();
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

class StoryCommentsSheet extends ConsumerWidget {
  final String storyId;
  const StoryCommentsSheet({super.key, required this.storyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We would ideally have a separate provider for comments, but we can reuse storiesProvider
    // OR create a simple future builder for now to fetch them directly
    
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
              child: FutureBuilder<dynamic>(
                future: ApiService.get('stories/$storyId/comments/'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                  }
                  if (!snapshot.hasData || (snapshot.data is List && (snapshot.data as List).isEmpty)) {
                    return const Center(child: Text("No comments yet. Be the first!", style: TextStyle(color: Colors.grey)));
                  }
                  
                  final comments = snapshot.data as List<dynamic>;
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
              ),
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
