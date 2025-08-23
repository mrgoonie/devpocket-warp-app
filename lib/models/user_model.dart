class User {
  final String id;
  final String username;
  final String email;
  final bool emailVerified;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Subscription information
  final String subscriptionTier; // 'free', 'pro', 'team', 'enterprise'
  final bool isInTrial;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionEndsAt;
  
  // Settings
  final bool twoFactorEnabled;
  final bool emailNotifications;
  final bool pushNotifications;
  
  // Profile information
  final String? firstName;
  final String? lastName;
  final String? bio;
  final String? company;
  final String? location;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.emailVerified = false,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.subscriptionTier = 'free',
    this.isInTrial = false,
    this.trialEndsAt,
    this.subscriptionEndsAt,
    this.twoFactorEnabled = false,
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.firstName,
    this.lastName,
    this.bio,
    this.company,
    this.location,
  });

  User copyWith({
    String? id,
    String? username,
    String? email,
    bool? emailVerified,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? subscriptionTier,
    bool? isInTrial,
    DateTime? trialEndsAt,
    DateTime? subscriptionEndsAt,
    bool? twoFactorEnabled,
    bool? emailNotifications,
    bool? pushNotifications,
    String? firstName,
    String? lastName,
    String? bio,
    String? company,
    String? location,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      isInTrial: isInTrial ?? this.isInTrial,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      subscriptionEndsAt: subscriptionEndsAt ?? this.subscriptionEndsAt,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      bio: bio ?? this.bio,
      company: company ?? this.company,
      location: location ?? this.location,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      emailVerified: json['email_verified'] ?? json['emailVerified'] ?? false,
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['updatedAt'] ?? json['created_at'] ?? json['createdAt']),
      subscriptionTier: json['subscription_tier'] ?? json['subscriptionTier'] ?? 'free',
      isInTrial: json['is_in_trial'] ?? json['isInTrial'] ?? false,
      trialEndsAt: json['trial_ends_at'] != null || json['trialEndsAt'] != null
          ? DateTime.parse(json['trial_ends_at'] ?? json['trialEndsAt']) 
          : null,
      subscriptionEndsAt: json['subscription_ends_at'] != null || json['subscriptionEndsAt'] != null
          ? DateTime.parse(json['subscription_ends_at'] ?? json['subscriptionEndsAt']) 
          : null,
      twoFactorEnabled: json['two_factor_enabled'] ?? json['twoFactorEnabled'] ?? false,
      emailNotifications: json['email_notifications'] ?? json['emailNotifications'] ?? true,
      pushNotifications: json['push_notifications'] ?? json['pushNotifications'] ?? true,
      firstName: json['first_name'] ?? json['firstName'],
      lastName: json['last_name'] ?? json['lastName'],
      bio: json['bio'],
      company: json['company'],
      location: json['location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'emailVerified': emailVerified,
      'avatar_url': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'subscription_tier': subscriptionTier,
      'is_in_trial': isInTrial,
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'subscription_ends_at': subscriptionEndsAt?.toIso8601String(),
      'two_factor_enabled': twoFactorEnabled,
      'email_notifications': emailNotifications,
      'push_notifications': pushNotifications,
      'first_name': firstName,
      'last_name': lastName,
      'bio': bio,
      'company': company,
      'location': location,
    };
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return username;
  }

  bool get isSubscribed {
    return subscriptionTier != 'free' && 
           (subscriptionEndsAt == null || subscriptionEndsAt!.isAfter(DateTime.now()));
  }

  bool get hasActiveSubscription {
    return isInTrial || isSubscribed;
  }

  int get trialDaysLeft {
    if (!isInTrial || trialEndsAt == null) return 0;
    final difference = trialEndsAt!.difference(DateTime.now());
    return difference.inDays.clamp(0, double.infinity).toInt();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'User{id: $id, username: $username, email: $email, subscriptionTier: $subscriptionTier}';
  }
}

// Authentication state
enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  loading,
  error,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get hasError => error != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.error == error &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return Object.hash(status, user, error, isLoading);
  }

  @override
  String toString() {
    return 'AuthState{status: $status, user: $user, error: $error, isLoading: $isLoading}';
  }
}