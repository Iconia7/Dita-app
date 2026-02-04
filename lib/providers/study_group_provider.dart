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
}

// ========== Chat Provider (One per Group) ==========

final chatMessagesProvider = StateNotifierProvider.family<ChatNotifier, AsyncValue<List<GroupMessageModel>>, int>((ref, groupId) {
  return ChatNotifier(groupId, ref);
});

class ChatNotifier extends StateNotifier<AsyncValue<List<GroupMessageModel>>> {
  final int groupId;
  final Ref ref;
  WebSocketChannel? _channel;

  ChatNotifier(this.groupId, this.ref) : super(const AsyncValue.loading()) {
    _initChat();
  }

  Future<void> _initChat() async {
    // 1. Load history via REST
    try {
      final historyData = await ApiService.getGroupMessages(groupId);
      final history = historyData.map((json) => GroupMessageModel.fromJson(json)).toList();
      state = AsyncValue.data(history);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }

    // 2. Connect WebSockets
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // 🛑 FORCE_FIX: ABSOLUTE HARDCODED URL WITH PORT
    final url = 'wss://api.dita.co.ke:443/ws/chat/$groupId/';
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      _channel!.stream.listen((event) {
        final data = json.decode(event);
        final newMessage = GroupMessageModel(
          id: DateTime.now().millisecondsSinceEpoch, // Local ID for display
          username: data['username'],
          content: data['message'],
          timestamp: DateTime.now(),
        );

        state.whenData((currentMessages) {
          state = AsyncValue.data([...currentMessages, newMessage]);
        });
      }, onError: (err) {
        AppLogger.error('WebSocket Error', error: err);
      }, onDone: () {
        AppLogger.warning('WebSocket Closed. Retrying in 5s...');
        Future.delayed(const Duration(seconds: 5), () => _connectWebSocket());
      });
    } catch (e) {
      AppLogger.error('WebSocket Connection Failed', error: e);
    }
  }

  void sendMessage(String text) {
    if (_channel == null || text.trim().isEmpty) return;
    
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final data = {
      'message': text,
      'username': user.username,
    };

    _channel!.sink.add(json.encode(data));
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}
