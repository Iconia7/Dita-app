import 'dart:io';
import 'package:dita_app/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/dita_loader.dart';

class LostFoundScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser; // Need this to auto-fill phone
  const LostFoundScreen({super.key, required this.currentUser});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color _accentGold = const Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddLostItemSheet(
        currentUser: widget.currentUser, 
        onPosted: () => setState(() {}), // Refresh list
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: scaffoldBg, // 🟢 Dynamic BG
      appBar: AppBar(
        title: const Text("Lost & Found 🕵️", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accentGold,
          indicatorWeight: 4,
          labelColor: _accentGold,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: "LOST 🛑"),
            Tab(text: "FOUND ✅"),
          ],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.getLostFoundItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: DaystarSpinner(size: 120)); // Use custom spinner
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
             return EmptyStateWidget(
                svgPath: 'assets/svgs/safe.svg',
                title: "Nothing to see here",
                message: "No items have been reported recently. That is great news!",
                actionLabel: "Report an Item",
                onActionPressed: _showAddItemSheet,
              );
          }

          final allItems = snapshot.data!;
          final lostItems = allItems.where((i) => i['category'] == 'LOST').toList();
          final foundItems = allItems.where((i) => i['category'] == 'FOUND').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(lostItems),
              _buildList(foundItems),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemSheet,
        backgroundColor: _accentGold,
        foregroundColor: primaryColor, // 🟢 Dynamic Text Color
        icon: const Icon(Icons.add_a_photo),
        label: const Text("Post Item"),
      ),
    );
  }

  Widget _buildList(List<dynamic> items) {
    // 🟢 Theme Helpers
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.labelSmall?.color;
    final primaryColor = Theme.of(context).primaryColor;

    if (items.isEmpty) {
      return EmptyStateWidget(
        svgPath: 'assets/svgs/safe.svg',
        title: "Nothing here",
        message: "No items found in this category.",
        actionLabel: "Report an Item",
        onActionPressed: _showAddItemSheet,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final bool isResolved = item['is_resolved'] ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
          color: cardColor, // 🟢 Dynamic Card BG
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IMAGE AREA
              if (item['image'] != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: Image.network(
                    item['image'], 
                    height: 180, 
                    width: double.infinity, 
                    fit: BoxFit.cover,
                    errorBuilder: (c,e,s) => Container(height: 180, color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.grey)),
                  ),
                ),
              
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['item_name'], 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor), // 🟢 Dynamic Text
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isResolved)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(5)),
                            child: const Text("RESOLVED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        else
                          Text(
                            DateFormat('MMM d').format(DateTime.parse(item['created_at'])),
                            style: TextStyle(color: subTextColor, fontSize: 12), // 🟢 Dynamic Subtext
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: subTextColor),
                        const SizedBox(width: 4),
                        Text(item['location'], style: TextStyle(color: subTextColor, fontSize: 13)), // 🟢
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(item['description'], style: TextStyle(color: textColor)), // 🟢
                    const SizedBox(height: 15),
                    
                    // CONTACT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isResolved ? null : () async {
                          final Uri launchUri = Uri(scheme: 'tel', path: item['contact_phone']);
                          await launchUrl(launchUri);
                        },
                        icon: const Icon(Icons.call),
                        label: Text(isResolved ? "Item Returned" : "Contact Finder/Owner"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isResolved ? Colors.grey : primaryColor, // 🟢 Dynamic Color
                          side: BorderSide(color: isResolved ? Colors.grey : primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

// --- SHEET FOR ADDING ITEM ---
class AddLostItemSheet extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final VoidCallback onPosted;

  const AddLostItemSheet({super.key, required this.currentUser, required this.onPosted});

  @override
  State<AddLostItemSheet> createState() => _AddLostItemSheetState();
}

class _AddLostItemSheetState extends State<AddLostItemSheet> {
  // ... (Controllers and Submit logic stay the same) ...
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locController = TextEditingController();
  late TextEditingController _phoneController;
  
  String _category = 'LOST'; 
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.currentUser['phone_number']);
  }
  
  // ... (pickImage and submit methods) ...
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _locController.text.isEmpty) return;

    setState(() => _isLoading = true);

    Map<String, String> data = {
      'item_name': _titleController.text,
      'description': _descController.text,
      'location': _locController.text,
      'contact_phone': _phoneController.text,
      'category': _category,
    };

    bool success = await ApiService.postLostItem(data, _selectedImage);

    setState(() => _isLoading = false);

    if (success && mounted) {
      widget.onPosted(); 
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item Posted!"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final inputColor = isDark ? const Color(0xFF0F172A) : Colors.grey[100];
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: sheetColor, // 🟢 Dynamic BG
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Post New Item", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)), // 🟢
            const Divider(),
            
            // Category Switch
            Row(
              children: [
                Expanded(child: _buildRadio("Lost 🛑", 'LOST', textColor!, primaryColor)),
                Expanded(child: _buildRadio("Found ✅", 'FOUND', textColor, primaryColor)),
              ],
            ),
            const SizedBox(height: 15),

            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: inputColor, // 🟢 Dynamic Picker BG
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[300]!),
                  image: _selectedImage != null 
                    ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                    : null
                ),
                child: _selectedImage == null 
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt, color: Colors.grey, size: 40),
                        Text("Tap to add photo", style: TextStyle(color: Colors.grey))
                      ],
                    )
                  : null,
              ),
            ),
            const SizedBox(height: 15),

            // Inputs
            _buildInput(_titleController, "Item Name (e.g. Blue Wallet)", inputColor, textColor),
            const SizedBox(height: 10),
            _buildInput(_locController, "Location (e.g. BCC Lab 3)", inputColor, textColor),
            const SizedBox(height: 10),
            _buildInput(_phoneController, "Contact Phone", inputColor, textColor, isPhone: true),
            const SizedBox(height: 10),
            _buildInput(_descController, "Description", inputColor, textColor, maxLines: 2),
            
            const SizedBox(height: 25),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("POST ITEM", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(String label, String val, Color textColor, Color activeColor) {
    return RadioListTile(
      title: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)), // 🟢
      value: val,
      groupValue: _category,
      activeColor: activeColor, // 🟢
      contentPadding: EdgeInsets.zero,
      onChanged: (v) => setState(() => _category = v.toString()),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, Color? fill, Color? text, {bool isPhone = false, int maxLines = 1}) {
      return TextField(
        controller: ctrl,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        maxLines: maxLines,
        style: TextStyle(color: text),
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: TextStyle(color: Colors.grey[500]),
          filled: true,
          fillColor: fill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
        ),
      );
  }
}