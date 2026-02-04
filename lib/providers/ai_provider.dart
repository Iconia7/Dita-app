import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/ai_repository.dart';
import '../data/datasources/remote/ai_remote_datasource.dart';
import 'auth_provider.dart';
import 'event_provider.dart';
import 'timetable_provider.dart';
import '../utils/app_logger.dart';

// ========== Dependency Injection ==========

final aiRemoteDataSourceProvider = Provider<AiRemoteDataSource>((ref) {
  return AiRemoteDataSource();
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(remoteDataSource: ref.watch(aiRemoteDataSourceProvider));
});

// ========== State Providers ==========

class ChatMessage {
  final String role;
  final String text;

  ChatMessage({required this.role, required this.text});

  Map<String, dynamic> toJson() => {
        "role": (role == 'user') ? "user" : "model",
        "parts": [
          {"text": text}
        ]
      };
}

class ChatState {
  final List<ChatMessage> history;
  final bool isLoading;
  final String? error;

  ChatState({
    required this.history,
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? history,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final AiRepository _repository;
  final Ref _ref;

  ChatNotifier(this._repository, this._ref)
      : super(ChatState(history: [
          ChatMessage(
              role: 'assistant',
              text: 'Hello! I am DITA AI. Ask me about your exams, classes, or upcoming events! 🎓')
        ]));

  Future<void> generateQuiz(String topic) async {
    final quizPrompt = "Generate a short 5-question multiple choice quiz about '$topic'. Format the response ONLY as a specialized JSON string with no markdown formatting. Structure: { \"title\": \"Quiz Title\", \"questions\": [ { \"question\": \"...\", \"options\": [\"A\", \"B\", \"C\", \"D\"], \"answerIndex\": 0 } ] }";
    
    // We don't add this prompt to visible history to keep UI clean, or we can add it as a system action.
    // For now, let's just make it a user message so the user sees what they asked.
    await sendMessage(quizPrompt);
  }

  Future<void> sendMessage(String message, {String? base64File, String? mimeType}) async {
    if (message.trim().isEmpty) return;

    final userMessage = ChatMessage(role: 'user', text: message);
    state = state.copyWith(
      history: [...state.history, userMessage],
      isLoading: true,
      error: null,
    );
    try {
      final systemInstruction = _buildSystemInstruction();
      final apiHistory = state.history.map((m) => m.toJson()).toList();

      final result = await _repository.getChatResponse(
        apiHistory, 
        systemInstruction,
        base64File: base64File,
        mimeType: mimeType
      );

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            error: failure.message,
          );
        },
        (response) {
          final botMessage = ChatMessage(role: 'assistant', text: response);
          state = state.copyWith(
            history: [...state.history, botMessage],
            isLoading: false,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Connection error',
      );
    }
  }

  String _buildSystemInstruction() {
    // Fetch context from other providers
    final user = _ref.read(currentUserProvider);
    final events = _ref.read(eventProvider).value ?? [];
    final timetable = _ref.read(timetableProvider).value ?? [];

    String userContext = '';
    if (user != null) {
      userContext = """
👤 **CURRENT STUDENT PROFILE:**
- **Name:** ${user.username}
- **Program:** ${user.program ?? 'N/A'}
- **Current Points:** ${user.points}
- **Membership:** ${user.isPaidMember == true ? 'Gold Member 🌟' : 'Standard'}
""";
    }

    String eventContext = '';
    if (events.isNotEmpty) {
      eventContext = """
📢 **UPCOMING SCHOOL EVENTS:**
${events.take(3).map((e) => "- ${e.title} (${e.date} @ ${e.location ?? 'Unknown'})").join("\n")}
""";
    }

    String examContext = '';
    final exams = timetable.where((e) => e.isExam).toList();
    if (exams.isNotEmpty) {
      exams.sort((a, b) => (a.examDate ?? DateTime.now()).compareTo(b.examDate ?? DateTime.now()));
      final upcoming = exams.where((e) => e.examDate != null && e.examDate!.isAfter(DateTime.now())).take(3).toList();
      if (upcoming.isNotEmpty) {
        examContext = """
📅 **YOUR UPCOMING EXAMS:**
${upcoming.map((e) => "- ${e.code ?? 'Exam'}: ${e.title} on ${e.examDate} at ${e.venue ?? 'N/A'}").join("\n")}
""";
      } else {
        examContext = "\n📅 **YOUR EXAMS:** No upcoming exams scheduled.";
      }
    }

    return """
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
    - **Transport:** School buses pick up at the main gate. Check the notice board for schedules.
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
* **📱 Community Hub:**
    - A social feed for students.
    - **Categories:** Academic (Help), Market (Sell items), General.
* **🕵️ Lost & Found:**
    - Found something? Post a picture! Lost something? Check the feed.
* **🏆 Leaderboard:**
    - Earn points by attending DITA events and scanning the QR code.
* **📅 Timetables:**
    - Exams and classes load from cache.
* **📚 Resources:**
    - Access past papers and notes. Locked for standard members. Gold status costs KES 200.

**5. CONTEXT AWARENESS (USE THIS DATA TO ANSWER):**
$userContext
$examContext
$eventContext

**BEHAVIORAL GUIDELINES:**
- **Personalize:** Use the student's name if available.
- **Be Helpful:** Answer questions based on the provided context if possible.
- **Length:** Keep answers concise (max 3-4 sentences).
""";
  }

  void clearHistory() {
    state = ChatState(history: [
      ChatMessage(
          role: 'assistant',
          text: 'History cleared. How else can I help you? 🎓')
    ]);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(aiRepositoryProvider), ref);
});
