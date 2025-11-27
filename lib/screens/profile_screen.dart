import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _currentUser;
  bool _isUpdating = false;

  // Daystar Brand Colors
  final Color _primaryBlue = const Color(0xFF003366);
  final Color _bgWhite = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  // --- 1. EDIT PROFILE LOGIC ---
  void _showEditDialog() {
    // Initialize controllers with current data
    final admController = TextEditingController(text: _currentUser['admission_number']);
    final programController = TextEditingController(text: _currentUser['program']);
    final phoneController = TextEditingController(text: _currentUser['phone_number']);
    final emailController = TextEditingController(text: _currentUser['email']);
    
    // Handle Year Dropdown (Default to 1 if null)
    int selectedYear = _currentUser['year_of_study'] ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // StatefulBuilder is required to update the Dropdown inside the Dialog
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Edit Profile", style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogInput(admController, "Admission No", Icons.badge_outlined),
                  const SizedBox(height: 15),
                  _buildDialogInput(programController, "Program", Icons.school_outlined),
                  const SizedBox(height: 15),
                  
                  // Year Dropdown
                  DropdownButtonFormField<int>(
                    value: selectedYear,
                    decoration: InputDecoration(
                      labelText: "Year of Study",
                      prefixIcon: Icon(Icons.calendar_today, color: _primaryBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text("Year $y"))).toList(),
                    onChanged: (val) => setStateDialog(() => selectedYear = val!),
                  ),
                  
                  const SizedBox(height: 15),
                  _buildDialogInput(phoneController, "Phone Number", Icons.phone_iphone_rounded, isPhone: true),
                  const SizedBox(height: 15),
                  _buildDialogInput(emailController, "Email Address", Icons.email_outlined),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("Cancel", style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context); // Close dialog first
                  await _updateProfile(
                    admController.text,
                    programController.text,
                    selectedYear,
                    phoneController.text,
                    emailController.text
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: const Text("Save Changes"),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _updateProfile(String adm, String prog, int year, String phone, String email) async {
    setState(() => _isUpdating = true);

    // Prepare Payload
    Map<String, dynamic> data = {
      "admission_number": adm,
      "program": prog,
      "year_of_study": year,
      "phone_number": phone,
      "email": email,
    };

    // Call API
    bool success = await ApiService.updateUser(_currentUser['id'], data);

    // Refresh Data if successful
    if (success) {
      final freshData = await ApiService.getUserDetails(_currentUser['id']);
      if (freshData != null) {
        setState(() => _currentUser = freshData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile Updated Successfully!"), backgroundColor: Colors.green)
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update profile."), backgroundColor: Colors.red)
        );
      }
    }

    setState(() => _isUpdating = false);
  }

  // --- 2. SUPPORT LOGIC ---
  Future<void> _launchContact(String scheme, String path) async {
    final Uri launchUri = Uri(scheme: scheme, path: path);
    try {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $scheme: $e");
    }
  }

  Future<void> _openWhatsApp() async {
    // Replace with Admin Number
    const String adminPhone = "254115332870"; 
    const String message = "Hello, I need help with the DITA App.";
    final Uri whatsappUrl = Uri.parse("https://wa.me/$adminPhone?text=${Uri.encodeComponent(message)}");
    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch WhatsApp");
    }
  }

  // --- 3. UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgWhite,
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _primaryBlue,
        elevation: 0,
        actions: [
          if (_isUpdating)
             const Padding(
               padding: EdgeInsets.all(15.0),
               child: SizedBox(width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
             )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- HEADER (Avatar & Name) ---
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _primaryBlue.withOpacity(0.2), width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: _primaryBlue.withOpacity(0.1),
                          child: Icon(Icons.person_rounded, size: 60, color: _primaryBlue),
                        ),
                      ),
                      // Edit Button on Avatar
                      GestureDetector(
                        onTap: _showEditDialog,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 18),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    (_currentUser['username'] ?? "Student").toUpperCase(),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _primaryBlue),
                  ),
                  Text(
                    _currentUser['email'] ?? "No Email",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // --- DETAILS CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Personal Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        onPressed: _showEditDialog,
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                        tooltip: "Edit Details",
                      )
                    ],
                  ),
                  const Divider(),
                  _buildDetailRow(Icons.badge_outlined, "Admission No", _currentUser['admission_number'] ?? "-"),
                  const Divider(height: 25),
                  _buildDetailRow(Icons.school_outlined, "Program", _currentUser['program'] ?? "-"),
                  const Divider(height: 25),
                  _buildDetailRow(Icons.calendar_today_outlined, "Year of Study", "Year ${_currentUser['year_of_study'] ?? 1}"),
                  const Divider(height: 25),
                  _buildDetailRow(Icons.phone_iphone_rounded, "Phone", _currentUser['phone_number'] ?? "-"),
                ],
              ),
            ),

            const SizedBox(height: 30),
            
            // --- SUPPORT SECTION ---
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 10),
                child: Text("Support & Help", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryBlue)),
              ),
            ),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  _buildActionTile(Icons.chat_bubble_outline_rounded, "Chat on WhatsApp", Colors.green, _openWhatsApp),
                  const Divider(height: 1, indent: 60),
                  _buildActionTile(Icons.call_outlined, "Call Support", Colors.blue, () => _launchContact('tel', '0115332870')),
                  const Divider(height: 1, indent: 60),
                  _buildActionTile(Icons.email_outlined, "Email Issues", Colors.orange, () => _launchContact('mailto', 'dita@daystar.ac.ke')),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- LOGOUT BUTTON ---
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.red.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primaryBlue, size: 20),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
    );
  }

  Widget _buildDialogInput(TextEditingController controller, String label, IconData icon, {bool isPhone = false}) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      ),
    );
  }
}