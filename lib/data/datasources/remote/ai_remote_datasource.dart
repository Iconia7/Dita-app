import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/errors/exceptions.dart';
import '../../../utils/app_logger.dart';

class AiRemoteDataSource {
  final String _apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  final _timeout = const Duration(seconds: 30);

  Future<String> getChatResponse(List<Map<String, dynamic>> history, String systemInstruction, {String? base64File, String? mimeType}) async {
    if (_apiKey.isEmpty) {
      throw ServerException('API key not found');
    }

    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey');
      
      // OPTIMIZATION: Cap history to last 10 messages to avoid huge payloads/TPM limits
      List<Map<String, dynamic>> cappedHistory = history.length > 10 
          ? history.sublist(history.length - 10) 
          : history;

      // Inject file into the LAST user message if present
      List<Map<String, dynamic>> finalHistory = List.from(cappedHistory);
      
      if (base64File != null && mimeType != null && finalHistory.isNotEmpty) {
        // Get the last message, which should be the user's prompt
        final lastMsg = Map<String, dynamic>.from(finalHistory.last);
        if (lastMsg['role'] == 'user') {
           // Gemini expects "parts": [ {text: "Query"}, {inline_data: {...}} ]
           List<Map<String, dynamic>> parts = List.from(lastMsg['parts']);
           parts.add({
             "inline_data": {
               "mime_type": mimeType,
               "data": base64File
             }
           });
           lastMsg['parts'] = parts;
           finalHistory[finalHistory.length - 1] = lastMsg;
        }
      }

      final body = {
        "contents": finalHistory,
        "system_instruction": {
          "parts": [
            {"text": systemInstruction}
          ]
        },
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 1500,
          "topP": 0.9,
        }
      };

      AppLogger.api('POST', url.toString());
      
      http.Response? resp;
      int retryCount = 0;
      const int maxRetries = 3;
      
      while (retryCount <= maxRetries) {
        resp = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(_timeout);

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final candidate = data['candidates'][0];
            final parts = candidate['content']['parts'];
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'];
            }
          }
          return "I'm not sure how to respond to that.";
        } else if (resp.statusCode == 429) {
          retryCount++;
          if (retryCount > maxRetries) break;
          
          final waitTime = Duration(seconds: retryCount * 3);
          AppLogger.warning('AI Rate Limit (429). Retrying in ${waitTime.inSeconds}s... ($retryCount/$maxRetries)');
          await Future.delayed(waitTime);
          continue;
        } else {
          AppLogger.error('AI API Error: ${resp.statusCode}');
          throw ServerException('AI service error: ${resp.statusCode}');
        }
      }

      if (resp?.statusCode == 429) {
        throw ServerException('AI Rate Limit reached. Please wait a minute and try again.');
      }
      
      throw ServerException('Unexpected error from AI service');
    } catch (e, stackTrace) {
      AppLogger.error('AI Connection error', error: e, stackTrace: stackTrace);
      throw ServerException('Connection error');
    }
  }
}
