// lib/screens/ai_assistant_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  late final String _apiKey;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final Color _primaryDark = const Color(0xFF003366);
  final Color _accentGold = const Color(0xFFFFD700);
  final Color _bgOffWhite = const Color(0xFFF4F6F9);

  // UI history
  final List<Map<String, String>> _history = [
    {'role': 'assistant', 'text': 'Hello! I am DITA AI. Ask me about your exams, classes, or upcoming events! 🎓'}
  ];


  @override
  void initState() {
    super.initState();
    // Ensure you call dotenv.load() in main.dart before runApp (example below).
    _apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      // Fail fast in dev so you know to add the key
      _history.insert(0, {'role': 'assistant', 'text': 'API key not found. Add GOOGLE_API_KEY in .env'});
    }
  }

Future<void> _sendMessage() async {
  final message = _textController.text.trim();
  if (message.isEmpty) return;

  setState(() {
    _history.add({'role': 'user', 'text': message});
    _isLoading = true;
    _textController.clear();
  });
  _scrollToBottom();

  try {
    // 1) Get Events Context
    String eventContext = '';
    try {
      final events = await ApiService.getEvents();
      if (events.isNotEmpty) {
        eventContext = "\n\nREAL-TIME UPCOMING EVENTS:\n" + 
            events.take(3).map((e) => "- ${e['title']} on ${e['date']} @ ${e['venue']}").join("\n");
      }
    } catch (_) {}

    // 2) Define System Instruction
    final systemText = """
You are DITA AI, the intelligent virtual assistant for Daystar University students.
Your persona is helpful, tech-savvy, friendly, and concise.
BEHAVIOR: Keep answers short (max 3 sentences). If unknown, refer to DITA Office.

Knowledge:
- BCC Building: Located after SBE block, before ICT. Rooms BCC 1-12.
- ICT Building: Tech hub. DITA Office on Ground Floor between washrooms.
- DAC: Main admin building with library.
- Exams: Arrive 30 mins early. Must have ID & Exam Card.
$eventContext
""";

    // 3) Build History
    List<Map<String, dynamic>> apiContents = [];
    for (final m in _history) {
      apiContents.add({
        "role": (m['role'] == 'user') ? "user" : "model",
        "parts": [
          {"text": m['text']}
        ]
      });
    }

    // 4) Build Request Body
    final body = {
      "contents": apiContents,
      "system_instruction": {
        "parts": [
          {"text": systemText}
        ]
      },
      "generationConfig": {
        "temperature": 0.7,
        "maxOutputTokens": 300,
      }
    };

    // 5) CALL API (Using v1beta + gemini-2.5-flash)
    // Note: We use 'v1beta' here as it often supports the newest models best
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey');

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      String assistantText = "I'm not sure.";
      
      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        final parts = data['candidates'][0]['content']['parts'];
        if (parts != null && parts.isNotEmpty) {
          assistantText = parts[0]['text'];
        }
      }
      
      setState(() {
        _history.add({'role': 'model', 'text': assistantText});
        _isLoading = false;
      });
    } else {
      print("API Error: ${resp.body}");
      setState(() {
        _history.add({'role': 'model', 'text': "My brain is offline (Error ${resp.statusCode})."});
        _isLoading = false;
      });
    }
    _scrollToBottom();
  } catch (e) {
    print("Exception: $e");
    setState(() {
      _history.add({'role': 'model', 'text': "Connection error."});
      _isLoading = false;
    });
  }
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
    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
        title: const Text("DITA Assistant 🤖", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(15),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final msg = _history[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                      color: isUser ? _primaryDark : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: isUser ? const Radius.circular(15) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(15),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                    ),
                    child: isUser
                        ? Text(msg['text']!, style: const TextStyle(color: Colors.white))
                        : MarkdownBody(
                            data: msg['text']!,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(fontSize: 15, height: 1.4),
                              strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "Ask about events, exams...",
                      filled: true,
                      fillColor: _bgOffWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: _accentGold,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: _sendMessage,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
