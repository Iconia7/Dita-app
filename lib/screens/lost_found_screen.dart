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
  final Color _primaryDark = const Color(0xFF003366);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Lost & Found 🕵️", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDark,
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
            return const Center(child: DaystarSpinner(size: 120));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No items reported yet."));
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
        foregroundColor: _primaryDark,
        icon: const Icon(Icons.add_a_photo),
        label: const Text("Post Item"),
      ),
    );
  }

  Widget _buildList(List<dynamic> items) {
    // In LostFoundScreen (inside _buildList)
if (items.isEmpty) {
  return EmptyStateWidget(
    svgPath: 'assets/svgs/no_lost.svg',
    title: "Nothing to see here",
    message: "No items have been reported in this category recently. That is great news!",
    actionLabel: "Report an Item",
    onActionPressed: _showAddItemSheet, // Opens your add sheet
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
                    errorBuilder: (c,e,s) => Container(height: 180, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(item['location'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(item['description'], style: TextStyle(color: Colors.grey[800])),
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
                          foregroundColor: isResolved ? Colors.grey : _primaryDark,
                          side: BorderSide(color: isResolved ? Colors.grey : _primaryDark),
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
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locController = TextEditingController();
  late TextEditingController _phoneController;
  
  String _category = 'LOST'; // Default
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.currentUser['phone_number']);
  }

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
      widget.onPosted(); // Refresh parent
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item Posted!"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Post New Item", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            
            // Category Switch
            Row(
              children: [
                Expanded(child: _buildRadio("Lost 🛑", 'LOST')),
                Expanded(child: _buildRadio("Found ✅", 'FOUND')),
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
                  color: Colors.grey[100],
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

            TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Item Name (e.g. Blue Wallet)")),
            TextField(controller: _locController, decoration: const InputDecoration(labelText: "Location (e.g. BCC Lab 3)")),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Contact Phone"), keyboardType: TextInputType.phone),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: "Description"), maxLines: 2),
            
            const SizedBox(height: 25),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
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

  Widget _buildRadio(String label, String val) {
    return RadioListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      value: val,
      groupValue: _category,
      activeColor: const Color(0xFF003366),
      contentPadding: EdgeInsets.zero,
      onChanged: (v) => setState(() => _category = v.toString()),
    );
  }
}