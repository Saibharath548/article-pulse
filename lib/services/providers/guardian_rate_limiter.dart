import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Enforces The Guardian developer API rate limits:
/// 1. Maximum 500 requests per calendar day (UTC).
/// 2. Throttled to at most 1 request per second to avoid HTTP 429 errors.
class GuardianRateLimiter {
  static const int maxRequestsPerDay = 500;
  static const Duration minInterval = Duration(milliseconds: 1050); // slightly > 1 sec
  static const String _prefDailyCountKey = 'guardian_api_req_count';
  static const String _prefDateKey = 'guardian_api_req_date';

  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _todayCount = 0;
  String _todayDateStr = '';
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayUtcString();
    final storedDate = prefs.getString(_prefDateKey) ?? '';

    if (storedDate == today) {
      _todayCount = prefs.getInt(_prefDailyCountKey) ?? 0;
    } else {
      _todayCount = 0;
      await prefs.setString(_prefDateKey, today);
      await prefs.setInt(_prefDailyCountKey, 0);
    }
    _todayDateStr = today;
    _initialized = true;
  }

  String _getTodayUtcString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns remaining requests allowed for today.
  Future<int> getRemainingRequestsToday() async {
    await _ensureInitialized();
    final today = _getTodayUtcString();
    if (_todayDateStr != today) {
      _todayDateStr = today;
      _todayCount = 0;
    }
    return (maxRequestsPerDay - _todayCount).clamp(0, maxRequestsPerDay);
  }

  /// Checks if another request is permitted today under the 500 quota.
  Future<bool> canMakeRequest() async {
    final remaining = await getRemainingRequestsToday();
    return remaining > 0;
  }

  /// Waits if needed to respect the 1 request/second throttle, then increments quota count.
  Future<void> acquire() async {
    await _ensureInitialized();

    final today = _getTodayUtcString();
    if (_todayDateStr != today) {
      _todayDateStr = today;
      _todayCount = 0;
    }

    if (_todayCount >= maxRequestsPerDay) {
      throw Exception('The Guardian API developer quota reached ($maxRequestsPerDay requests/day). Resets at 00:00 UTC.');
    }

    // Rate throttle (1 req/sec)
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequestTime);
    if (elapsed < minInterval) {
      final waitMs = (minInterval - elapsed).inMilliseconds;
      await Future.delayed(Duration(milliseconds: waitMs));
    }

    _lastRequestTime = DateTime.now();
    _todayCount++;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDateKey, _todayDateStr);
    await prefs.setInt(_prefDailyCountKey, _todayCount);
  }
}
