import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  // Add any other IPs/hosts here if they change later (e.g. when deploying).
  static const List<String> baseUrls = [
    'http://10.0.0.165/Capstone Project1',
    'http://192.168.0.131/Capstone Project1', // old network, harmless to keep
    'http://10.0.2.2/Capstone Project1', // emulator only
  ];
  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    Object? lastError;
    for (final baseUrl in baseUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(timeout);
        return response;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Could not reach any server');
  }

  static Future<http.Response> get(
    String path, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    Object? lastError;
    for (final baseUrl in baseUrls) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/$path'))
            .timeout(timeout);
        return response;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Could not reach any server');
  }
}
