import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/ai_provider.dart';
import '../providers/timetable_provider.dart';
import '../data/models/timetable_model.dart';
import '../widgets/quiz_card.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  bool _voiceMode = false;
  
  // File Attachment
  File? _selectedFile;
  String? _base64File;
  String? _mimeType;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      if(mounted) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          // Simple mime type guess
          final ext = result.files.single.extension?.toLowerCase();
          if (ext == 'pdf') _mimeType = 'application/pdf';
          else if (ext == 'png') _mimeType = 'image/png';
          else _mimeType = 'image/jpeg';
        });
        
        final bytes = await _selectedFile!.readAsBytes();
        _base64File = base64Encode(bytes);
      }
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
      _base64File = null;
      _mimeType = null;
    });
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
             if(mounted) {
               setState(() => _isListening = false);
               // AUTO-SEND if voice mode is on and we have text
               if (_voiceMode && _textController.text.isNotEmpty) {
                 _sendMessage();
               }
             }
          }
        },
        onError: (val) => debugPrint('onError: $val'),
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (mounted) {
              setState(() {
                _textController.text = val.recognizedWords;
              });
            }
          },
        );
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Speech recognition not available')),
           );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty && _selectedFile == null) return;

    // PREVENT DOUBLE-SEND
    if (ref.read(chatProvider).isLoading) return;

    final base64 = _base64File;
    final mime = _mimeType;

    _textController.clear();
    _clearFile(); // Clear UI immediately

    await ref.read(chatProvider.notifier).sendMessage(
      message.isEmpty ? "Analyze this document" : message,
      base64File: base64,
      mimeType: mime
    );
    _scrollToBottom();
  }

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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    final chatState = ref.watch(chatProvider);
    
    // Dynamic message bubble colors
    final userBubbleColor = isDark ? primaryColor : const Color(0xFF003366);
    final botBubbleColor = isDark ? const Color(0xFF1E293B) : Colors.white; 
    final inputFillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F9); 

    // Scroll to bottom when new message arrives
    ref.listen(chatProvider, (previous, next) {
      if (previous?.history.length != next.history.length) {
        _scrollToBottom();
        
        // VOICE MODE: Speak back the last message if it's from the assistant
        if (_voiceMode && next.history.last.role == 'assistant') {
          final lastMsg = next.history.last.text;
          // Don't speak raw JSON quiz data
          if (!(lastMsg.trim().startsWith('{') && lastMsg.contains('"questions"'))) {
            _tts.speak(lastMsg);
          } else {
             _tts.speak("I've generated a quiz for you. Good luck!");
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("DITA Assistant 🤖", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_voiceMode ? Icons.volume_up : Icons.volume_off, color: Colors.white),
            tooltip: "Toggle Voice Mode",
            onPressed: () {
              setState(() => _voiceMode = !_voiceMode);
              if (!_voiceMode) _tts.stop();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            tooltip: "Clear History",
            onPressed: () => ref.read(chatProvider.notifier).clearHistory(),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(15),
              itemCount: chatState.history.length,
              itemBuilder: (context, index) {
                final msg = chatState.history[index];
                final isUser = msg.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                      color: isUser ? userBubbleColor : botBubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: isUser ? const Radius.circular(15) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(15),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                      ],
                    ),
                    child: isUser
                        ? Text(msg.text, style: const TextStyle(color: Colors.white))
                        : _buildBotMessageContent(msg.text, textColor, isDark),
                  ),
                );
              },
            ),
          ),
          if (chatState.isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)),
            ),
          
          if (chatState.error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(chatState.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),

          // CONTEXTUAL SUGGESTIONS
          _buildContextualSuggestions(ref),

          // INPUT AREA
          Container(
            padding: const EdgeInsets.all(15),
            color: isDark ? botBubbleColor : Colors.white,
            child: Column(
              children: [
                if (_selectedFile != null)
                   Padding(
                     padding: const EdgeInsets.only(bottom: 10),
                     child: Row(
                       children: [
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                           decoration: BoxDecoration(
                             color: primaryColor.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(15),
                             border: Border.all(color: primaryColor.withOpacity(0.3))
                           ),
                           child: Row(
                             children: [
                               Icon(Icons.attach_file, size: 16, color: primaryColor),
                               const SizedBox(width: 5),
                               Text(
                                 _selectedFile!.path.split(Platform.pathSeparator).last,
                                 style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                                 overflow: TextOverflow.ellipsis,
                               ),
                               const SizedBox(width: 5),
                               GestureDetector(
                                 onTap: _clearFile,
                                 child: const Icon(Icons.close, size: 16, color: Colors.red),
                               )
                             ],
                           ),
                         ),
                       ],
                     ),
                   ),
                Row(
                  children: [
                    // ATTACH BUTTON
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: isDark ? Colors.white70 : Colors.grey,
                      onPressed: _pickFile,
                      tooltip: "Attach PDF or Image",
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: _selectedFile != null ? "Ask about this file..." : "Ask DITA or upload a PDF...",
                          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                const SizedBox(width: 5),
                // MIC BUTTON
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none, 
                    color: _isListening ? Colors.red : (isDark ? Colors.white70 : Colors.grey)
                  ),
                  onPressed: _listen,
                  tooltip: "Voice Input",
                ),
                const SizedBox(width: 5),
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFD700),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);
}

  Widget _buildContextualSuggestions(WidgetRef ref) {
    final timetableAsync = ref.watch(timetableProvider);
    
    return timetableAsync.maybeWhen(
      data: (items) {
        final now = DateTime.now();
        // Find next class today
        final today = _getDayName(now.weekday);
        
        final upcoming = items.where((item) {
          if (item.dayOfWeek != today) return false;
          // Simple time check (assumes 24h format HH:mm)
          final parts = item.startTime.split(':');
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          final classTime = DateTime(now.year, now.month, now.day, hour, minute);
          
          // Check if class is in the future but within 2 hours
          return classTime.isAfter(now) && classTime.difference(now).inHours < 2;
        }).toList();

        if (upcoming.isEmpty) return const SizedBox.shrink();

        final nextClass = upcoming.first;

        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ActionChip(
                avatar: const Icon(Icons.school, size: 16, color: Colors.blue),
                label: Text("Quiz me on ${nextClass.code ?? nextClass.title}"),
                onPressed: () {
                  ref.read(chatProvider.notifier).generateQuiz("Basic concepts of ${nextClass.title}");
                },
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1]; 
  }

  Widget _buildBotMessageContent(String text, Color? textColor, bool isDark) {
    // Try to parse as quiz JSON
    if (text.trim().startsWith('{') && text.contains('"questions"')) {
      try {
        final Map<String, dynamic> quizData = jsonDecode(text);
        if (quizData.containsKey('questions')) {
          return QuizCard(quizData: quizData);
        }
      } catch (e) {
        // Not valid JSON, fall through
      }
    }

    return MarkdownBody(
      data: text,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 15, height: 1.4, color: textColor),
        strong: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blueAccent : Colors.blue),
        listBullet: TextStyle(color: textColor),
      ),
    );
  }
}