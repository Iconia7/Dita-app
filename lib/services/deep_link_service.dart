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
      handleLink(uri, ref);
    });
    
    // Handle initial link that opened the app
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        // Delay to ensure app is fully initialized
        Future.delayed(const Duration(milliseconds: 500), () {
          handleLink(initialLink, ref);
        });
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }
  }
  
  static void handleLink(Uri uri, WidgetRef ref) async {
    print('Deep link received: $uri');
    
    // Parse both formats:
    // 1. ditaapp://group/123
    // 2. https://dita.co.ke/group/123
    
    int? groupId;
    
    if (uri.scheme == 'ditaapp' && uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'group') {
      // Format: ditaapp://group/123
      groupId = int.tryParse(uri.pathSegments[1]);
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') && 
               uri.host == 'api.dita.co.ke' && 
               uri.pathSegments.length >= 2 && 
               uri.pathSegments[0] == 'group') {
      // Format: https://api.dita.co.ke/group/123
      groupId = int.tryParse(uri.pathSegments[1]);
    }
    
    if (groupId != null) {
      print('Navigating to group: $groupId');
      
      // Fetch group details from API
      try {
        final groupData = await ApiService.getStudyGroup(groupId);
        final group = StudyGroupModel.fromJson(groupData);
        
        // Navigate to group chat
        _navigationKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => StudyGroupChatScreen(group: group),
          ),
        );
      } catch (e) {
        print('Error fetching group: $e');
        
        String errorMessage = 'Could not find study group';
        if (e.toString().contains('Session expired')) {
          errorMessage = 'Please login to join the study group';
        }
        
        // Show error snackbar
        final context = _navigationKey.currentState?.overlay?.context;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

extension on BuildContext {
  T? let<T>(T? Function(BuildContext) fn) => fn(this);
}
