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
          'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$_apiKey');
      
      // OPTIMIZATION: Cap history to last 10 messages to avoid huge payloads/TPM limits
      List<Map<String, dynamic>> cappedHistory = history.length > 10 
          ? history.sublist(history.length - 10) 
          : history;

List<Map<String, dynamic>> finalHistory = [];

// Inject system instruction as first message
if (systemInstruction.isNotEmpty) {
  finalHistory.add({
    "role": "user",
    "parts": [
      {
        "text":
          "SYSTEM INSTRUCTION:\n$systemInstruction"
      }
    ]
  });
}

// Append capped conversation history
finalHistory.addAll(cappedHistory);

      
     if (base64File != null && mimeType != null) {
  // Find the last message that actually has text parts
  for (int i = finalHistory.length - 1; i >= 0; i--) {
    final msg = finalHistory[i];
    if (msg['parts'] != null) {
      List<Map<String, dynamic>> parts = List.from(msg['parts']);
      parts.add({
        "inline_data": {
          "mime_type": mimeType,
          "data": base64File
        }
      });
      msg['parts'] = parts;
      finalHistory[i] = msg;
      break;
    }
  }
}


      final body = {
        "contents": finalHistory,
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
          AppLogger.error('AI Error Body: ${resp.body}');
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
