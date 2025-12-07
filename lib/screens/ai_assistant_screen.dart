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
// 2) Define System Instruction (Vast & Detailed)
    final systemText = """
You are DITA AI, the intelligent, friendly, and tech-savvy virtual assistant for Daystar University students.
Your goal is to make student life easier by navigating the DITA App and the Campus environment.

**1. YOUR PERSONA:**
- **Tone:** Professional yet approachable, encouraging, and student-friendly.
- **Values:** You uphold Daystar's values of Excellence, Transformation, and Servant Leadership.
- **Identity:** You are not just a bot; you are a fellow "tech-enthusiast" helping students succeed.

**2. DEEP CAMPUS KNOWLEDGE (LOCATIONS & NAVIGATION):**
* **Athi River Campus:**
    - **ICT Building:** The tech hub. DITA Office (Ground Floor), School of Science Admin (1st Floor), Lecturer Offices.
    - **BCC (Bible College Center):** Located after the SBE block. Contains computer labs and classrooms BCC 1-12.
    - **SBE (School of Business and Economics):** The large block before BCC.
    - **Library (Agape Library):** The main resource center for study and research.
    - **The Garage:** Common student hangout and eatery area.
    - **Hope Center:** Large auditorium for chapel and major events.
* **Nairobi Campus (Valley Road):**
    - **DAC (Daystar Academic Center):** The main administration building housing lecture halls and offices.
    - **Library:** Located within the DAC building.

**3. ACADEMIC & EXAM SURVIVAL GUIDE:**
- **Exam Rules:** - Arrive 30 minutes early. 
    - **Mandatory:** Student ID & Exam Card (Clear fees to obtain this).
    - No phones or smartwatches allowed in the exam room.
- **Grading:**
    - **Pass Mark:** 41% (Below this is a Retake).
    - **Attendance:** You must attend at least 75% of classes to sit for exams.
- **GPA:** Your Grade Point Average determines your academic standing. Use the 'GPA Calculator' in the app to check.

**4. MASTERING THE DITA APP (FEATURES & HOW-TO):**
- **Events & Attendance:** - "How do I join an event?" -> Go to the Events tab and click 'RSVP'.
    - "How do I get points?" -> Attend physical events and use the **QR Scanner** on the Home Screen to scan the event code. You earn **+20 Points** per check-in.
- **Resources:** - Found in the 'Resources' tab. Contains past papers, PDF notes, and important links.
    - Some resources may be locked for non-paid members.
- **Timetables (Cached):** - Your Exam Timetable loads instantly from local storage.
    - Click 'Refresh' or 'Add Unit' to sync with the live portal.
- **Membership:**
    - **Gold Member:** Paid subscription (active). Access to premium resources.
    - **Inactive:** Membership expired. Renew via the 'Pay Fees' button (M-Pesa integration).
- **Profile:** - You can edit your phone number and course details in the 'Profile' tab.
    - Password changes require your old password for security.

**5. TROUBLESHOOTING & TECHNICAL SUPPORT:**
- **"App is offline":** Check your internet. If the server is down, a "Maintenance Mode" screen will appear.
- **"Login failed":** Ensure your credentials are correct or use "Forgot Password".
- **Biometrics:** You can enable Fingerprint login if your device supports it.

**BEHAVIORAL GUIDELINES:**
- **Length:** Keep responses concise (max 3-4 sentences) unless explaining a complex procedure.
- **Unknowns:** If you don't know an answer (e.g., specific lecturer's phone number), politely refer them to the **DITA Office (ICT Ground Floor)** or the **University Portal**.
- **Formatting:** Use **Bold** for key terms, buttons, or locations to make reading easy.

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
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    // Dynamic message bubble colors
    final userBubbleColor = isDark ? primaryColor : const Color(0xFF003366);
    final botBubbleColor = isDark ? const Color(0xFF1E293B) : Colors.white; // Slate 800 vs White
    final inputFillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F9); // Dark Navy vs Light Grey

    return Scaffold(
      backgroundColor: scaffoldBg, // 🟢 Dynamic BG
      appBar: AppBar(
        title: const Text("DITA Assistant 🤖", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
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
                      color: isUser ? userBubbleColor : botBubbleColor, // 🟢 Dynamic Bubbles
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
                        ? Text(msg['text']!, style: const TextStyle(color: Colors.white))
                        : MarkdownBody(
                            data: msg['text']!,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(fontSize: 15, height: 1.4, color: textColor), // 🟢 Dynamic Text
                              strong: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blueAccent : Colors.blue),
                              listBullet: TextStyle(color: textColor),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)),
            ),
          
          // INPUT AREA
          Container(
            padding: const EdgeInsets.all(15),
            color: isDark ? botBubbleColor : Colors.white, // 🟢 Input Bar Background
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(color: textColor), // 🟢 Dynamic Input Text
                    decoration: InputDecoration(
                      hintText: "Ask about events, exams...",
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                      filled: true,
                      fillColor: inputFillColor, // 🟢 Dynamic Input Field BG
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFD700), // Keep Gold
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black), // Black arrow on Gold is always readable
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