// lib/core/services/offline_sync_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import '../utils/session_manager.dart';

/// Manages an offline queue for tasks that couldn't be created due to
/// network issues. When connectivity is restored the queue is flushed
/// automatically.
class OfflineSyncService extends ChangeNotifier {
  static const String _queueKey = 'offline_task_queue';

  // ── Singleton ──────────────────────────────────────────────────
  static final OfflineSyncService _instance = OfflineSyncService._();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  bool _isOnline = true;

  /// Number of tasks waiting to be synced.
  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  /// Whether a sync is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Whether the device currently has connectivity.
  bool get isOnline => _isOnline;

  /// Callback invoked after each successfully synced task.
  /// Signature: (tempId, serverTask) — lets the controller swap the
  /// optimistic placeholder with the real server object.
  void Function(String tempId, Map<String, dynamic> serverTask)? onTaskSynced;

  /// Called when the entire pending queue has been flushed (even if some
  /// items failed). UI can use this to trigger a full refresh.
  VoidCallback? onSyncComplete;

  // ── Lifecycle ──────────────────────────────────────────────────

  /// Call once at app start (e.g. in MainAppShell).
  Future<void> init() async {
    await _refreshPendingCount();

    // Listen for connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      final wasOffline = !_isOnline;
      _isOnline = online;
      notifyListeners();

      if (online && wasOffline) {
        debugPrint('🌐 [OfflineSync] Back online — flushing queue…');
        syncPendingTasks();
      }
    });

    // Check initial state
    final results = await Connectivity().checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    notifyListeners();

    // If we're already online and have pending items, flush now
    if (_isOnline && _pendingCount > 0) {
      syncPendingTasks();
    }
  }

  void dispose_() {
    _connectivitySub?.cancel();
  }

  // ── Queue management ───────────────────────────────────────────

  /// Enqueue a task body that failed to POST. Returns a temporary ID
  /// that the controller can use as an optimistic placeholder `_id`.
  Future<String> enqueue(Map<String, dynamic> taskBody) async {
    final tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    final entry = {
      'tempId': tempId,
      'body': taskBody,
      'createdAt': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    final list = _readQueue(prefs);
    list.add(entry);
    await prefs.setString(_queueKey, jsonEncode(list));

    _pendingCount = list.length;
    notifyListeners();
    debugPrint(
        '📦 [OfflineSync] Enqueued task "${taskBody['title']}" (tempId=$tempId). '
        'Queue size: ${list.length}');
    return tempId;
  }

  /// Remove a single entry from the queue by its tempId.
  Future<void> _removeFromQueue(String tempId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _readQueue(prefs);
    list.removeWhere((e) => e['tempId'] == tempId);
    await prefs.setString(_queueKey, jsonEncode(list));
    _pendingCount = list.length;
  }

  /// Read the raw queue list from prefs.
  List<Map<String, dynamic>> _readQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> _refreshPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingCount = _readQueue(prefs).length;
    notifyListeners();
  }

  // ── Sync logic ─────────────────────────────────────────────────

  /// Attempt to POST all queued tasks to the server.
  Future<void> syncPendingTasks() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    final token = await SessionManager.getToken();
    if (token == null) {
      _isSyncing = false;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final queue = _readQueue(prefs);

    if (queue.isEmpty) {
      _isSyncing = false;
      notifyListeners();
      return;
    }

    debugPrint('🔄 [OfflineSync] Syncing ${queue.length} pending tasks…');

    int synced = 0;
    // Work on a copy so we can safely mutate during iteration
    for (final entry in List<Map<String, dynamic>>.from(queue)) {
      final tempId = entry['tempId'] as String;
      final body = Map<String, dynamic>.from(entry['body'] as Map);

      try {
        final response = await http.post(
          Uri.parse('${ApiConstants.backendUrl}/api/task'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        );

        if (response.statusCode == 201) {
          final json = jsonDecode(response.body);
          final serverTask = json['data'] as Map<String, dynamic>?;

          await _removeFromQueue(tempId);
          synced++;

          if (serverTask != null) {
            onTaskSynced?.call(tempId, serverTask);
          }

          debugPrint(
              '✅ [OfflineSync] Synced "$tempId" → ${serverTask?['_id']}');
        } else {
          debugPrint(
              '⚠️ [OfflineSync] Server returned ${response.statusCode} for '
              '"$tempId" — keeping in queue');
        }
      } catch (e) {
        debugPrint('❌ [OfflineSync] Network error for "$tempId": $e');
        // Stop trying remaining items — we're probably still offline
        break;
      }
    }

    await _refreshPendingCount();

    _isSyncing = false;
    notifyListeners();

    if (synced > 0) {
      debugPrint('🔄 [OfflineSync] Done — synced $synced tasks, '
          '$_pendingCount still pending');
      onSyncComplete?.call();
    }
  }

  /// Clear the entire queue (e.g. on logout).
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    _pendingCount = 0;
    notifyListeners();
  }
}
