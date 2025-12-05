import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  // Use a secure way to store this in production!
  final String _apiKey = 'AIzaSyDgkPXZTJsYA8pBUVh0APIHhiC7L-6FHE0'; 
  
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final Color _primaryDark = const Color(0xFF003366);
  final Color _accentGold = const Color(0xFFFFD700);
  final Color _bgOffWhite = const Color(0xFFF4F6F9);

  // We keep the history here for the UI
  final List<Map<String, String>> _history = [
    {'role': 'model', 'text': 'Hello! I am DITA AI. Ask me about your exams, classes, or upcoming events! 🎓'}
  ];

  static const String baseSystemPrompt = """
You are DITA AI, the intelligent virtual assistant for Daystar University students.
Your persona is helpful, tech-savvy, friendly, and concise.

**1. YOUR KNOWLEDGE BASE (CAMPUS & LOCATIONS):**
- **BCC Building:** Located after SBE block, before ICT. Rooms BCC 1-12.
- **ICT Building:** Tech hub. DITA Office is on Ground Floor between washrooms.
- **DITA Office:** ICT Building, Ground Floor.
- **DAC:** Main admin building with library.
- **Valley Road:** Nairobi campus.

**2. ACADEMIC RULES:**
- **Exams:** Arrive 30 mins early. Must have ID & Exam Card.
- **Clearance:** Clear fees to get exam card.
- **Pass Mark:** Generally 40%.

**3. APP NAVIGATION:**
- **Timetable:** Use 'Classes' tab or 'Portal Sync'.
- **Exams:** Use 'Exams' button on dashboard.
- **GPA:** Use 'GPA Calculator' in Quick Actions.
- **Resources:** Past papers in 'Resources' tab.

**BEHAVIOR:**
- Keep answers short (max 3 sentences).
- If unknown, refer to DITA Office.
""";

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
      // 1. FETCH REAL CONTEXT
      String eventContext = "";
      try {
        final events = await ApiService.getEvents();
        if (events.isNotEmpty) {
           String eventList = events.take(3).map((e) => "- ${e['title']} on ${e['date']} @ ${e['venue']}").join("\n");
           eventContext = "\n\n**REAL-TIME UPCOMING EVENTS:**\n$eventList";
        } else {
           eventContext = "\n\n**EVENTS:** No upcoming events found.";
        }
      } catch (e) {
        eventContext = ""; 
      }

      // 2. PREPARE API PAYLOAD (WITH MEMORY)
      final String systemInstruction = baseSystemPrompt + eventContext;
      
      List<Map<String, dynamic>> apiContents = [];

      // Loop through history to build context (Skip the very first static greeting)
      for (int i = 1; i < _history.length; i++) {
        var msg = _history[i];
        apiContents.add({
          "role": msg['role'] == 'user' ? "user" : "model",
          "parts": [{"text": msg['text']}]
        });
      }

      // 3. CALL GEMINI (1.5 Flash is faster/cheaper)
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          // System Instruction is a separate field in v1beta for better adherence
          "system_instruction": {
            "parts": [{"text": systemInstruction}]
          },
          "contents": apiContents, 
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 300, // Limit verbosity
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = "I'm not sure.";
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
           text = data['candidates'][0]['content']['parts'][0]['text'];
        }
        
        setState(() {
          _history.add({'role': 'model', 'text': text});
          _isLoading = false;
        });
      } else {
        print('Error: ${response.body}');
        setState(() {
          _history.add({'role': 'model', 'text': "My brain is offline (Error ${response.statusCode})."});
          _isLoading = false;
        });
      }
      _scrollToBottom();

    } catch (e) {
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