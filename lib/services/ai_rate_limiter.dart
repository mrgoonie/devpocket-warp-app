import 'dart:async';

import 'ai_service_models.dart';

/// Handles rate limiting for AI API requests
class AIRateLimiter {
  final RateLimitState _state;

  AIRateLimiter({
    int maxRequestsPerMinute = 20,
  }) : _state = RateLimitState(
         requestTimes: [],
         maxRequestsPerMinute: maxRequestsPerMinute,
       );

  /// Check if we can make a request right now
  bool canMakeRequest() {
    return _state.canMakeRequest();
  }

  /// Get how long to wait before next request
  Duration getWaitTime() {
    return _state.getWaitTime();
  }

  /// Wait if necessary, then record the request
  Future<void> checkRateLimit() async {
    final waitTime = getWaitTime();
    
    if (waitTime > Duration.zero) {
      // Wait for the required time
      await Future.delayed(waitTime);
    }
    
    // Record this request
    _state.recordRequest();
  }

  /// Record a request without waiting (for immediate recording)
  void recordRequest() {
    _state.recordRequest();
  }

  /// Get current rate limit statistics
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    
    // Clean old requests
    _state.requestTimes.removeWhere((time) => time.isBefore(oneMinuteAgo));
    
    return {
      'requestsInLastMinute': _state.requestTimes.length,
      'maxRequestsPerMinute': _state.maxRequestsPerMinute,
      'canMakeRequest': canMakeRequest(),
      'waitTime': getWaitTime().inSeconds,
      'resetTime': _state.requestTimes.isNotEmpty 
          ? _state.requestTimes.first.add(const Duration(minutes: 1)).toIso8601String()
          : null,
    };
  }

  /// Reset rate limiting state
  void reset() {
    _state.requestTimes.clear();
  }

  /// Update maximum requests per minute
  void updateLimit(int newLimit) {
    // Note: This would require modifying RateLimitState to be mutable
    // For now, this is a placeholder for future enhancement
  }
}