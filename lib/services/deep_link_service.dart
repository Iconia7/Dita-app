import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/study_group_chat_screen.dart';
import '../data/models/study_group_model.dart';
import '../services/api_service.dart';

class DeepLinkService {
  static final _appLinks = AppLinks();
  static final _navigationKey = GlobalKey<NavigatorState>();
  
  static GlobalKey<NavigatorState> get navigationKey => _navigationKey;

  static Future<void> initDeepLinks(WidgetRef ref) async {
    // Handle links when app is already running
    _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri, ref);
    });
    
    // Handle initial link that opened the app
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        // Delay to ensure app is fully initialized
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleLink(initialLink, ref);
        });
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }
  }
  
  static void _handleLink(Uri uri, WidgetRef ref) async {
    print('Deep link received: $uri');
    
    // Parse: https://dita.co.ke/group/123
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'group') {
      final groupIdStr = uri.pathSegments[1];
      final groupId = int.tryParse(groupIdStr);
      
      if (groupId != null) {
        print('Navigating to group: $groupId');
        
        // Fetch group details from API
        try {
          final groups = await ApiService.getStudyGroups();
          final group = groups.firstWhere(
            (g) => g.id == groupId,
            orElse: () => throw Exception('Group not found'),
          );
          
          // Navigate to group chat
          _navigationKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => StudyGroupChatScreen(group: group),
            ),
          );
        } catch (e) {
          print('Error fetching group: $e');
          // Show error snackbar
          _navigationKey.currentState?.overlay?.context.let((context) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not find study group'),
                backgroundColor: Colors.red,
              ),
            );
          });
        }
      }
    }
  }
}

extension on BuildContext {
  T? let<T>(T? Function(BuildContext) fn) => fn(this);
}
