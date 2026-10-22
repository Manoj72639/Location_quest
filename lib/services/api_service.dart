import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'QUEST_API_URL',
    defaultValue: 'http://192.168.1.5:8000',
  );

  Future<Map<String, dynamic>> validateQuest({
    required String questId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please sign in first.');
    }

    try {
      final token = await user.getIdToken();

      if (token == null || token.isEmpty) {
        throw Exception('Unable to get authentication token.');
      }

      final uri = Uri.parse(
        '$baseUrl/quests/${Uri.encodeComponent(questId)}/validate',
      );

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': accuracy,
            }),
          )
          .timeout(const Duration(seconds: 30));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw Exception(
          'Backend returned an invalid response '
          '(HTTP ${response.statusCode}).',
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }

        throw Exception('Unexpected response format from backend.');
      }

      if (decoded is Map && decoded['detail'] != null) {
        throw Exception(decoded['detail'].toString());
      }

      throw Exception('Server error: HTTP ${response.statusCode}');
    } on TimeoutException {
      throw Exception(
        'Request timed out. Check whether the backend is running '
        'and reachable from your phone.',
      );
    } on SocketException {
      throw Exception(
        'Cannot connect to the backend. Check the API IP, '
        'Wi-Fi connection, and Windows Firewall.',
      );
    } on http.ClientException {
      throw Exception(
        'Network request failed. Check your API URL and connection.',
      );
    }
  }
}
