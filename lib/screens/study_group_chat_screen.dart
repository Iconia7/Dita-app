import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/study_group_provider.dart';
import '../data/models/study_group_model.dart';
import '../providers/auth_provider.dart';

class StudyGroupChatScreen extends ConsumerStatefulWidget {
  final StudyGroupModel group;
  const StudyGroupChatScreen({super.key, required this.group});

  @override
  ConsumerState<StudyGroupChatScreen> createState() => _StudyGroupChatScreenState();
}

class _StudyGroupChatScreenState extends ConsumerState<StudyGroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false; // Guard  for duplicate messages

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.group.id));
    final connectionStatus = ref.watch(chatConnectionStatusProvider(widget.group.id));
    final currentUser = ref.watch(currentUserProvider);
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Match AI assistant color scheme
    final userBubbleColor = isDark ? primaryColor : const Color(0xFF003366);
    final botBubbleColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inputFillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F9);

    ref.listen(chatMessagesProvider(widget.group.id), (previous, next) {
      if (previous?.value?.length != next.value?.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          widget.group.name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connectionStatus == ConnectionStatus.connected
                      ? Colors.green
                      : connectionStatus == ConnectionStatus.connecting
                          ? Colors.orange
                          : Colors.red,
                  boxShadow: [
                    BoxShadow(
                      color: (connectionStatus == ConnectionStatus.connected
                              ? Colors.green
                              : Colors.orange)
                          .withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareGroup(context),
            tooltip: 'Share Group',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showGroupInfo(context),
          )
        ],
      ),
      body: Column(
          children: [
            // Connection status banner
            if (connectionStatus != ConnectionStatus.connected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: connectionStatus == ConnectionStatus.connecting
                      ? Colors.orange.withOpacity(0.9)
                      : Colors.red.withOpacity(0.9),
                ),
                child: Row(
                  children: [
                    if (connectionStatus == ConnectionStatus.connecting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        connectionStatus == ConnectionStatus.connecting
                            ? 'Connecting to chat...'
                            : 'Disconnected from chat',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (connectionStatus == ConnectionStatus.disconnected)
                      TextButton(
                        onPressed: () {
                          ref.read(chatMessagesProvider(widget.group.id).notifier).retryConnection();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: messagesAsync.when(
                data: (messages) => ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(15, 15, 15, 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.username == currentUser?.username;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                        decoration: BoxDecoration(
                          color: isMe ? userBubbleColor : botBubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(15),
                            topRight: const Radius.circular(15),
                            bottomLeft: isMe ? const Radius.circular(15) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(15),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  msg.username,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: primaryColor),
                                ),
                              ),
                            Text(
                              msg.content,
                              style: TextStyle(
                                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                DateFormat('HH:mm').format(msg.timestamp),
                                style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text("Error connecting to chat: $err")),
              ),
            ),
            _buildInputArea(context, isDark),
          ],
        ),
    );
  }

  Widget _buildInputArea(BuildContext context, bool isDark) {
    final connectionStatus = ref.watch(chatConnectionStatusProvider(widget.group.id));
    final isConnected = connectionStatus == ConnectionStatus.connected;
    final inputFillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F9);
    
    return Container(
      padding: const EdgeInsets.all(15),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              enabled: isConnected,
              decoration: InputDecoration(
                hintText: isConnected ? "Type a message..." : "Connecting...",
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: isConnected ? (_) => _sendMessage() : null,
            ),
          ),
          const SizedBox(width: 5),
          CircleAvatar(
            backgroundColor: isConnected ? const Color(0xFFFFD700) : Colors.grey,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black),
              onPressed: isConnected ? _sendMessage : null,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return; // Guard: Don't send empty messages
    
    // Guard: Prevent duplicate sends while sending
    if (_isSending) return;
    
    setState(() => _isSending = true);
    
    ref.read(chatMessagesProvider(widget.group.id).notifier).sendMessage(text);
    _messageController.clear();
    
    // Reset flag after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isSending = false);
    });
  }

  void _showGroupInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(Icons.group, size: 30, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.group.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(widget.group.courseCode, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text("About", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.group.description.isNotEmpty ? widget.group.description : "No description available.", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            _infoRow(Icons.people, "${widget.group.memberCount} Members"),
            const SizedBox(height: 12),
            _infoRow(Icons.calendar_today, "Created ${DateFormat.yMMMd().format(widget.group.createdAt)}"),
            const SizedBox(height: 32),
            
            // Action Buttons
            if (widget.group.creatorId != 0 && widget.group.creatorId == ref.read(currentUserProvider)?.id)
              // Delete Button (Creator only)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _deleteGroup(context),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text("Delete Group"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else
              // Leave Button (Members)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _leaveGroup(context),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text("Leave Group"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  Future<void> _deleteGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Group"),
        content: const Text("Are you sure you want to delete this group? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Close the bottom sheet first
      Navigator.pop(context);
      
      // Call provider to delete
      await ref.read(studyGroupsProvider.notifier).deleteGroup(widget.group.id);
      
      if (mounted) {
        // Pop the chat screen and go back to the list
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Group deleted successfully")),
        );
      }
    }
  }

  Future<void> _leaveGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Group"),
        content: const Text("Are you sure you want to leave this group?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Leave"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Close the bottom sheet first
      Navigator.pop(context);

      // Call provider to leave
      await ref.read(studyGroupsProvider.notifier).leaveGroup(widget.group.id);

      if (mounted) {
        // Pop the chat screen and go back to the list
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You have left the group")),
        );
      }
    }
  }

  void _shareGroup(BuildContext context) {
    final shareText = '''
Join my DITA study group! 📚

Group: ${widget.group.name}
Course: ${widget.group.courseCode}
${widget.group.description.isNotEmpty ? '\n${widget.group.description}' : ''}

To join, search for "${widget.group.name}" in the DITA app's Study Groups section.
    '''.trim();

    Share.share(
      shareText,
      subject: 'Join ${widget.group.name} on DITA',
    );
  }
}
