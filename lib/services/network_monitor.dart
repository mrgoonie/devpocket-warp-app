import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network monitoring service for tracking connectivity and quality
class NetworkMonitor {
  static NetworkMonitor? _instance;
  static NetworkMonitor get instance => _instance ??= NetworkMonitor._();

  NetworkMonitor._() {
    _initialize();
  }

  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkState> _networkStateController = StreamController.broadcast();
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _qualityCheckTimer;
  
  NetworkState _currentState = NetworkState.unknown();

  /// Stream of network state changes
  Stream<NetworkState> get networkStateStream => _networkStateController.stream;

  /// Current network state
  NetworkState get currentState => _currentState;

  /// Check if device has internet connectivity
  bool get hasConnectivity => _currentState.isConnected;

  /// Check if connection quality is good enough for SSH
  bool get isGoodForSsh => _currentState.isGoodForSsh;

  void _initialize() {
    // Start monitoring connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        debugPrint('[NetworkMonitor] Connectivity stream error: $error');
      },
    );

    // Start periodic quality checks
    _qualityCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkNetworkQuality(),
    );

    // Initial network state check
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _onConnectivityChanged(result);
    } catch (e) {
      debugPrint('[NetworkMonitor] Initial connectivity check failed: $e');
      _updateNetworkState(NetworkState.disconnected());
    }
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    debugPrint('[NetworkMonitor] Connectivity changed: $results');
    
    try {
      // Determine primary connection type
      final primaryResult = results.isNotEmpty ? results.first : ConnectivityResult.none;
      final connectionType = _mapConnectivityResult(primaryResult);
      
      if (connectionType == NetworkConnectionType.none) {
        _updateNetworkState(NetworkState.disconnected());
        return;
      }

      // Check actual internet connectivity
      final hasInternet = await _checkInternetConnectivity();
      if (!hasInternet) {
        _updateNetworkState(NetworkState.noInternet(connectionType));
        return;
      }

      // Check network quality
      final quality = await _measureNetworkQuality();
      _updateNetworkState(NetworkState.connected(
        connectionType: connectionType,
        quality: quality,
      ));

    } catch (e) {
      debugPrint('[NetworkMonitor] Error handling connectivity change: $e');
      _updateNetworkState(NetworkState.error(e.toString()));
    }
  }

  NetworkConnectionType _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return NetworkConnectionType.wifi;
      case ConnectivityResult.mobile:
        return NetworkConnectionType.mobile;
      case ConnectivityResult.ethernet:
        return NetworkConnectionType.ethernet;
      case ConnectivityResult.bluetooth:
        return NetworkConnectionType.bluetooth;
      case ConnectivityResult.vpn:
        return NetworkConnectionType.vpn;
      case ConnectivityResult.other:
        return NetworkConnectionType.other;
      case ConnectivityResult.none:
        return NetworkConnectionType.none;
    }
  }

  Future<bool> _checkInternetConnectivity() async {
    try {
      // Try to connect to a reliable endpoint
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('[NetworkMonitor] Internet connectivity check failed: $e');
      return false;
    }
  }

  Future<NetworkQuality> _measureNetworkQuality() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Simple network quality test - ping a reliable server
      await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      
      stopwatch.stop();
      final responseTime = stopwatch.elapsedMilliseconds;

      // Classify quality based on response time
      if (responseTime < 100) {
        return NetworkQuality.excellent;
      } else if (responseTime < 300) {
        return NetworkQuality.good;
      } else if (responseTime < 800) {
        return NetworkQuality.fair;
      } else {
        return NetworkQuality.poor;
      }

    } catch (e) {
      debugPrint('[NetworkMonitor] Network quality measurement failed: $e');
      return NetworkQuality.poor;
    }
  }

  Future<void> _checkNetworkQuality() async {
    if (_currentState.status != NetworkStatus.connected) return;

    try {
      final quality = await _measureNetworkQuality();
      if (quality != _currentState.quality) {
        final updatedState = _currentState.copyWith(quality: quality);
        _updateNetworkState(updatedState);
      }
    } catch (e) {
      debugPrint('[NetworkMonitor] Periodic quality check failed: $e');
    }
  }

  void _updateNetworkState(NetworkState newState) {
    if (_currentState != newState) {
      final previousState = _currentState;
      _currentState = newState;
      
      debugPrint('[NetworkMonitor] Network state changed: ${previousState.status} -> ${newState.status}');
      
      if (!_networkStateController.isClosed) {
        _networkStateController.add(newState);
      }
    }
  }

  /// Manually trigger network quality check
  Future<NetworkQuality> checkNetworkQuality() async {
    final quality = await _measureNetworkQuality();
    final updatedState = _currentState.copyWith(
      quality: quality,
      lastChecked: DateTime.now(),
    );
    _updateNetworkState(updatedState);
    return quality;
  }

  /// Check if network is suitable for SSH connections
  Future<bool> isNetworkSuitableForSsh() async {
    if (!hasConnectivity) return false;
    
    try {
      // Test connection to a common SSH port (22)
      final socket = await Socket.connect('google.com', 80)
          .timeout(const Duration(seconds: 5));
      socket.destroy();
      return true;
    } catch (e) {
      debugPrint('[NetworkMonitor] SSH suitability check failed: $e');
      return false;
    }
  }

  /// Get network recommendations for SSH connections
  List<String> getNetworkRecommendations() {
    final recommendations = <String>[];
    
    if (!hasConnectivity) {
      recommendations.addAll([
        'Check your network connection',
        'Try connecting to WiFi or mobile data',
        'Restart your network adapter',
      ]);
      return recommendations;
    }

    switch (_currentState.quality) {
      case NetworkQuality.poor:
        recommendations.addAll([
          'Network quality is poor - connections may be unstable',
          'Try moving closer to WiFi router',
          'Consider switching to a different network',
          'Close other apps using network',
        ]);
        break;
      case NetworkQuality.fair:
        recommendations.addAll([
          'Network quality is fair - some delays expected',
          'Consider using WiFi instead of mobile data',
          'Close bandwidth-heavy apps',
        ]);
        break;
      case NetworkQuality.good:
      case NetworkQuality.excellent:
        recommendations.add('Network quality is good for SSH connections');
        break;
      case NetworkQuality.unknown:
        recommendations.add('Network quality is being assessed...');
        break;
    }

    if (_currentState.connectionType == NetworkConnectionType.mobile) {
      recommendations.addAll([
        'Using mobile data - data charges may apply',
        'Consider connecting to WiFi for better stability',
      ]);
    }

    return recommendations;
  }

  /// Dispose resources
  void dispose() {
    debugPrint('[NetworkMonitor] Disposing network monitor');
    
    _connectivitySubscription?.cancel();
    _qualityCheckTimer?.cancel();
    _networkStateController.close();
  }
}

/// Network connection state
@immutable
class NetworkState {
  final NetworkStatus status;
  final NetworkConnectionType connectionType;
  final NetworkQuality quality;
  final String? errorMessage;
  final DateTime lastChecked;

  const NetworkState({
    required this.status,
    required this.connectionType,
    required this.quality,
    this.errorMessage,
    required this.lastChecked,
  });

  factory NetworkState.unknown() {
    return NetworkState(
      status: NetworkStatus.unknown,
      connectionType: NetworkConnectionType.none,
      quality: NetworkQuality.unknown,
      lastChecked: DateTime.now(),
    );
  }

  factory NetworkState.disconnected() {
    return NetworkState(
      status: NetworkStatus.disconnected,
      connectionType: NetworkConnectionType.none,
      quality: NetworkQuality.unknown,
      lastChecked: DateTime.now(),
    );
  }

  factory NetworkState.noInternet(NetworkConnectionType connectionType) {
    return NetworkState(
      status: NetworkStatus.noInternet,
      connectionType: connectionType,
      quality: NetworkQuality.unknown,
      lastChecked: DateTime.now(),
    );
  }

  factory NetworkState.connected({
    required NetworkConnectionType connectionType,
    required NetworkQuality quality,
  }) {
    return NetworkState(
      status: NetworkStatus.connected,
      connectionType: connectionType,
      quality: quality,
      lastChecked: DateTime.now(),
    );
  }

  factory NetworkState.error(String error) {
    return NetworkState(
      status: NetworkStatus.error,
      connectionType: NetworkConnectionType.none,
      quality: NetworkQuality.unknown,
      errorMessage: error,
      lastChecked: DateTime.now(),
    );
  }

  /// Check if device is connected to internet
  bool get isConnected => status == NetworkStatus.connected;

  /// Check if connection quality is good enough for SSH
  bool get isGoodForSsh => isConnected && 
      (quality == NetworkQuality.excellent || 
       quality == NetworkQuality.good ||
       quality == NetworkQuality.fair);

  /// Get user-friendly status description
  String get statusDescription {
    switch (status) {
      case NetworkStatus.unknown:
        return 'Network status unknown';
      case NetworkStatus.disconnected:
        return 'No network connection';
      case NetworkStatus.noInternet:
        return 'Connected to ${connectionType.displayName} but no internet access';
      case NetworkStatus.connected:
        return 'Connected via ${connectionType.displayName} (${quality.displayName} quality)';
      case NetworkStatus.error:
        return 'Network error: ${errorMessage ?? "Unknown error"}';
    }
  }

  /// Get quality indicator emoji
  String get qualityEmoji {
    switch (quality) {
      case NetworkQuality.excellent:
        return '🟢';
      case NetworkQuality.good:
        return '🟡';
      case NetworkQuality.fair:
        return '🟠';
      case NetworkQuality.poor:
        return '🔴';
      case NetworkQuality.unknown:
        return '⚪';
    }
  }

  NetworkState copyWith({
    NetworkStatus? status,
    NetworkConnectionType? connectionType,
    NetworkQuality? quality,
    String? errorMessage,
    DateTime? lastChecked,
  }) {
    return NetworkState(
      status: status ?? this.status,
      connectionType: connectionType ?? this.connectionType,
      quality: quality ?? this.quality,
      errorMessage: errorMessage ?? this.errorMessage,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkState &&
        other.status == status &&
        other.connectionType == connectionType &&
        other.quality == quality &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(status, connectionType, quality, errorMessage);
  }

  @override
  String toString() {
    return 'NetworkState(status: $status, type: $connectionType, quality: $quality)';
  }
}

/// Network status enumeration
enum NetworkStatus {
  unknown,
  disconnected,
  noInternet,
  connected,
  error,
}

/// Network connection type
enum NetworkConnectionType {
  none,
  wifi,
  mobile,
  ethernet,
  bluetooth,
  vpn,
  other,
}

extension NetworkConnectionTypeExtension on NetworkConnectionType {
  String get displayName {
    switch (this) {
      case NetworkConnectionType.none:
        return 'None';
      case NetworkConnectionType.wifi:
        return 'WiFi';
      case NetworkConnectionType.mobile:
        return 'Mobile Data';
      case NetworkConnectionType.ethernet:
        return 'Ethernet';
      case NetworkConnectionType.bluetooth:
        return 'Bluetooth';
      case NetworkConnectionType.vpn:
        return 'VPN';
      case NetworkConnectionType.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case NetworkConnectionType.none:
        return '❌';
      case NetworkConnectionType.wifi:
        return '📶';
      case NetworkConnectionType.mobile:
        return '📱';
      case NetworkConnectionType.ethernet:
        return '🔌';
      case NetworkConnectionType.bluetooth:
        return '🔵';
      case NetworkConnectionType.vpn:
        return '🔒';
      case NetworkConnectionType.other:
        return '🌐';
    }
  }
}

/// Network quality levels
enum NetworkQuality {
  excellent,
  good,
  fair,
  poor,
  unknown,
}

extension NetworkQualityExtension on NetworkQuality {
  String get displayName {
    switch (this) {
      case NetworkQuality.excellent:
        return 'Excellent';
      case NetworkQuality.good:
        return 'Good';
      case NetworkQuality.fair:
        return 'Fair';
      case NetworkQuality.poor:
        return 'Poor';
      case NetworkQuality.unknown:
        return 'Unknown';
    }
  }

  String get emoji {
    switch (this) {
      case NetworkQuality.excellent:
        return '🟢';
      case NetworkQuality.good:
        return '🟡';
      case NetworkQuality.fair:
        return '🟠';
      case NetworkQuality.poor:
        return '🔴';
      case NetworkQuality.unknown:
        return '⚪';
    }
  }
}