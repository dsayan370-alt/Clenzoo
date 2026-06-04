import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class CallService {
  static final CallService _i = CallService._();
  static CallService get instance => _i;
  CallService._();

  static const String apiBase = 'https://clenzoo.com/login/call_log_api.php';

  final _notif = FlutterLocalNotificationsPlugin();
  StreamSubscription? _sub;
  DateTime? _callStart;
  String _number = '';
  bool _active = false;

  // ── init ──────────────────────────────────────────────
  static Future<void> init() async {
    await instance._initNotif();
    await instance._requestPerms();
    instance._listenCalls();
  }

  Future<void> _initNotif() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notif.initialize(const InitializationSettings(android: android, iOS: ios));
  }

  Future<void> _requestPerms() async {
    await [
      Permission.phone,
      Permission.callLog,
      Permission.notification,
    ].request();
  }

  // ── Listen to phone state changes ─────────────────────
  void _listenCalls() {
    _sub = PhoneState.stream.listen((state) {
      switch (state.status) {
        case PhoneStateStatus.CALL_STARTED:
          _callStart = DateTime.now();
          _active = true;
          if ((state.number ?? '').isNotEmpty) _number = state.number!;
          break;

        case PhoneStateStatus.CALL_ENDED:
          if (_active && _callStart != null) {
            final dur = DateTime.now().difference(_callStart!).inSeconds;
            final start = _callStart!.toIso8601String();
            final end = DateTime.now().toIso8601String();
            _active = false;
            _sendLog(_number, dur, 'outgoing', start, end);
            _callStart = null;
          }
          break;

        default:
          break;
      }
    });
  }

  // ── Make a call ────────────────────────────────────────
  Future<void> dial(String number) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    _number = clean;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Send log to server ─────────────────────────────────
  Future<void> _sendLog(String contact, int durSec, String type,
      String start, String end) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('agent_token') ?? '';
    if (token.isEmpty) {
      await _saveOffline(contact, durSec, type, start, end);
      return;
    }
    try {
      final res = await http.post(
        Uri.parse('$apiBase?action=log_call'),
        headers: {'Content-Type': 'application/json', 'X-Agent-Token': token},
        body: jsonEncode({
          'contact': contact,
          'duration_seconds': durSec,
          'call_type': type,
          'call_start': start,
          'call_end': end,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final msg = data['message'] as String? ?? 'Call logged';
        final valid = data['is_valid'] as bool? ?? false;
        final comm = (data['commission'] as num?)?.toDouble() ?? 0;
        _notify(
          valid ? '✅ Valid Call  +₹${comm.toStringAsFixed(0)}' : '📞 Call Logged',
          '$msg  |  ${durSec}s',
          valid,
        );
      }
    } catch (_) {
      await _saveOffline(contact, durSec, type, start, end);
    }
  }

  // ── Notification ───────────────────────────────────────
  Future<void> _notify(String title, String body, bool success) async {
    await _notif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'cz_calls', 'Call Tracker',
          channelDescription: 'Clenzoo call tracking',
          importance: Importance.high, priority: Priority.high,
          color: success ? Colors.green : Colors.blue,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  // ── Offline queue ──────────────────────────────────────
  Future<void> _saveOffline(String contact, int dur, String type,
      String start, String end) async {
    final prefs = await SharedPreferences.getInstance();
    final q = prefs.getStringList('offline_q') ?? [];
    q.add(jsonEncode({'contact': contact, 'duration_seconds': dur,
        'call_type': type, 'call_start': start, 'call_end': end}));
    await prefs.setStringList('offline_q', q);
  }

  Future<void> retryOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final q = prefs.getStringList('offline_q') ?? [];
    if (q.isEmpty) return;
    final token = prefs.getString('agent_token') ?? '';
    if (token.isEmpty) return;
    final failed = <String>[];
    for (final item in q) {
      try {
        final d = jsonDecode(item) as Map<String, dynamic>;
        await _sendLog(d['contact'], d['duration_seconds'],
            d['call_type'], d['call_start'], d['call_end']);
      } catch (_) {
        failed.add(item);
      }
    }
    await prefs.setStringList('offline_q', failed);
  }

  // ── API helpers ────────────────────────────────────────
  static Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('agent_token') ?? '';
    if (token.isEmpty) return {};
    try {
      final res = await http.get(
        Uri.parse('$apiBase?action=get_stats'),
        headers: {'X-Agent-Token': token},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        return (b['today'] as Map<String, dynamic>?) ?? {};
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('agent_token') ?? '';
    if (token.isEmpty) return {};
    try {
      final res = await http.get(
        Uri.parse('$apiBase?action=get_settings'),
        headers: {'X-Agent-Token': token},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('agent_token') ?? '';
    if (token.isEmpty) return [];
    try {
      final res = await http.get(
        Uri.parse('$apiBase?action=get_history&limit=30'),
        headers: {'X-Agent-Token': token},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        return ((b['logs'] as List?) ?? []).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }
}
