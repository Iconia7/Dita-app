import 'package:flutter/material.dart';
import 'package:dita_app/utils/app_theme.dart';

class DitaToast {
  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    bool isError = false,
  }) {
    final bgColor = backgroundColor ?? (isError ? Colors.redAccent : AppTheme.ditaBlue);
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/icon/icon.png',
                height: 24,
                width: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.05,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  /// Convenience method for error toasts
  static void error(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    show(context, message, isError: true, duration: duration);
  }

  /// Convenience method for success/info toasts
  static void success(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    show(context, message, backgroundColor: Colors.green, duration: duration);
  }
}
