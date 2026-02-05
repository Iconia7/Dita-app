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
    final connectionStatus = ref.watch(chatConnectionStatusProvider(widget.group.id));
    final currentUser = ref.watch(currentUserProvider);
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(chatMessagesProvider(widget.group.id), (previous, next) {
      if (previous?.value?.length != next.value?.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.9), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Row(
              children: [
                Text(widget.group.courseCode, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(width: 8),
                // Connection status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connectionStatus == ConnectionStatus.connected
                        ? Colors.green
                        : connectionStatus == ConnectionStatus.connecting
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showGroupInfo(context),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          image: isDark ? null : const DecorationImage(
            image: AssetImage('assets/images/chat_bg_pattern.png'), // Optional pattern
            opacity: 0.05,
            repeat: ImageRepeat.repeat,
          ),
        ),
        child: Column(
          children: [
            // Connection status banner
            if (connectionStatus != ConnectionStatus.connected)
              Container(
                margin: const EdgeInsets.only(top: 90),
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
                  padding: EdgeInsets.only(
                    top: connectionStatus != ConnectionStatus.connected ? 20 : 100, 
                    left: 15, 
                    right: 15, 
                    bottom: 20
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.username == currentUser?.username;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          gradient: isMe ? LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.8)]) : null,
                          color: isMe ? null : (isDark ? const Color(0xFF1F2937) : Colors.white),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                          ),
                          boxShadow: [
                             if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(msg.username, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: primaryColor)),
                              ),
                            Text(msg.content, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 15)),
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
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, bool isDark) {
    final connectionStatus = ref.watch(chatConnectionStatusProvider(widget.group.id));
    final isConnected = connectionStatus == ConnectionStatus.connected;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  enabled: isConnected,
                  decoration: InputDecoration(
                    hintText: isConnected ? "Type a message..." : "Connecting...",
                    hintStyle: TextStyle(color: isConnected ? Colors.grey : Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: isConnected ? (_) => _sendMessage() : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: isConnected ? _sendMessage : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isConnected
                      ? LinearGradient(colors: [Theme.of(context).primaryColor, Colors.indigoAccent])
                      : LinearGradient(colors: [Colors.grey[400]!, Colors.grey[500]!]),
                  shape: BoxShape.circle,
                  boxShadow: isConnected
                      ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Icon(
                  Icons.send_rounded, 
                  color: isConnected ? Colors.white : Colors.grey[300], 
                  size: 20
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      ref.read(chatMessagesProvider(widget.group.id).notifier).sendMessage(text);
      _messageController.clear();
    }
  }

  void _showGroupInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
}
