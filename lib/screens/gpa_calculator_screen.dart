import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GpaCalculatorScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const GpaCalculatorScreen({super.key, required this.user});

  @override
  State<GpaCalculatorScreen> createState() => _GpaCalculatorScreenState();
}

class _GpaCalculatorScreenState extends State<GpaCalculatorScreen> {
  // --- COLORS ---
  final Color _primaryDark = const Color(0xFF003366);
  final Color _accentGold = const Color(0xFFFFD700);
  final Color _bgOffWhite = const Color(0xFFF4F6F9);

  // Data
  List<Map<String, dynamic>> _courses = [];
  double _currentGpa = 0.0;

  // Grading Scale (Standard 4.0 Scale - Adjust if needed for your Uni)
  final Map<String, double> _gradePoints = {
    "A": 4.0, "A-": 3.7,
    "B+": 3.3, "B": 3.0, "B-": 2.7,
    "C+": 2.3, "C": 2.0, "C-": 1.7,
    "D+": 1.3, "D": 1.0, "F": 0.0
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- LOGIC ---

  void _calculateGpa() {
    double totalPoints = 0;
    double totalCredits = 0;

    for (var course in _courses) {
      double points = _gradePoints[course['grade']] ?? 0.0;
      int credits = course['credits'];
      
      totalPoints += (points * credits);
      totalCredits += credits;
    }

    setState(() {
      _currentGpa = totalCredits == 0 ? 0.0 : (totalPoints / totalCredits);
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('gpa_data_${widget.user['id']}');
    if (data != null) {
      setState(() {
        _courses = List<Map<String, dynamic>>.from(json.decode(data));
      });
      _calculateGpa();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gpa_data_${widget.user['id']}', json.encode(_courses));
    _calculateGpa();
  }

  void _addCourse(String name, String grade, int credits) {
    setState(() {
      _courses.add({
        "name": name,
        "grade": grade,
        "credits": credits
      });
    });
    _saveData();
  }

  void _removeCourse(int index) {
    setState(() {
      _courses.removeAt(index);
    });
    _saveData();
  }

  // --- UI DIALOG ---
  void _showAddCourseSheet() {
    final nameController = TextEditingController();
    final creditsController = TextEditingController();
    String selectedGrade = "A";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 25, left: 25, right: 25
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Add Course", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
                const SizedBox(height: 20),
                
                // Course Name
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: "Course Name (e.g. Math)",
                    prefixIcon: Icon(Icons.book, color: Colors.grey[500]),
                    filled: true,
                    fillColor: _bgOffWhite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    // Grade Dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(color: _bgOffWhite, borderRadius: BorderRadius.circular(15)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedGrade,
                            isExpanded: true,
                            items: _gradePoints.keys.map((String grade) {
                              return DropdownMenuItem<String>(
                                value: grade,
                                child: Text("Grade: $grade", style: const TextStyle(fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                            onChanged: (val) => setSheetState(() => selectedGrade = val!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    
                    // Credits Input
                    Expanded(
                      child: TextField(
                        controller: creditsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: "Credits",
                          prefixIcon: Icon(Icons.numbers, color: Colors.grey[500]),
                          filled: true,
                          fillColor: _bgOffWhite,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty && creditsController.text.isNotEmpty) {
                        _addCourse(nameController.text, selectedGrade, int.tryParse(creditsController.text) ?? 3);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryDark, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    child: const Text("Add to GPA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  Color _getGpaColor(double gpa) {
    if (gpa >= 3.5) return Colors.green;
    if (gpa >= 2.5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
        title: const Text("GPA Calculator", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCourseSheet,
        backgroundColor: _accentGold,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("Add Course", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // --- 1. GPA SCORE CARD ---
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_primaryDark, const Color(0xFF004C99)]),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: _primaryDark.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                const Text("Cumulative GPA", style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 10),
                Text(
                  _currentGpa.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 60, 
                    fontWeight: FontWeight.w900, 
                    color: _getGpaColor(_currentGpa) == Colors.green ? Colors.greenAccent : _getGpaColor(_currentGpa)
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _courses.isEmpty ? "Add courses to start" : "${_courses.length} Courses Added",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),

          // --- 2. COURSE LIST ---
          Expanded(
            child: _courses.isEmpty
                ? Center(child: Icon(Icons.calculate_outlined, size: 80, color: Colors.grey[300]))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) {
                      final course = _courses[index];
                      return Dismissible(
                        key: UniqueKey(),
                        onDismissed: (_) => _removeCourse(index),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(15)),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 3))],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _primaryDark.withOpacity(0.1),
                                child: Text(course['grade'], style: TextStyle(fontWeight: FontWeight.bold, color: _primaryDark)),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(course['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text("${course['credits']} Credit Units", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text(
                                "${(_gradePoints[course['grade']]! * course['credits']).toStringAsFixed(1)} pts",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}