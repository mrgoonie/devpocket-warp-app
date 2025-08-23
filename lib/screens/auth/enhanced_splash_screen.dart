import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../themes/app_theme.dart';
import '../../services/app_initialization_service.dart';
import '../../services/auth_persistence_service.dart';
import '../../main.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import '../main/main_tab_screen.dart';

/// Enhanced splash screen with app initialization
class EnhancedSplashScreen extends ConsumerStatefulWidget {
  const EnhancedSplashScreen({super.key});

  @override
  ConsumerState<EnhancedSplashScreen> createState() => _EnhancedSplashScreenState();
}

class _EnhancedSplashScreenState extends ConsumerState<EnhancedSplashScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _logoController;
  late AnimationController _progressController;
  late Animation<double> _logoAnimation;
  late Animation<double> _progressAnimation;

  String _currentStatus = 'Starting up...';
  double _progress = 0.0;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    // Logo animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );

    // Progress animation
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    // Start logo animation
    _logoController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      final initService = AppInitializationService.instance;

      // Listen to initialization status
      late StreamSubscription<String> statusSubscription;
      statusSubscription = initService.statusStream.listen((status) {
        if (mounted) {
          setState(() {
            _currentStatus = status;
            _progress = _calculateProgress(status);
          });
          _progressController.forward();
        }
      });

      // Add a minimum splash time for better UX
      final initFuture = initService.initialize();
      final minTimeFuture = Future.delayed(const Duration(seconds: 2));

      final results = await Future.wait([initFuture, minTimeFuture]);
      final initResult = results[0] as AppInitializationResult;

      statusSubscription.cancel();

      if (mounted) {
        if (initResult.isSuccess) {
          await _navigateToInitialScreen(initResult.initialRoute ?? '/login');
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = initResult.message;
            _currentStatus = 'Initialization failed';
          });
        }
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Startup error: $e';
          _currentStatus = 'Something went wrong';
        });
      }
    }
  }

  double _calculateProgress(String status) {
    // Map status messages to progress values
    if (status.contains('Starting')) return 0.1;
    if (status.contains('secure storage')) return 0.2;
    if (status.contains('onboarding')) return 0.4;
    if (status.contains('authentication')) return 0.6;
    if (status.contains('session')) return 0.8;
    if (status.contains('route')) return 0.9;
    if (status.contains('completed')) return 1.0;
    return _progress;
  }

  Future<void> _navigateToInitialScreen(String route) async {
    // Add a small delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    Widget destination;
    switch (route) {
      case '/onboarding':
        destination = const OnboardingScreen();
        break;
      case '/main':
        destination = const MainTabScreen();
        break;
      case '/login':
      default:
        destination = const LoginScreen();
        break;
    }

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _currentStatus = 'Retrying...';
      _progress = 0.0;
    });

    // Reset the initialization service
    await AppInitializationService.instance.reset();
    
    // Restart initialization
    await _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkBackground,
              AppTheme.darkSurface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Spacer(flex: 2),
                
                // Logo Section
                AnimatedBuilder(
                  animation: _logoAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoAnimation.value,
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.terminal,
                              size: 64,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'DevPocket',
                            style: context.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI-Powered Mobile Terminal',
                            style: context.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const Spacer(flex: 2),

                // Status Section
                if (_hasError) ...[
                  _buildErrorSection(),
                ] else ...[
                  _buildLoadingSection(),
                ],

                const Spacer(),

                // Version and Credits
                Column(
                  children: [
                    Text(
                      'Version ${AppConstants.appVersion}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Built with ❤️ for Developers',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      children: [
        // Progress Bar
        Container(
          width: double.infinity,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.darkBorderColor,
            borderRadius: BorderRadius.circular(3),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // Status Text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _currentStatus,
            key: ValueKey(_currentStatus),
            style: context.textTheme.bodyLarge?.copyWith(
              color: AppTheme.darkTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 16),

        // Loading Spinner
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection() {
    return Column(
      children: [
        // Error Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.terminalRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppTheme.terminalRed.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.error_outline,
            color: AppTheme.terminalRed,
            size: 32,
          ),
        ),

        const SizedBox(height: 24),

        // Error Title
        Text(
          'Initialization Failed',
          style: context.textTheme.titleLarge?.copyWith(
            color: AppTheme.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        // Error Message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.terminalRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.terminalRed.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _errorMessage!,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 24),

        // Retry Button
        ElevatedButton.icon(
          onPressed: _retryInitialization,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }
}