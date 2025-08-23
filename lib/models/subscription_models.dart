/// Subscription tier enumeration
enum SubscriptionTier {
  free('FREE'),
  pro('PRO'),
  team('TEAM');
  
  const SubscriptionTier(this.value);
  final String value;
  
  static SubscriptionTier fromString(String value) {
    return SubscriptionTier.values.firstWhere(
      (tier) => tier.value == value.toUpperCase(),
      orElse: () => SubscriptionTier.free,
    );
  }
}

/// Subscription status model
class SubscriptionStatus {
  final bool isActive;
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final SubscriptionLimits limits;
  
  const SubscriptionStatus({
    required this.isActive,
    required this.tier,
    this.expiresAt,
    required this.limits,
  });
  
  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isActive: json['is_active'] ?? json['isActive'] ?? false,
      tier: SubscriptionTier.fromString(json['tier'] ?? 'FREE'),
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'])
          : json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt'])
          : null,
      limits: SubscriptionLimits.fromJson(json['limits'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'is_active': isActive,
      'tier': tier.value,
      'expires_at': expiresAt?.toIso8601String(),
      'limits': limits.toJson(),
    };
  }
  
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isFree => tier == SubscriptionTier.free;
  bool get isPro => tier == SubscriptionTier.pro;
  bool get isTeam => tier == SubscriptionTier.team;
  
  @override
  String toString() {
    return 'SubscriptionStatus{tier: $tier, isActive: $isActive, expiresAt: $expiresAt}';
  }
}

/// Subscription limits model
class SubscriptionLimits {
  final int sshConnections; // -1 means unlimited
  final int aiRequests; // -1 means unlimited
  final bool cloudHistory;
  final bool multiDevice;
  
  const SubscriptionLimits({
    required this.sshConnections,
    required this.aiRequests,
    required this.cloudHistory,
    required this.multiDevice,
  });
  
  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) {
    return SubscriptionLimits(
      sshConnections: json['ssh_connections'] ?? json['sshConnections'] ?? 0,
      aiRequests: json['ai_requests'] ?? json['aiRequests'] ?? 0,
      cloudHistory: json['cloud_history'] ?? json['cloudHistory'] ?? false,
      multiDevice: json['multi_device'] ?? json['multiDevice'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'ssh_connections': sshConnections,
      'ai_requests': aiRequests,
      'cloud_history': cloudHistory,
      'multi_device': multiDevice,
    };
  }
  
  bool get hasUnlimitedSshConnections => sshConnections == -1;
  bool get hasUnlimitedAiRequests => aiRequests == -1;
  
  @override
  String toString() {
    return 'SubscriptionLimits{ssh: $sshConnections, ai: $aiRequests, cloudHistory: $cloudHistory, multiDevice: $multiDevice}';
  }
}

/// Subscription plan model
class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final SubscriptionTier tier;
  final double price;
  final String currency;
  final String interval; // 'monthly', 'yearly'
  final List<String> features;
  final SubscriptionLimits limits;
  final bool isPopular;
  
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.price,
    this.currency = 'USD',
    required this.interval,
    required this.features,
    required this.limits,
    this.isPopular = false,
  });
  
  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      tier: SubscriptionTier.fromString(json['tier']),
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] ?? 'USD',
      interval: json['interval'],
      features: List<String>.from(json['features'] ?? []),
      limits: SubscriptionLimits.fromJson(json['limits'] ?? {}),
      isPopular: json['isPopular'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'tier': tier.value,
      'price': price,
      'currency': currency,
      'interval': interval,
      'features': features,
      'limits': limits.toJson(),
      'isPopular': isPopular,
    };
  }
  
  String get priceDisplay {
    if (price == 0) return 'Free';
    return '\$${price.toStringAsFixed(2)}/$interval';
  }
  
  @override
  String toString() {
    return 'SubscriptionPlan{name: $name, tier: $tier, price: $priceDisplay}';
  }
}

/// Payment history entry
class PaymentHistoryEntry {
  final String id;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final String? description;
  final String? invoiceUrl;
  
  const PaymentHistoryEntry({
    required this.id,
    required this.amount,
    this.currency = 'USD',
    required this.status,
    required this.createdAt,
    this.description,
    this.invoiceUrl,
  });
  
  factory PaymentHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryEntry(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] ?? 'USD',
      status: json['status'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      description: json['description'],
      invoiceUrl: json['invoice_url'] ?? json['invoiceUrl'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'description': description,
      'invoice_url': invoiceUrl,
    };
  }
  
  String get amountDisplay => '\$${amount.toStringAsFixed(2)}';
  bool get isSuccessful => status.toLowerCase() == 'succeeded';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isFailed => status.toLowerCase() == 'failed';
  
  @override
  String toString() {
    return 'PaymentHistoryEntry{id: $id, amount: $amountDisplay, status: $status}';
  }
}

/// Feature usage model
class FeatureUsage {
  final String feature;
  final int used;
  final int limit; // -1 means unlimited
  final DateTime? resetDate;
  
  const FeatureUsage({
    required this.feature,
    required this.used,
    required this.limit,
    this.resetDate,
  });
  
  factory FeatureUsage.fromJson(Map<String, dynamic> json) {
    return FeatureUsage(
      feature: json['feature'],
      used: json['used'] ?? 0,
      limit: json['limit'] ?? 0,
      resetDate: json['reset_date'] != null 
          ? DateTime.parse(json['reset_date'])
          : json['resetDate'] != null 
          ? DateTime.parse(json['resetDate'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'feature': feature,
      'used': used,
      'limit': limit,
      'reset_date': resetDate?.toIso8601String(),
    };
  }
  
  bool get isUnlimited => limit == -1;
  bool get isAtLimit => !isUnlimited && used >= limit;
  double get usagePercentage => isUnlimited ? 0.0 : (used / limit).clamp(0.0, 1.0);
  int get remaining => isUnlimited ? -1 : (limit - used).clamp(0, limit);
  
  @override
  String toString() {
    return 'FeatureUsage{feature: $feature, used: $used, limit: $limit}';
  }
}