import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class AiService {
  static const _urlKey = 'nova_server_url';
  static const _defaultUrl = 'http://10.0.2.2:8000';

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_urlKey) ?? _defaultUrl;
  }

  Future<void> setServerUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, value.trim().replaceAll(RegExp(r'/+$'), ''));
  }

  Future<String> sendMessage(List<ChatMessage> history) async {
    final baseUrl = await getServerUrl();
    final uri = Uri.parse('$baseUrl/api/chat');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'messages': history.map((m) => m.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 180));

    if (response.statusCode != 200) {
      String detail = 'Server error (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] != null) {
          detail = body['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['reply'] ?? '').toString();
  }

  Future<bool> checkServer() async {
    final baseUrl = await getServerUrl();
    final response = await http
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 12));
    return response.statusCode == 200;
  }
}
