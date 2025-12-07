import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  bool _isFlashOn = false;
  late AnimationController _animationController;

  // 🟢 Colors moved to Theme (Only keeping Gold for scanner UI)
  final Color _accentGold = const Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Theme Helpers
    // In Dark Mode, we use black for the camera background.
    // The overlay color should match the primary brand color but semi-transparent.
    final overlayColor = Theme.of(context).primaryColor.withOpacity(0.7); 

    final double scanArea = 260.0;
    final double sidePadding = (MediaQuery.of(context).size.width - scanArea) / 2;
    final double verticalPadding = (MediaQuery.of(context).size.height - scanArea) / 2;

    return Scaffold(
      backgroundColor: Colors.black, // Camera needs black background
      body: Stack(
        children: [
          // 1. THE CAMERA LAYER
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  controller.stop();
                  Navigator.pop(context, barcode.rawValue);
                }
              }
            },
          ),

          // 2. THE THEMED OVERLAY (Dark Blue Cutout)
          // 🟢 Switched _primaryDark to dynamic overlayColor
          Positioned(
            top: 0, left: 0, right: 0, 
            height: verticalPadding, 
            child: Container(color: overlayColor)
          ),
          Positioned(
            bottom: 0, left: 0, right: 0, 
            height: verticalPadding, 
            child: Container(color: overlayColor)
          ),
          Positioned(
            top: verticalPadding, bottom: verticalPadding, left: 0, 
            width: sidePadding, 
            child: Container(color: overlayColor)
          ),
          Positioned(
            top: verticalPadding, bottom: verticalPadding, right: 0, 
            width: sidePadding, 
            child: Container(color: overlayColor)
          ),

          // 3. THE GOLD SCANNING FRAME & ANIMATION
          Center(
            child: Stack(
              children: [
                // The Border Box
                Container(
                  width: scanArea,
                  height: scanArea,
                  decoration: BoxDecoration(
                    border: Border.all(color: _accentGold, width: 2),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: _accentGold.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)
                    ]
                  ),
                ),
                // The Animated Red Line
                SizedBox(
                  width: scanArea,
                  height: scanArea,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          Positioned(
                            top: _animationController.value * (scanArea - 10),
                            left: 10,
                            right: 10,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                boxShadow: [
                                  BoxShadow(color: Colors.redAccent.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)
                                ]
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // Corner Decor
                Positioned(top: 0, left: 0, child: _buildCorner(true, true)),
                Positioned(top: 0, right: 0, child: _buildCorner(true, false)),
                Positioned(bottom: 0, left: 0, child: _buildCorner(false, true)),
                Positioned(bottom: 0, right: 0, child: _buildCorner(false, false)),
              ],
            ),
          ),

          // 4. HEADER (Back Button & Title)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), 
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24)
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const Text(
                    "Scan QR Code", 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)
                  ),
                  const SizedBox(width: 45), // Spacer
                ],
              ),
            ),
          ),

          // 5. BOTTOM CONTROLS
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: const Text(
                    "Align QR code within the frame",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Flashlight Toggle
                GestureDetector(
                  onTap: () {
                    controller.toggleTorch();
                    setState(() {
                      _isFlashOn = !_isFlashOn;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _isFlashOn ? _accentGold : Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: _isFlashOn ? _accentGold : Colors.white24, width: 2)
                    ),
                    child: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off, 
                      color: _isFlashOn ? Colors.black : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for corners
  Widget _buildCorner(bool top, bool left) {
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: _accentGold, width: 4) : BorderSide.none,
          bottom: !top ? BorderSide(color: _accentGold, width: 4) : BorderSide.none,
          left: left ? BorderSide(color: _accentGold, width: 4) : BorderSide.none,
          right: !left ? BorderSide(color: _accentGold, width: 4) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: (top && left) ? const Radius.circular(20) : Radius.zero,
          topRight: (top && !left) ? const Radius.circular(20) : Radius.zero,
          bottomLeft: (!top && left) ? const Radius.circular(20) : Radius.zero,
          bottomRight: (!top && !left) ? const Radius.circular(20) : Radius.zero,
        )
      ),
    );
  }
}