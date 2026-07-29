import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import 'package:crypto/crypto.dart';

class ChatSession {
  final String id;
  final String title;
  final String extractedText;
  final List<ChatMessage> messages;
  final List<Map<String, String>> history;
  final int timestamp;

  ChatSession({
    required this.id,
    required this.title,
    required this.extractedText,
    required this.messages,
    required this.history,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'extractedText': extractedText,
    'messages': messages.map((m) => m.toJson()).toList(),
    'history': history,
    'timestamp': timestamp,
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'],
    title: json['title'],
    extractedText: json['extractedText'],
    messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList(),
    history: List<Map<String, String>>.from((json['history'] ?? []).map((x) => Map<String, String>.from(x))),
    timestamp: json['timestamp'] ?? 0,
  );
}

class ChatStorageService {
  static const String _key = 'dot_ai_chat_sessions';

  static String generateId(String text) {
    return md5.convert(utf8.encode(text)).toString();
  }

  static Future<void> saveSession(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    sessions[session.id] = session;
    
    final Map<String, dynamic> jsonMap = {};
    for (var entry in sessions.entries) {
      jsonMap[entry.key] = entry.value.toJson();
    }
    await prefs.setString(_key, json.encode(jsonMap));
  }

  static Future<Map<String, ChatSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null) return {};
    
    try {
      final Map<String, dynamic> map = json.decode(str);
      final Map<String, ChatSession> sessions = {};
      for (var entry in map.entries) {
        sessions[entry.key] = ChatSession.fromJson(entry.value);
      }
      return sessions;
    } catch (_) {
      return {};
    }
  }

  static Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    sessions.remove(id);
    
    final Map<String, dynamic> jsonMap = {};
    for (var entry in sessions.entries) {
      jsonMap[entry.key] = entry.value.toJson();
    }
    await prefs.setString(_key, json.encode(jsonMap));
  }
}
