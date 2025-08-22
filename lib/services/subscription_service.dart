import 'package:flutter/foundation.dart';

import '../models/subscription_models.dart';
import 'api_client.dart';

/// Subscription management service
class SubscriptionService {
  static SubscriptionService? _instance;
  static SubscriptionService get instance => _instance ??= SubscriptionService._();
  
  final ApiClient _apiClient = ApiClient.instance;
  
  SubscriptionService._();
  
  /// Get current subscription status
  Future<SubscriptionStatus?> getCurrentSubscription() async {
    try {
      final response = await _apiClient.get<SubscriptionStatus>(
        '/subscriptions/current',
        fromJson: (json) => SubscriptionStatus.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Get subscription failed: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Error getting subscription: $e');
      return null;
    }
  }
  
  /// Get subscription status (similar to current but different endpoint)
  Future<SubscriptionStatus?> getSubscriptionStatus() async {
    try {
      final response = await _apiClient.get<SubscriptionStatus>(
        '/subscriptions/status',
        fromJson: (json) => SubscriptionStatus.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Get subscription status failed: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Error getting subscription status: $e');
      return null;
    }
  }
  
  /// Get available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/subscriptions/plans',
      );
      
      if (response.isSuccess && response.data != null) {
        return response.data!
            .map((json) => SubscriptionPlan.fromJson(json))
            .toList();
      }
      
      debugPrint('Get plans failed: ${response.errorMessage}');
      return [];
    } catch (e) {
      debugPrint('Error getting subscription plans: $e');
      return [];
    }
  }
  
  /// Get payment history
  Future<List<PaymentHistoryEntry>> getPaymentHistory() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/subscriptions/history',
      );
      
      if (response.isSuccess && response.data != null) {
        return response.data!
            .map((json) => PaymentHistoryEntry.fromJson(json))
            .toList();
      }
      
      debugPrint('Get payment history failed: ${response.errorMessage}');
      return [];
    } catch (e) {
      debugPrint('Error getting payment history: $e');
      return [];
    }
  }
  
  /// Cancel current subscription
  Future<bool> cancelSubscription() async {
    try {
      final response = await _apiClient.post('/subscriptions/cancel');
      
      if (response.isSuccess) {
        return true;
      }
      
      debugPrint('Cancel subscription failed: ${response.errorMessage}');
      return false;
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return false;
    }
  }
  
  /// Check feature usage limits
  Future<FeatureUsage?> getFeatureUsage(String feature) async {
    try {
      final response = await _apiClient.get<FeatureUsage>(
        '/subscriptions/usage/$feature',
        fromJson: (json) => FeatureUsage.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Get feature usage failed: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Error getting feature usage: $e');
      return null;
    }
  }
  
  /// Create free subscription (for new users)
  Future<bool> createFreeSubscription() async {
    try {
      final response = await _apiClient.post('/subscriptions/free');
      
      if (response.isSuccess) {
        return true;
      }
      
      debugPrint('Create free subscription failed: ${response.errorMessage}');
      return false;
    } catch (e) {
      debugPrint('Error creating free subscription: $e');
      return false;
    }
  }
  
  /// Process RevenueCat transaction
  Future<bool> processRevenueCatTransaction(Map<String, dynamic> transactionData) async {
    try {
      final response = await _apiClient.post(
        '/subscriptions/revenuecat-transaction',
        data: transactionData,
      );
      
      if (response.isSuccess) {
        return true;
      }
      
      debugPrint('Process RevenueCat transaction failed: ${response.errorMessage}');
      return false;
    } catch (e) {
      debugPrint('Error processing RevenueCat transaction: $e');
      return false;
    }
  }
  
  /// Check if user can use a specific feature
  Future<bool> canUseFeature(String feature) async {
    final usage = await getFeatureUsage(feature);
    if (usage == null) return false;
    
    return !usage.isAtLimit;
  }
  
  /// Get payment service health
  Future<bool> isPaymentServiceHealthy() async {
    try {
      final response = await _apiClient.get('/payment/health');
      return response.isSuccess;
    } catch (e) {
      debugPrint('Payment service health check failed: $e');
      return false;
    }
  }
}