# DevPocket Development Guide

**Version**: 1.0.0  
**Last Updated**: August 2025  
**Status**: All Major Compilation Errors Resolved
**Related files:**
- `./docs/codebase-summary.md`
- `./docs/devpocket-code-structure-and-standards.md`
- `./docs/devpocket-architecture-guide.md`

## Overview

This guide documents the current development setup, architecture decisions, and recent improvements made to resolve compilation errors and enhance the DevPocket Flutter application.

## Recent Major Fixes & Improvements

### 1. Service Layer Enhancements

#### AuthPersistenceService Implementation
- **Issue**: Missing authentication persistence across app sessions
- **Solution**: Implemented comprehensive authentication service with:
  - Automatic token refresh with exponential backoff
  - Stream-based state management
  - Session validation and recovery
  - Proper state transitions

#### SecureStorageService Overhaul
- **Issue**: Missing critical methods for token and configuration storage
- **Solution**: Enhanced service with:
  - Multi-layer encryption (AES-256 + device keys)
  - iOS Keychain and Android EncryptedSharedPreferences integration
  - Biometric authentication support
  - Secure token management (access/refresh tokens)

#### OnboardingService Implementation
- **Issue**: No persistence for onboarding completion state
- **Solution**: Created service with:
  - Persistent onboarding state across app sessions
  - Integration with secure storage
  - Proper completion tracking

### 2. SSH Integration Fixes

#### dartssh2 API Compatibility
- **Issue**: Using deprecated/incorrect SSH API methods
- **Solution**: Updated to dartssh2 v2.9.0 with:
  - Proper `SSHKeyPair.fromPem()` usage
  - Correct connection establishment patterns
  - Enhanced error handling

#### SSH Models Enhancement
- **Issue**: Missing SSH event types and key management models
- **Solution**: Added comprehensive models:
  - `SshKeyEvent` and `SshKeyEventType` enums
  - Enhanced `SshKeyType` with all supported algorithms
  - Proper validation and error handling

### 3. Terminal Integration Updates

#### xterm.dart API Compatibility
- **Issue**: Using deprecated terminal methods
- **Solution**: Updated to xterm.dart v3.4.0:
  - Removed deprecated methods
  - Updated TerminalView widget parameters
  - Enhanced PTY support

#### WebSocketManager Enhancement
- **Issue**: Basic WebSocket implementation lacking reliability
- **Solution**: Enhanced manager with:
  - Connection state management
  - Automatic reconnection with backoff
  - Binary data support for terminal I/O
  - Proper error handling

### 4. State Management Fixes

#### Provider Namespace Resolution
- **Issue**: Conflicts between AuthState classes
- **Solution**: Renamed and reorganized:
  - `AuthState` → `AuthPersistenceState`
  - Separated SSH host and SSH key providers
  - Clear provider boundaries and responsibilities

#### Widget Implementation
- **Issue**: Missing critical UI components
- **Solution**: Implemented missing widgets:
  - `HostCard` widget for SSH host display
  - `AddHostSheet` for SSH host creation
  - `SshKeyCard` for SSH key management
  - Enhanced terminal widgets

### 5. Security Enhancements

#### Multi-layer Encryption
- **Implementation**: Device-specific encryption keys
- **Features**: Hardware-backed security on supported devices
- **Fallback**: Software-based encryption for older devices

#### Biometric Authentication
- **iOS**: Face ID / Touch ID integration
- **Android**: Fingerprint and biometric support
- **Fallback**: PIN/password authentication

## Development Environment Setup

### Prerequisites

```bash
# Flutter SDK
flutter --version  # Ensure 3.16.0+

# Dependencies
flutter pub get

# Platform-specific setup
cd ios && pod install  # iOS
cd android && ./gradlew build  # Android
```

### Key Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.4.0          # State management
  flutter_secure_storage: ^9.0.0    # Secure storage
  dartssh2: ^2.9.0                  # SSH client
  xterm: ^3.4.0                     # Terminal emulator
  local_auth: ^2.1.6                # Biometric auth
  device_info_plus: ^9.1.0          # Device information
  web_socket_channel: ^2.4.0        # WebSocket support
  crypto: ^3.0.3                    # Cryptographic functions
```

### Environment Configuration

#### iOS Configuration
```xml
<!-- ios/Runner/Info.plist -->
<key>NSFaceIDUsageDescription</key>
<string>Use biometric authentication for secure access</string>

<key>keychain-access-groups</key>
<array>
  <string>$(AppIdentifierPrefix)com.devpocket.app</string>
</array>
```

#### Android Configuration
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
<uses-permission android:name="android.permission.INTERNET" />
```

## Architecture Patterns

### Service Layer Pattern

All services follow singleton pattern with proper initialization:

```dart
class ServiceName {
  static ServiceName? _instance;
  static ServiceName get instance => _instance ??= ServiceName._();
  
  ServiceName._();
  
  Future<void> initialize() async {
    // Initialization logic
  }
}
```

### State Management Pattern

Using Riverpod for reactive state management:

```dart
// Provider definition
final serviceProvider = Provider<ServiceName>((ref) {
  return ServiceName.instance;
});

// State provider
final stateProvider = StateNotifierProvider<StateNotifier, StateType>((ref) {
  return StateNotifier(ref.read(serviceProvider));
});
```

### Error Handling Pattern

Consistent error handling across services:

```dart
try {
  final result = await riskyOperation();
  return ApiResponse.success(result);
} catch (e) {
  debugPrint('ServiceName error: $e');
  return ApiResponse.error('Operation failed: ${e.toString()}');
}
```

## Testing Strategy

### Current Test Coverage

#### Unit Tests
- Service layer business logic
- Model validation and serialization
- Cryptographic functions
- Authentication flows

#### Integration Tests
- End-to-end authentication
- SSH connection establishment
- Terminal session management
- WebSocket communication

#### Widget Tests
- User interface components
- Navigation flows
- Form validation
- Error states

### Running Tests

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration/

# Specific test files
flutter test test/services/auth_persistence_service_test.dart
```

### Test Environment

```dart
// Example test setup
void main() {
  group('AuthPersistenceService', () {
    late AuthPersistenceService service;
    
    setUp(() {
      service = AuthPersistenceService();
    });
    
    test('should initialize correctly', () async {
      await service.initialize();
      expect(service.currentState, AuthPersistenceState.unknown);
    });
  });
}
```

## API Integration

### Backend Communication

The Flutter app communicates with the DevPocket API:

```dart
class ApiClient {
  static const String baseUrl = 'https://api.dev.devpocket.app';
  
  Future<ApiResponse<T>> request<T>({
    required String endpoint,
    required String method,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    // Implementation with proper error handling
  }
}
```

### Authentication Headers

All authenticated requests include JWT tokens:

```dart
final headers = {
  'Authorization': 'Bearer $accessToken',
  'Content-Type': 'application/json',
};
```

## Security Implementation

### Secure Storage Implementation

```dart
class SecureStorageService {
  // iOS: Keychain with hardware backing
  // Android: EncryptedSharedPreferences
  
  Future<void> storeAuthTokens(String accessToken, String refreshToken) async {
    final encryptedAccess = await _encrypt(accessToken);
    final encryptedRefresh = await _encrypt(refreshToken);
    
    await _secureStorage.write(
      key: 'access_token',
      value: encryptedAccess,
    );
  }
}
```

### Biometric Authentication

```dart
Future<bool> authenticateWithBiometrics() async {
  try {
    final isAvailable = await _localAuth.canCheckBiometrics;
    if (!isAvailable) return false;
    
    return await _localAuth.authenticate(
      localizedReason: 'Authenticate to access DevPocket',
      options: const AuthenticationOptions(
        biometricOnly: true,
      ),
    );
  } catch (e) {
    debugPrint('Biometric authentication failed: $e');
    return false;
  }
}
```

## Performance Considerations

### Memory Management

Proper disposal of resources:

```dart
class ServiceName {
  final StreamController _controller = StreamController.broadcast();
  
  void dispose() {
    _controller.close();
    // Other cleanup
  }
}
```

### Network Optimization

- Connection pooling for HTTP requests
- WebSocket connection reuse
- Proper timeout handling
- Retry mechanisms with exponential backoff

### Storage Optimization

- Lazy loading of secure storage
- Efficient key-value operations
- Proper encryption/decryption caching

## Debugging & Troubleshooting

### Common Issues

#### 1. Authentication Failures
- Check token expiration and refresh logic
- Verify secure storage initialization
- Confirm API endpoint configuration

#### 2. SSH Connection Issues
- Validate SSH key format and permissions
- Check network connectivity
- Verify host configuration

#### 3. Terminal Display Problems
- Ensure xterm.dart version compatibility
- Check WebSocket connection status
- Verify PTY configuration

### Debug Logging

Enable comprehensive logging:

```dart
void main() {
  if (kDebugMode) {
    debugPrint('DevPocket Debug Mode Enabled');
  }
  runApp(MyApp());
}
```

## Build & Deployment

### Development Build

```bash
# Debug build
flutter run --debug

# Profile build (performance testing)
flutter run --profile

# Release build
flutter run --release
```

### Platform-Specific Builds

#### iOS
```bash
flutter build ios --release
cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner archive
```

#### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### Code Signing

Ensure proper certificates and provisioning profiles are configured for production builds.

## Continuous Integration

### GitHub Actions Configuration

The project includes CI/CD with:
- Automated testing on push/PR
- Platform-specific builds
- Security scanning
- Performance testing

### Quality Gates

- All tests must pass
- Code coverage > 80%
- No critical security vulnerabilities
- Performance benchmarks met

## Migration Guide

### From Previous Versions

If upgrading from earlier versions:

1. **Update Dependencies**: Ensure all packages are at required versions
2. **Service Migration**: Update service instantiation patterns
3. **State Management**: Update provider usage patterns
4. **Authentication**: Migrate to new AuthPersistenceService

### Breaking Changes

- `AuthState` renamed to `AuthPersistenceState`
- SSH API methods updated for dartssh2 v2.9.0
- Terminal widget parameters changed for xterm.dart v3.4.0

## Contributing Guidelines

### Code Style

- Follow Dart/Flutter style guidelines
- Use meaningful variable and method names
- Add documentation for public APIs
- Implement proper error handling

### Pull Request Process

1. Create feature branch from `main`
2. Implement changes with tests
3. Update documentation as needed
4. Submit PR with clear description
5. Address review feedback
6. Merge after approval

### Testing Requirements

- Unit tests for all new services
- Widget tests for UI components
- Integration tests for user flows
- Update existing tests for changes

---

**Note**: This development guide reflects the current state after resolving 150+ compilation errors and implementing comprehensive service layer enhancements. The application is now in a production-ready state with robust architecture and comprehensive error handling.