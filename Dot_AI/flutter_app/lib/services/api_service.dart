// =============================================================
//  API Service - Backend Communication
//  Handles all HTTP calls to the FastAPI backend
// =============================================================

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Change this to your backend URL
/// - Local dev (same device): http://localhost:8000
/// - Android emulator: http://10.0.2.2:8000
/// - Real device on same WiFi: http://YOUR_PC_IP:8000
const String kBaseUrl = 'http://127.0.0.1:8000/api';

class ApiService {
  // Timeout duration for API calls
  static const Duration _timeout = Duration(seconds: 60);

  // =====================================================
  // 1. PROCESS IMAGE → Extract Braille Text
  // =====================================================

  /// Sends a Braille image to the backend and returns extracted text.
  ///
  /// [imageFile] - The image file selected/captured by the user
  /// Returns a map with 'text' and 'success' keys
  static Future<Map<String, dynamic>> processImage(File imageFile) async {
    try {
      final uri = Uri.parse('$kBaseUrl/process-image');

      // Create multipart request (required for file uploads)
      final request = http.MultipartRequest('POST', uri);

      // Determine file type from extension
      final extension = imageFile.path.split('.').last.toLowerCase();
      final mediaType = _getMediaType(extension);

      // Attach image file to request
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // Must match FastAPI parameter name
          imageFile.path,
          contentType: mediaType,
        ),
      );

      // Send request with timeout
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'text': data['text'] ?? '',
          'confidence': data['confidence'] ?? 0.0,
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['detail'] ?? 'Image processing failed',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server. Check your network connection.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'An error occurred: ${e.toString()}',
      };
    }
  }

  // =====================================================
  // 2. QUERY → Ask Question About Braille Text
  // =====================================================

  /// Sends a question and extracted text to the backend for LLM answering.
  ///
  /// [question] - User's question
  /// [context] - Extracted Braille text (used as context)
  /// [history] - Previous conversation messages (for multi-turn chat)
  static Future<Map<String, dynamic>> queryText({
    required String question,
    required String context,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final uri = Uri.parse('$kBaseUrl/query');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'question': question,
              'context': context,
              'conversation_history': history,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'answer': data['answer'] ?? '',
          'model_used': data['model_used'] ?? 'unknown',
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['detail'] ?? 'Query failed',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server. Check your network connection.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Query error: ${e.toString()}',
      };
    }
  }

  // =====================================================
  // 3. TEXT-TO-SPEECH → Convert Text to Audio
  // =====================================================

  /// Converts text to speech and returns audio bytes.
  ///
  /// [text] - Text to convert to speech
  /// [language] - Language code (default: 'en')
  static Future<Map<String, dynamic>> textToSpeech({
    required String text,
    String language = 'en',
  }) async {
    try {
      final uri = Uri.parse('$kBaseUrl/tts/base64');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'language': language,
              'speed': 1.0,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'audio_base64': data['audio_base64'] ?? '',
          'format': data['format'] ?? 'mp3',
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['detail'] ?? 'TTS failed',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server for audio generation.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'TTS error: ${e.toString()}',
      };
    }
  }

  // =====================================================
  // Helper Methods
  // =====================================================

  static MediaType _getMediaType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'bmp':
        return MediaType('image', 'bmp');
      default:
        return MediaType('image', 'jpeg');
    }
  }
}