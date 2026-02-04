import 'dart:convert';
import 'package:flutter/material.dart';

class QuizCard extends StatefulWidget {
  final Map<String, dynamic> quizData;

  const QuizCard({super.key, required this.quizData});

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isCompleted = false;
  int? _selectedAnswerIndex;
  bool _answered = false;

  void _submitAnswer(int index) {
    if (_answered) return;
    
    setState(() {
      _selectedAnswerIndex = index;
      _answered = true;
      
      final questions = widget.quizData['questions'] as List;
      final correctIndex = questions[_currentQuestionIndex]['answerIndex'];
      
      if (index == correctIndex) {
        _score++;
      }
    });

    // Auto advance after short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    final questions = widget.quizData['questions'] as List;
    if (_currentQuestionIndex < questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _answered = false;
      });
    } else {
      setState(() {
        _isCompleted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.quizData['title'] ?? 'Quiz';
    final questions = widget.quizData['questions'] as List;
    final currentQ = questions[_currentQuestionIndex];
    final options = currentQ['options'] as List;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
        ]
      ),
      child: _isCompleted ? _buildResult() : _buildQuestion(title, currentQ, options, questions.length),
    );
  }

  Widget _buildQuestion(String title, dynamic questionData, List dynamicOptions, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            Text("${_currentQuestionIndex + 1}/$total", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const Divider(),
        const SizedBox(height: 10),
        Text(questionData['question'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 15),
        ...List.generate(dynamicOptions.length, (index) {
          final option = dynamicOptions[index];
          final correctIndex = questionData['answerIndex'];
          
          Color color = Theme.of(context).scaffoldBackgroundColor;
          if (_answered) {
            if (index == correctIndex) color = Colors.green.withOpacity(0.2);
            else if (index == _selectedAnswerIndex) color = Colors.red.withOpacity(0.2);
          }

          return GestureDetector(
            onTap: () => _submitAnswer(index),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _answered && index == correctIndex ? Colors.green : Colors.transparent
                )
              ),
              child: Text(option),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResult() {
    final questions = widget.quizData['questions'] as List;
    final total = questions.length;
    final percentage = (_score / total * 100).round();
    
    return Column(
      children: [
        const Icon(Icons.emoji_events_rounded, size: 50, color: Colors.orange),
        const SizedBox(height: 10),
        Text("Quiz Completed!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 5),
        Text("You scored $_score / $total ($percentage%)"),
        const SizedBox(height: 15),
        ElevatedButton(
          onPressed: () {
             // Optional: Callback to restart or notify parent
             setState(() {
               _currentQuestionIndex = 0;
               _score = 0;
               _isCompleted = false;
               _answered = false;
               _selectedAnswerIndex = null;
             });
          }, 
          child: const Text("Retake Quiz")
        )
      ],
    );
  }
}
