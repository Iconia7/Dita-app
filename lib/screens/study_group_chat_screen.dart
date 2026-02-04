import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    final currentUser = ref.watch(currentUserProvider);
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Scroll to bottom when new messages arrive
    ref.listen(chatMessagesProvider(widget.group.id), (previous, next) {
      if (previous?.value?.length != next.value?.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(widget.group.courseCode, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
               // Show group info / members
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) => ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(15),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.username == currentUser?.username;
                  
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? primaryColor : (isDark ? const Color(0xFF1E293B) : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(15).copyWith(
                          bottomRight: isMe ? Radius.zero : const Radius.circular(15),
                          bottomLeft: isMe ? const Radius.circular(15) : Radius.zero,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(msg.username, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor)),
                          Text(msg.content, style: TextStyle(color: isMe || isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('HH:mm').format(msg.timestamp),
                            style: TextStyle(fontSize: 10, color: isMe || isDark ? Colors.white70 : Colors.black54),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) {
                      ref.read(chatMessagesProvider(widget.group.id).notifier).sendMessage(_messageController.text);
                      _messageController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFD700),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: () {
                      ref.read(chatMessagesProvider(widget.group.id).notifier).sendMessage(_messageController.text);
                      _messageController.clear();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
