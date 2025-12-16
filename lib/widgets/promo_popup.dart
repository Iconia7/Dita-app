import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class PromoPopup {
  static Future<void> checkAndShow(BuildContext context) async {
    // 1. Fetch only ACTIVE promotions
    List<dynamic> promos = await ApiService.getPromotions();
    
    if (promos.isEmpty) return;

    // 2. Get the newest one
    final latest = promos.first;
    final int promoId = latest['id'];
    final String title = latest['title'];
    final String message = latest['message'];
    final String? imageUrl = latest['image'];
    final String actionText = latest['action_text'] ?? "CHECK IT OUT";

    // 3. Check if already seen
    final prefs = await SharedPreferences.getInstance();
    final int? lastSeenId = prefs.getInt('last_seen_promo_id');

    // If we've seen this specific ID, don't show it again
    if (lastSeenId == promoId) {
      return; 
    }

    // 4. Show the Dialog
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _PromoDialogWidget(
          id: promoId,
          title: title,
          message: message,
          imageUrl: imageUrl,
          actionText: actionText,
          onClose: () {
            prefs.setInt('last_seen_promo_id', promoId); // Mark as seen
            Navigator.pop(ctx);
          },
        ),
      );
    }
  }
}

class _PromoDialogWidget extends StatelessWidget {
  final int id;
  final String title;
  final String message;
  final String? imageUrl;
  final String actionText;
  final VoidCallback onClose;

  const _PromoDialogWidget({
    required this.id,
    required this.title,
    required this.message,
    this.imageUrl,
    required this.actionText,
    required this.onClose
  });

  @override
  Widget build(BuildContext context) {
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // MAIN CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 0, bottom: 20, left: 0, right: 0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // IMAGE (Full width at top)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  child: imageUrl != null 
                    ? Image.network(
                        imageUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (c,e,s) => _buildPlaceholder(context),
                      )
                    : _buildPlaceholder(context),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // Body
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: onClose, // Could link to a URL here if needed
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700), // Gold
                            foregroundColor: const Color(0xFF003366),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 5,
                          ),
                          child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      // Dismiss Text
                      GestureDetector(
                        onTap: onClose,
                        child: Text(
                          "No thanks",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CLOSE "X" BUTTON (Floating)
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Center(
        child: Icon(Icons.local_offer, size: 60, color: Theme.of(context).primaryColor),
      ),
    );
  }
}