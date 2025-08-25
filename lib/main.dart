import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'screens/auth/splash_screen.dart';
import 'screens/terminal/terminal_screen.dart';
import 'screens/vaults/vaults_screen.dart';
import 'themes/app_theme.dart';
import 'providers/theme_provider.dart';
import 'services/secure_storage_service.dart';
import 'models/ssh_profile_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize secure storage service first
  try {
    debugPrint('Initializing SecureStorageService...');
    await SecureStorageService.instance.initialize();
    debugPrint('✅ SecureStorageService initialized successfully');
  } catch (e) {
    debugPrint('❌ SecureStorageService initialization failed: $e');
    // Continue with app startup even if secure storage fails
    // This allows the app to run with basic storage fallback
  }
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: DevPocketApp(),
    ),
  );
}

class DevPocketApp extends ConsumerWidget {
  const DevPocketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    
    return MaterialApp(
      title: 'DevPocket',
      debugShowCheckedModeBanner: false,
      
      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      
      // Home screen
      home: const SplashScreen(),
      
      // Global navigation
      navigatorKey: GlobalKey<NavigatorState>(),
      
      // Error handling
      builder: (context, child) {
        // Global error boundary
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return _buildErrorWidget(context, errorDetails);
        };
        
        return child ?? const SizedBox.shrink();
      },
      
      // Route configuration
      onGenerateRoute: _onGenerateRoute,
      
      // Localization (future implementation)
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      locale: const Locale('en', 'US'),
    );
  }

  Widget _buildErrorWidget(BuildContext context, FlutterErrorDetails errorDetails) {
    return Material(
      child: Container(
        color: AppTheme.darkBackground,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.terminalRed,
              ),
              const SizedBox(height: 16),
              const Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please restart the app or contact support if the problem persists.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Restart app
                  SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Restart App'),
              ),
              const SizedBox(height: 16),
              if (errorDetails.exception.toString().isNotEmpty) ...[
                const Text(
                  'Error Details:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorderColor),
                  ),
                  child: Text(
                    errorDetails.exception.toString(),
                    style: const TextStyle(
                      fontFamily: AppTheme.terminalFont,
                      fontSize: 10,
                      color: AppTheme.terminalRed,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Route generator function for handling navigation with arguments
Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  debugPrint('[Navigation] Generating route: ${settings.name}');
  
  switch (settings.name) {
    case '/terminal':
      final sshProfile = settings.arguments as SshProfile?;
      debugPrint('[Navigation] Terminal route with SSH profile: ${sshProfile?.name ?? 'null'}');
      return MaterialPageRoute(
        builder: (context) => TerminalScreen(sshProfile: sshProfile),
        settings: settings,
      );
    
    case '/vaults':
      return MaterialPageRoute(
        builder: (context) => const VaultsScreen(),
        settings: settings,
      );
    
    case '/':
      return MaterialPageRoute(
        builder: (context) => const SplashScreen(),
        settings: settings,
      );
    
    default:
      debugPrint('[Navigation] ❌ Unknown route: ${settings.name}');
      return null;
  }
}

// App-wide error handling
class AppErrorHandler {
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log error to crash reporting service (future implementation)
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack Trace: ${details.stack}');
    };
  }
  
  static void handleError(Object error, StackTrace stackTrace) {
    // Log error to crash reporting service (future implementation)
    debugPrint('Dart Error: $error');
    debugPrint('Stack Trace: $stackTrace');
  }
}

// Global constants
class AppConstants {
  static const String appName = 'DevPocket';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  
  // API Configuration (moved to ApiConfig)
  static const String openRouterUrl = 'https://openrouter.ai/api/v1';
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String onboardingCompletedKey = 'onboarding_completed';
  static const String openRouterApiKeyKey = 'openrouter_api_key';
  
  // Secure Storage Instance
  static const secureStorage = FlutterSecureStorage();
}

// Global utility functions
extension BuildContextExtensions on BuildContext {
  bool get isDarkMode {
    return Theme.of(this).brightness == Brightness.dark;
  }
  
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  
  TextTheme get textTheme => Theme.of(this).textTheme;
  
  Size get screenSize => MediaQuery.of(this).size;
  
  EdgeInsets get padding => MediaQuery.of(this).padding;
  
  double get statusBarHeight => MediaQuery.of(this).padding.top;
  
  double get bottomSafeArea => MediaQuery.of(this).padding.bottom;
  
  bool get isKeyboardVisible => MediaQuery.of(this).viewInsets.bottom > 0;
}