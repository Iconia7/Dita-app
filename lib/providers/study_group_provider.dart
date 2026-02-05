import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../data/models/study_group_model.dart';
import '../providers/auth_provider.dart';
import '../utils/app_logger.dart';

// ========== Study Groups List Provider ==========

final studyGroupsProvider = StateNotifierProvider<StudyGroupsNotifier, AsyncValue<List<StudyGroupModel>>>((ref) {
  return StudyGroupsNotifier();
});

class StudyGroupsNotifier extends StateNotifier<AsyncValue<List<StudyGroupModel>>> {
  StudyGroupsNotifier() : super(const AsyncValue.loading()) {
    loadGroups();
  }

  Future<void> loadGroups() async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiService.getStudyGroups();
      final groups = data.map((json) => StudyGroupModel.fromJson(json)).toList();
      state = AsyncValue.data(groups);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> joinGroup(int groupId) async {
    final success = await ApiService.joinStudyGroup(groupId);
    if (success) {
      await loadGroups();
    }
  }

  Future<void> leaveGroup(int groupId) async {
    final success = await ApiService.leaveStudyGroup(groupId);
    if (success) {
      await loadGroups();
    }
  }

  Future<void> createGroup(String name, String courseCode, String description) async {
    final result = await ApiService.createStudyGroup(name, courseCode, description);
    if (result != null) {
      await loadGroups();
    }
  }

  Future<void> deleteGroup(int groupId) async {
    final success = await ApiService.deleteStudyGroup(groupId);
    if (success) {
      await loadGroups();
    }
  }
}

// ========== Chat Provider (One per Group) ==========

enum ConnectionStatus { disconnected, connecting, connected }

final chatMessagesProvider = StateNotifierProvider.family<ChatNotifier, AsyncValue<List<GroupMessageModel>>, int>((ref, groupId) {
  return ChatNotifier(groupId, ref);
});

final chatConnectionStatusProvider = StateProvider.family<ConnectionStatus, int>((ref, groupId) {
  return ConnectionStatus.disconnected;
});

class ChatNotifier extends StateNotifier<AsyncValue<List<GroupMessageModel>>> {
  final int groupId;
  final Ref ref;
  WebSocketChannel? _channel;
  final List<Map<String, String>> _messageQueue = [];
  bool _isDisposed = false;

  ChatNotifier(this.groupId, this.ref) : super(const AsyncValue.loading()) {
    _initChat();
  }

  Future<void> _initChat() async {
    // 1. Load history via REST
    try {
      final historyData = await ApiService.getGroupMessages(groupId);
      final history = historyData.map((json) => GroupMessageModel.fromJson(json)).toList();
      if (!_isDisposed) {
        state = AsyncValue.data(history);
      }
    } catch (e, stackTrace) {
      if (!_isDisposed) {
        state = AsyncValue.error(e, stackTrace);
      }
    }

    // 2. Connect WebSockets
    _connectWebSocket();
  }

  void _connectWebSocket() {
    if (_isDisposed) return;
    
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    ref.read(chatConnectionStatusProvider(groupId).notifier).state = ConnectionStatus.connecting;

    // 🛑 FORCE_FIX: ABSOLUTE HARDCODED URL WITH PORT
    final url = 'wss://api.dita.co.ke:443/ws/chat/$groupId/';
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      _channel!.stream.listen((event) {
        if (_isDisposed) return;
        
        try {
          final data = json.decode(event);
          final newMessage = GroupMessageModel(
            id: DateTime.now().millisecondsSinceEpoch, // Local ID for display
            username: data['username'],
            content: data['message'],
            timestamp: DateTime.now(),
          );

          state.whenData((currentMessages) {
            if (!_isDisposed) {
              state = AsyncValue.data([...currentMessages, newMessage]);
            }
          });

          // Mark as connected on first successful message
          if (ref.read(chatConnectionStatusProvider(groupId)) != ConnectionStatus.connected) {
            ref.read(chatConnectionStatusProvider(groupId).notifier).state = ConnectionStatus.connected;
          }
        } catch (e) {
          AppLogger.error('Error parsing WebSocket message', error: e);
        }
      }, onError: (err) {
        if (_isDisposed) return;
        AppLogger.error('WebSocket Error', error: err);
        ref.read(chatConnectionStatusProvider(groupId).notifier).state = ConnectionStatus.disconnected;
        _scheduleReconnect();
      }, onDone: () {
        if (_isDisposed) return;
        AppLogger.warning('WebSocket Closed. Retrying in 5s...');
        ref.read(chatConnectionStatusProvider(groupId).notifier).state = ConnectionStatus.disconnected;
        _scheduleReconnect();
      });

      // Mark connected immediately (optimistic)
      ref.read(chatConnectionStatusProvider(groupId).notifier).state = ConnectionStatus.connected;
      
      // Send queued messages
      _flushMessageQueue();
      
    } catch (e) {
      if (_isDisposed) return;
      AppLogger.error('WebSocket Connection Failed', error: e);
      ref.read(chatConnectionStatusProvider(groupId).notifier).state = ConnectionStatus.disconnected;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isDisposed) {
        _connectWebSocket();
      }
    });
  }

  void sendMessage(String text) {
    if (_isDisposed || text.trim().isEmpty) return;
    
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final data = {
      'message': text,
      'username': user.username,
    };

    // If connected, send immediately
    if (_channel != null && ref.read(chatConnectionStatusProvider(groupId)) == ConnectionStatus.connected) {
      try {
        _channel!.sink.add(json.encode(data));
      } catch (e) {
        AppLogger.error('Error sending message', error: e);
        _messageQueue.add(data);
        _scheduleReconnect();
      }
    } else {
      // Queue message for later
      _messageQueue.add(data);
      AppLogger.info('Message queued. Connection status: ${ref.read(chatConnectionStatusProvider(groupId))}');
      
      // Try to reconnect if disconnected
      if (ref.read(chatConnectionStatusProvider(groupId)) == ConnectionStatus.disconnected) {
        _connectWebSocket();
      }
    }
  }

  void _flushMessageQueue() {
    if (_messageQueue.isEmpty) return;
    
    AppLogger.info('Flushing ${_messageQueue.length} queued messages');
    for (final message in _messageQueue) {
      try {
        _channel?.sink.add(json.encode(message));
      } catch (e) {
        AppLogger.error('Error flushing queued message', error: e);
      }
    }
    _messageQueue.clear();
  }

  void retryConnection() {
    if (_isDisposed) return;
    AppLogger.info('Manual retry connection initiated');
    _channel?.sink.close();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _channel?.sink.close();
    super.dispose();
  }
}
