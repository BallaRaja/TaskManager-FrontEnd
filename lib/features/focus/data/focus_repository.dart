// lib/features/focus/data/focus_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/session_manager.dart';
import '../models/focus_session.dart';

class FocusRepository {
  // ✅ Uses backendUrl (not baseUrl which points to /api/auth)
  String get _baseUrl => '${ApiConstants.backendUrl}/api/focus';

  // ── Auth token helper ──────────────────────────────────────
  Future<String?> _getToken() async {
    return await SessionManager.getToken(); // ✅ uses jwt_token key
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ── Save session ───────────────────────────────────────────
  Future<void> saveSession(FocusSession session) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No auth token found');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/session'),
            headers: _headers(token),
            body: jsonEncode({
              'taskId': session.taskId,
              'duration': session.duration,
              'date': session.date,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 201) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to save session (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('[FocusRepository] saveSession error: $e');
      rethrow;
    }
  }

  // ── Get daily summary ──────────────────────────────────────
  Future<Map<String, dynamic>> getDailySummary() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No auth token found');

      final response = await http
          .get(
            Uri.parse('$_baseUrl/daily'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // ✅ Handle both { data: {...} } and flat { totalSessions, ... } shapes
        final data = body['data'] as Map<String, dynamic>? ?? body;
        return {
          'totalSessions': data['totalSessions'] as int? ?? 0,
          'totalMinutes': data['totalMinutes'] as int? ?? 0,
          'streak': data['streak'] as int? ?? 0,
        };
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to fetch daily summary (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('[FocusRepository] getDailySummary error: $e');
      rethrow;
    }
  }

  // ── Get weekly analytics ───────────────────────────────────
  Future<Map<String, dynamic>> getWeeklyAnalytics() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No auth token found');

      final response = await http
          .get(
            Uri.parse('$_baseUrl/weekly'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>? ?? body;
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to fetch weekly analytics (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('[FocusRepository] getWeeklyAnalytics error: $e');
      rethrow;
    }
  }
}