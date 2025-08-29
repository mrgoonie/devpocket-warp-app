# DevPocket Flutter App - Code Structure and Standards

**Version**: 1.0.0  
**Last Updated**: August 29, 2025  
**Status**: Production Ready

## Table of Contents

1. [Overview](#overview)
2. [Code Structure Standards](#code-structure-standards)
3. [Coding Standards](#coding-standards)
4. [Security Standards](#security-standards)
5. [Architecture Patterns](#architecture-patterns)
6. [Development Practices](#development-practices)
7. [Performance Guidelines](#performance-guidelines)
8. [Testing Standards](#testing-standards)
9. [Documentation Standards](#documentation-standards)

## Overview

This document establishes the coding standards, file organization patterns, and development best practices for the DevPocket Flutter application. These standards ensure code consistency, maintainability, security, and performance across the codebase.

**Key Principles:**
- **Security First**: All sensitive data must be encrypted and properly handled
- **Performance Optimized**: Mobile-first approach with memory and battery optimization
- **Maintainable**: Clear structure and consistent patterns
- **Testable**: Code designed for comprehensive testing coverage
- **Scalable**: Architecture supports future enhancements

## Code Structure Standards

### Directory Organization

The codebase follows a feature-based architecture with clear separation of concerns:

```
lib/
├── config/                     # App configuration and constants
├── models/                     # Data models and DTOs
├── providers/                  # Riverpod state providers
├── screens/                    # UI screens organized by feature
├── services/                   # Business logic and external APIs
├── widgets/                    # Reusable UI components
├── themes/                     # App theming and design system
└── utils/                      # Utility functions and helpers
```

#### Detailed Directory Structure

**1. Config (`lib/config/`)**
```dart
config/
└── api_config.dart            # API endpoints and configuration
```

**2. Models (`lib/models/`)**
```dart
models/
├── ai_*.dart                  # AI service models
├── ssh_*.dart                 # SSH related models  
├── user_*.dart                # User and authentication models
├── enhanced_*.dart            # Enhanced feature models
└── api_response.dart          # Generic API response wrapper
```

**3. Providers (`lib/providers/`)**
```dart
providers/
├── auth_provider.dart         # Authentication state
├── terminal_*.dart            # Terminal state management
├── ssh_*.dart                 # SSH connection providers
└── theme_provider.dart        # Theme state management
```

**4. Screens (`lib/screens/`)**
```dart
screens/
├── auth/                      # Authentication screens
├── main/                      # Main app navigation
├── terminal/                  # Terminal interface
├── vaults/                    # SSH host management
├── settings/                  # App settings
└── ssh_keys/                  # SSH key management
```

**5. Services (`lib/services/`)**
```dart
services/
├── api/                       # API client layers
├── auth_*.dart                # Authentication services
├── ai_*.dart                  # AI service integration
├── ssh_*.dart                 # SSH functionality
├── terminal_*.dart            # Terminal services
├── secure_*.dart              # Security services
└── crypto_service.dart        # Cryptographic operations
```

**6. Widgets (`lib/widgets/`)**
```dart
widgets/
├── terminal/                  # Terminal-specific widgets
├── common_widgets.dart        # Reusable components
└── security_widgets.dart      # Security UI components
```

### File Naming Conventions

#### Standard Naming Rules
- **Files**: Use snake_case for all Dart files
- **Classes**: Use PascalCase
- **Variables**: Use camelCase
- **Constants**: Use camelCase with descriptive names
- **Enums**: Use PascalCase with descriptive values

#### Examples
```dart
// ✅ Good file names
secure_storage_service.dart
enhanced_ssh_models.dart
terminal_block_widget.dart

// ❌ Avoid
SecureStorageService.dart
enhanced-ssh-models.dart
terminalBlockWidget.dart
```

#### Service File Patterns
```dart
// Service files should end with _service.dart
auth_persistence_service.dart
secure_storage_service.dart
ssh_connection_manager.dart

// Provider files should end with _provider.dart
auth_provider.dart
terminal_session_provider.dart

// Model files should end with _models.dart
enhanced_ssh_models.dart
user_models.dart
```

### Import Organization Standards

Imports must be organized in the following order with blank lines between groups:

```dart
// 1. Dart SDK imports
import 'dart:async';
import 'dart:convert';

// 2. Flutter framework imports  
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// 3. Third-party package imports (alphabetical)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 4. Local imports (alphabetical, relative paths)
import '../models/user_model.dart';
import '../services/api_client.dart';
import 'secure_storage_service.dart';
```

## Coding Standards

### Dart/Flutter Code Style Guidelines

#### Class Structure Pattern
```dart
/// Documentation comment describing the class purpose
class ServiceName {
  // 1. Static members and constants
  static const String _privateConstant = 'value';
  static ServiceName? _instance;
  
  // 2. Instance variables (private first)
  final String _privateField;
  final PublicType publicField;
  
  // 3. Constructor(s)
  ServiceName._({
    required String privateField,
    required this.publicField,
  }) : _privateField = privateField;
  
  // 4. Factory constructors and named constructors
  factory ServiceName.create() => ServiceName._(/* ... */);
  
  // 5. Getters and setters
  String get privateField => _privateField;
  
  // 6. Public methods
  Future<Result> publicMethod() async {
    // Implementation
  }
  
  // 7. Private methods
  Future<void> _privateMethod() async {
    // Implementation
  }
  
  // 8. Overrides
  @override
  String toString() => 'ServiceName(field: $_privateField)';
}
```

#### Error Handling Patterns

**Consistent Error Handling:**
```dart
try {
  final result = await riskyOperation();
  return ApiResponse.success(result);
} catch (e, stackTrace) {
  debugPrint('ServiceName.methodName error: $e');
  if (kDebugMode) {
    debugPrint('Stack trace: $stackTrace');
  }
  return ApiResponse.error('Operation failed: ${e.toString()}');
}
```

**Service Layer Error Pattern:**
```dart
Future<ServiceResult<T>> serviceMethod() async {
  try {
    // Validate inputs
    if (invalidInput) {
      return ServiceResult.error('Validation failed');
    }
    
    // Perform operation
    final result = await operation();
    
    // Return success
    return ServiceResult.success(result);
  } catch (e) {
    debugPrint('Error in ${runtimeType}.serviceMethod: $e');
    return ServiceResult.error('Operation failed: $e');
  }
}
```

#### State Management Patterns (Riverpod)

**Provider Structure:**
```dart
// Service provider
final serviceProvider = Provider<ServiceName>((ref) {
  return ServiceName.instance;
});

// State provider with proper disposal
final stateProvider = StateNotifierProvider<StateController, StateType>((ref) {
  final service = ref.watch(serviceProvider);
  final controller = StateController(service);
  
  ref.onDispose(() {
    controller.dispose();
  });
  
  return controller;
});

// Stream provider for reactive updates
final streamProvider = StreamProvider<DataType>((ref) {
  final service = ref.watch(serviceProvider);
  return service.dataStream;
});
```

#### Model Structure Standards

**Immutable Data Models:**
```dart
class DataModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const DataModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  // Copy constructor for immutable updates
  DataModel copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return DataModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // JSON serialization
  factory DataModel.fromJson(Map<String, dynamic> json) {
    return DataModel(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DataModel(id: $id, name: $name)';
}
```

#### Widget Organization Standards

**Widget Structure Pattern:**
```dart
class CustomWidget extends StatelessWidget {
  // 1. Final properties
  final String title;
  final VoidCallback? onTap;
  final bool isEnabled;

  // 2. Constructor with key parameter
  const CustomWidget({
    super.key,
    required this.title,
    this.onTap,
    this.isEnabled = true,
  });

  // 3. Build method
  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        child: _buildContent(context),
      ),
    );
  }

  // 4. Private helper methods
  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: isEnabled 
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }
}
```

## Security Standards

### Secure Storage Practices

**Sensitive Data Handling:**
```dart
class SecureDataHandler {
  // ✅ Store sensitive data encrypted
  Future<void> storeSensitiveData(String key, String data) async {
    await _secureStorage.storeSecure(
      key: key,
      value: data,
      requireBiometric: true, // For highly sensitive data
    );
  }
  
  // ✅ Clear sensitive data from memory
  void clearSensitiveString(String sensitive) {
    // Overwrite string data in memory
    _cryptoService.clearSensitiveData(sensitive.codeUnits);
  }
  
  // ❌ Never store plain text passwords
  // String password = 'plain_password'; // DON'T DO THIS
  
  // ✅ Store hashed passwords
  String passwordHash = await hashPassword(password);
}
```

**Authentication Implementation Patterns:**
```dart
class AuthenticationService {
  // JWT token management
  Future<void> storeTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await _secureStorage.storeAuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      expiresAt: _calculateExpirationTime(),
    );
  }
  
  // Automatic token refresh
  Future<bool> refreshTokensIfNeeded() async {
    final tokens = await _secureStorage.getAuthTokens();
    if (tokens == null) return false;
    
    // Check if token is expiring soon (5 minutes buffer)
    if (_isTokenExpiringSoon(tokens['expires_at'])) {
      return await _refreshTokens();
    }
    
    return true;
  }
}
```

### API Key Management

**BYOK (Bring Your Own Key) Pattern:**
```dart
class ApiKeyManager {
  // Store API keys securely
  Future<void> storeApiKey(String keyName, String apiKey) async {
    await _secureStorage.storeAPIKey(
      keyName: keyName,
      apiKey: apiKey,
      requireBiometric: false, // User preference
    );
    
    // Clear from memory immediately
    _cryptoService.clearSensitiveData(apiKey.codeUnits);
  }
  
  // Retrieve and validate API keys
  Future<String?> getValidApiKey(String keyName) async {
    final apiKey = await _secureStorage.getAPIKey(keyName);
    
    if (apiKey == null || apiKey.isEmpty) return null;
    
    // Validate key format (optional)
    if (!_isValidApiKeyFormat(apiKey)) {
      debugPrint('Invalid API key format for $keyName');
      return null;
    }
    
    return apiKey;
  }
}
```

### Biometric Authentication Standards

**Implementation Pattern:**
```dart
class BiometricAuthService {
  Future<bool> authenticateWithBiometrics({
    required String reason,
    bool biometricOnly = false,
  }) async {
    try {
      // Check availability first
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) return false;
      
      // Get available biometrics
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return false;
      
      // Authenticate
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }
}
```

## Architecture Patterns

### Service Singleton Patterns

**Service Implementation:**
```dart
class ServiceTemplate {
  // Singleton pattern with lazy initialization
  static ServiceTemplate? _instance;
  static ServiceTemplate get instance => _instance ??= ServiceTemplate._();
  
  ServiceTemplate._();
  
  // Dependencies
  final ApiClient _apiClient = ApiClient.instance;
  final SecureStorageService _secureStorage = SecureStorageService.instance;
  
  // Internal state
  bool _initialized = false;
  
  // Initialization
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialize dependencies
      await _secureStorage.initialize();
      
      // Service-specific initialization
      await _performServiceInit();
      
      _initialized = true;
      debugPrint('✅ ${runtimeType} initialized');
    } catch (e) {
      debugPrint('❌ ${runtimeType} initialization failed: $e');
      rethrow;
    }
  }
  
  // Proper disposal
  Future<void> dispose() async {
    // Cleanup resources
    _initialized = false;
  }
  
  Future<void> _performServiceInit() async {
    // Service-specific initialization logic
  }
}
```

### Provider Organization

**Hierarchical Provider Structure:**
```dart
// Core service providers (rarely change)
final coreServiceProviders = [
  secureStorageServiceProvider,
  cryptoServiceProvider,
  authPersistenceServiceProvider,
];

// Feature-specific providers
final sshFeatureProviders = [
  sshHostServiceProvider,
  sshConnectionManagerProvider,
  sshKeyManagementServiceProvider,
];

// UI state providers (may change frequently)
final uiStateProviders = [
  terminalModeProvider,
  activeBlockProvider,
  themeProvider,
];
```

### Model Structure Standards

**Enhanced Model Pattern:**
```dart
// Base model interface
abstract class BaseModel {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  
  Map<String, dynamic> toJson();
  
  @override
  bool operator ==(Object other);
  
  @override
  int get hashCode;
}

// Enhanced model with security features
class SecureModel extends BaseModel {
  @override
  final String id;
  final String name;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  
  // Security features
  final SecurityLevel securityLevel;
  final bool requiresBiometric;
  final DateTime? lastSecurityAudit;
  final Map<String, dynamic> complianceFlags;
  
  const SecureModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.securityLevel = SecurityLevel.medium,
    this.requiresBiometric = false,
    this.lastSecurityAudit,
    this.complianceFlags = const {},
  });
  
  // Security assessment
  SecurityRisk get securityRisk {
    // Implementation for risk calculation
    return SecurityRisk.medium;
  }
}
```

### Widget Composition Guidelines

**Composite Widget Pattern:**
```dart
class FeatureScreen extends ConsumerWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context, ref),
      floatingActionButton: _buildFAB(context, ref),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Feature'),
      actions: [
        _buildAppBarActions(context),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    // Watch relevant providers
    final state = ref.watch(featureStateProvider);
    
    return state.when(
      data: (data) => _buildContent(context, data),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => _buildErrorState(context, error),
    );
  }

  Widget _buildContent(BuildContext context, FeatureData data) {
    return Column(
      children: [
        _buildHeader(context, data),
        Expanded(child: _buildList(context, data)),
      ],
    );
  }
}
```

## Development Practices

### Testing Requirements

**Test Structure Standards:**
```dart
// Test file structure
void main() {
  group('ServiceName', () {
    late ServiceName service;
    late MockDependency mockDependency;
    
    setUp(() {
      mockDependency = MockDependency();
      service = ServiceName(dependency: mockDependency);
    });
    
    tearDown(() {
      service.dispose();
    });
    
    group('initialization', () {
      test('should initialize successfully', () async {
        // Given
        when(mockDependency.initialize()).thenAnswer((_) async {});
        
        // When
        await service.initialize();
        
        // Then
        expect(service.isInitialized, true);
        verify(mockDependency.initialize()).called(1);
      });
    });
    
    group('error handling', () {
      test('should handle initialization failure gracefully', () async {
        // Given
        when(mockDependency.initialize()).thenThrow(Exception('Init failed'));
        
        // When & Then
        expect(
          () => service.initialize(),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
```

### Documentation Standards

**Code Documentation Pattern:**
```dart
/// Service for managing SSH connections with enhanced security features.
/// 
/// This service provides:
/// - Secure connection establishment
/// - Host key verification
/// - Connection health monitoring
/// - Automatic reconnection
/// 
/// Example usage:
/// ```dart
/// final sshService = SSHConnectionService.instance;
/// await sshService.initialize();
/// 
/// final result = await sshService.connect(hostProfile);
/// if (result.isSuccess) {
///   // Connection established
/// }
/// ```
class SSHConnectionService {
  /// Creates a new SSH connection to the specified host.
  /// 
  /// Parameters:
  /// - [hostProfile]: The SSH host configuration
  /// - [timeout]: Connection timeout (defaults to 30 seconds)
  /// 
  /// Returns a [ConnectionResult] indicating success or failure.
  /// 
  /// Throws:
  /// - [SSHException] if connection parameters are invalid
  /// - [SecurityException] if host key verification fails
  Future<ConnectionResult> connect(
    HostProfile hostProfile, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Implementation
  }
}
```

### Git Commit Message Format

**Conventional Commit Pattern:**
```bash
# Format: <type>(<scope>): <description>
# Types: feat, fix, docs, style, refactor, test, chore

# Examples:
feat(auth): add biometric authentication support
fix(terminal): resolve vi editor dimension race condition  
refactor(ssh): improve connection error handling
docs(api): update SSH service documentation
test(crypto): add AES encryption unit tests
chore(deps): update flutter_secure_storage to v9.0.0

# Breaking changes:
feat(auth)!: migrate to new authentication flow

# Multi-line for complex changes:
feat(terminal): implement fullscreen modal for interactive commands

- Add fullscreen terminal modal widget
- Implement proper keyboard handling
- Add escape key detection for vi/vim
- Update terminal session management
```

### Code Review Checklist

**Security Review Points:**
- [ ] No hardcoded API keys or credentials
- [ ] Sensitive data is encrypted before storage
- [ ] Input validation is implemented
- [ ] Error messages don't leak sensitive information
- [ ] Authentication is properly validated
- [ ] Biometric authentication is correctly implemented

**Code Quality Review:**
- [ ] Code follows established patterns
- [ ] Error handling is comprehensive
- [ ] Memory leaks are prevented (proper disposal)
- [ ] Performance implications are considered
- [ ] Documentation is updated
- [ ] Tests are added/updated

## Performance Guidelines

### Memory Management Patterns

**Resource Disposal:**
```dart
class ResourceManager {
  StreamController<Data>? _controller;
  Timer? _timer;
  SSHConnection? _connection;
  
  void initialize() {
    _controller = StreamController<Data>.broadcast();
    _timer = Timer.periodic(Duration(seconds: 30), _periodicTask);
  }
  
  Future<void> dispose() async {
    // Dispose in reverse order of creation
    _timer?.cancel();
    _timer = null;
    
    await _connection?.disconnect();
    _connection = null;
    
    await _controller?.close();
    _controller = null;
  }
  
  void _periodicTask(Timer timer) {
    // Task implementation
  }
}
```

### Network Optimization

**Connection Pooling Pattern:**
```dart
class NetworkManager {
  final Map<String, Connection> _connectionPool = {};
  static const int maxConnections = 5;
  
  Future<Connection> getConnection(String host) async {
    final key = _generateConnectionKey(host);
    
    // Reuse existing connection if available
    if (_connectionPool.containsKey(key)) {
      final connection = _connectionPool[key]!;
      if (connection.isActive) {
        return connection;
      } else {
        _connectionPool.remove(key);
      }
    }
    
    // Create new connection if under limit
    if (_connectionPool.length < maxConnections) {
      final connection = await _createConnection(host);
      _connectionPool[key] = connection;
      return connection;
    }
    
    // Remove oldest connection and create new one
    _evictOldestConnection();
    final connection = await _createConnection(host);
    _connectionPool[key] = connection;
    return connection;
  }
}
```

### Storage Optimization

**Efficient Key-Value Operations:**
```dart
class OptimizedStorage {
  final Map<String, dynamic> _cache = {};
  Timer? _cacheCleanupTimer;
  
  Future<T?> get<T>(String key) async {
    // Check cache first
    if (_cache.containsKey(key)) {
      return _cache[key] as T?;
    }
    
    // Read from storage
    final value = await _secureStorage.read(key: key);
    if (value != null) {
      // Cache for future reads
      _cache[key] = value;
      _scheduleCleanup();
      return value as T?;
    }
    
    return null;
  }
  
  Future<void> set<T>(String key, T value) async {
    // Update cache
    _cache[key] = value;
    
    // Write to storage asynchronously
    unawaited(_secureStorage.write(key: key, value: value.toString()));
  }
  
  void _scheduleCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer(Duration(minutes: 5), () {
      _cache.clear();
    });
  }
}
```

## Testing Standards

### Unit Test Requirements

**Service Testing Pattern:**
```dart
group('AuthPersistenceService', () {
  late AuthPersistenceService service;
  late MockSecureStorage mockStorage;
  late MockApiClient mockApiClient;
  
  setUp(() {
    mockStorage = MockSecureStorage();
    mockApiClient = MockApiClient();
    service = AuthPersistenceService(
      secureStorage: mockStorage,
      apiClient: mockApiClient,
    );
  });
  
  test('should login successfully with valid credentials', () async {
    // Given
    const email = 'test@example.com';
    const password = 'password123';
    final mockUser = User(id: '1', email: email);
    
    when(mockApiClient.post('/auth/login', data: anyNamed('data')))
      .thenAnswer((_) async => ApiResponse.success({
        'user': mockUser.toJson(),
        'accessToken': 'access_token',
        'refreshToken': 'refresh_token',
      }));
    
    when(mockStorage.storeAuthTokens(
      accessToken: anyNamed('accessToken'),
      refreshToken: anyNamed('refreshToken'),
      userId: anyNamed('userId'),
    )).thenAnswer((_) async {});
    
    // When
    final result = await service.login(email: email, password: password);
    
    // Then
    expect(result.isSuccess, true);
    expect(result.user, mockUser);
    verify(mockStorage.storeAuthTokens(
      accessToken: 'access_token',
      refreshToken: 'refresh_token',
      userId: '1',
    )).called(1);
  });
});
```

### Integration Test Standards

**Full Feature Flow Testing:**
```dart
void main() {
  group('SSH Connection Integration', () {
    testWidgets('should establish SSH connection and execute command', 
      (WidgetTester tester) async {
      // Given
      const testHost = HostProfile(/* test configuration */);
      
      // Build app
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      
      // Navigate to SSH screen
      await tester.tap(find.byKey(Key('ssh_tab')));
      await tester.pumpAndSettle();
      
      // Select host
      await tester.tap(find.text(testHost.name));
      await tester.pumpAndSettle();
      
      // Wait for connection
      await tester.pump(Duration(seconds: 5));
      
      // Verify connection established
      expect(find.text('Connected'), findsOneWidget);
      
      // Execute command
      await tester.enterText(find.byKey(Key('command_input')), 'ls -la');
      await tester.tap(find.byKey(Key('execute_button')));
      await tester.pumpAndSettle();
      
      // Verify command output
      expect(find.textContaining('total'), findsOneWidget);
    });
  });
}
```

## Documentation Standards

### API Documentation

**Service Documentation Template:**
```dart
/// Service for managing encrypted SSH keys with biometric protection.
/// 
/// This service handles:
/// - SSH key generation with secure algorithms
/// - Encrypted storage with hardware-backed security
/// - Key retrieval with biometric authentication
/// - Key lifecycle management
/// 
/// ## Security Features
/// 
/// - AES-256-GCM encryption for private keys
/// - Hardware security module integration where available
/// - Biometric authentication for high-security keys
/// - Secure memory clearing after use
/// 
/// ## Usage Example
/// 
/// ```dart
/// final keyService = SSHKeyManagementService.instance;
/// await keyService.initialize();
/// 
/// // Generate new key
/// final result = await keyService.generateKey(
///   name: 'production-server',
///   type: KeyType.ed25519,
///   requiresBiometric: true,
/// );
/// 
/// if (result.isSuccess) {
///   print('Key generated: ${result.key.fingerprint}');
/// }
/// ```
/// 
/// ## Error Handling
/// 
/// All methods return [ServiceResult] objects that encapsulate
/// success/failure states and provide detailed error information.
/// 
/// ## Thread Safety
/// 
/// This service is thread-safe and can be called from multiple
/// isolates simultaneously.
class SSHKeyManagementService {
  // Implementation
}
```

---

## Conclusion

These standards ensure that the DevPocket Flutter application maintains high code quality, security, and performance while remaining maintainable and scalable. All team members should follow these guidelines consistently.

**Key Takeaways:**
- **Security First**: Always encrypt sensitive data and validate inputs
- **Consistent Patterns**: Follow established service and provider patterns
- **Comprehensive Testing**: Write tests for all business logic
- **Clear Documentation**: Document public APIs and complex logic
- **Performance Aware**: Consider memory and network optimization
- **Error Handling**: Implement robust error handling throughout

For questions or clarifications about these standards, refer to the architecture and development guide documents, or consult with the development team.