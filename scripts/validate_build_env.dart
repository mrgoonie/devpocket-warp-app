#!/usr/bin/env dart

/// DevPocket Build Environment Validation Script
/// 
/// This script validates that all required tools and dependencies
/// are properly installed and configured for DevPocket development.

import 'dart:io';
import 'dart:convert';

class ValidationResult {
  final bool isValid;
  final String message;
  final List<String> fixes;

  ValidationResult(this.isValid, this.message, [this.fixes = const []]);
}

class BuildEnvironmentValidator {
  final List<ValidationResult> _results = [];
  
  /// Main validation entry point
  Future<void> validateEnvironment() async {
    print('🔍 DevPocket Build Environment Validation');
    print('=' * 50);
    
    // Run all validations
    await _validateFlutter();
    await _validateJava();
    await _validateAndroid();
    await _validateiOS();
    await _validateProjectDependencies();
    
    // Display results
    _displayResults();
    
    // Exit with appropriate code
    final hasErrors = _results.any((r) => !r.isValid);
    exit(hasErrors ? 1 : 0);
  }
  
  /// Validate Flutter SDK installation and version
  Future<void> _validateFlutter() async {
    print('\n📱 Flutter SDK');
    print('-' * 20);
    
    try {
      // Check Flutter installation
      final flutterResult = await Process.run('flutter', ['--version']);
      if (flutterResult.exitCode != 0) {
        _results.add(ValidationResult(
          false,
          '❌ Flutter not found in PATH',
          ['Install Flutter SDK from https://flutter.dev/docs/get-started/install',
           'Add Flutter to your PATH environment variable']
        ));
        return;
      }
      
      // Parse Flutter version
      final versionOutput = flutterResult.stdout.toString();
      final versionMatch = RegExp(r'Flutter (\d+)\.(\d+)\.(\d+)').firstMatch(versionOutput);
      
      if (versionMatch == null) {
        _results.add(ValidationResult(
          false,
          '❌ Could not determine Flutter version',
          ['Run "flutter --version" to check installation']
        ));
        return;
      }
      
      final major = int.parse(versionMatch.group(1)!);
      final minor = int.parse(versionMatch.group(2)!);
      
      // Check minimum version (3.24.0)
      if (major < 3 || (major == 3 && minor < 24)) {
        _results.add(ValidationResult(
          false,
          '❌ Flutter version too old: ${versionMatch.group(0)}. Required: 3.24.0+',
          ['Update Flutter: "flutter upgrade"',
           'Or install Flutter 3.24.0+ from https://flutter.dev']
        ));
        return;
      }
      
      _results.add(ValidationResult(
        true,
        '✅ Flutter ${versionMatch.group(0)} (Channel: ${_extractChannel(versionOutput)})'
      ));
      
      // Check Flutter doctor
      await _runFlutterDoctor();
      
    } catch (e) {
      _results.add(ValidationResult(
        false,
        '❌ Error checking Flutter: $e',
        ['Ensure Flutter is properly installed and in PATH']
      ));
    }
  }
  
  /// Run flutter doctor and parse results
  Future<void> _runFlutterDoctor() async {
    try {
      final doctorResult = await Process.run('flutter', ['doctor', '--machine']);
      if (doctorResult.exitCode == 0) {
        final doctorData = jsonDecode(doctorResult.stdout.toString()) as List;
        
        for (final item in doctorData) {
          final Map<String, dynamic> check = item as Map<String, dynamic>;
          final String name = check['name'] ?? 'Unknown';
          final String status = check['status'] ?? 'unknown';
          
          if (status == 'installed') {
            print('  ✅ $name');
          } else if (status == 'partial') {
            print('  ⚠️  $name (partial)');
          } else {
            print('  ❌ $name');
          }
        }
      }
    } catch (e) {
      print('  ⚠️  Could not run flutter doctor: $e');
    }
  }
  
  /// Validate Java JDK installation
  Future<void> _validateJava() async {
    print('\n☕ Java JDK');
    print('-' * 20);
    
    try {
      final javaResult = await Process.run('java', ['-version']);
      final javacResult = await Process.run('javac', ['-version']);
      
      if (javaResult.exitCode != 0 || javacResult.exitCode != 0) {
        _results.add(ValidationResult(
          false,
          '❌ Java JDK not found',
          ['Install OpenJDK 17 from https://adoptium.net/',
           'Set JAVA_HOME environment variable',
           'Add Java to PATH']
        ));
        return;
      }
      
      // Parse Java version from stderr (java outputs version to stderr)
      final javaVersion = javaResult.stderr.toString();
      final versionMatch = RegExp(r'"(\d+)\.').firstMatch(javaVersion) ?? 
                          RegExp(r'version (\d+)').firstMatch(javaVersion);
      
      if (versionMatch == null) {
        _results.add(ValidationResult(
          false,
          '❌ Could not determine Java version',
          ['Run "java -version" to check installation']
        ));
        return;
      }
      
      final majorVersion = int.parse(versionMatch.group(1)!);
      
      if (majorVersion < 17) {
        _results.add(ValidationResult(
          false,
          '❌ Java version too old: $majorVersion. Required: 17+',
          ['Install Java 17 from https://adoptium.net/',
           'Set JAVA_HOME to Java 17 installation']
        ));
        return;
      }
      
      _results.add(ValidationResult(
        true,
        '✅ Java JDK $majorVersion'
      ));
      
      // Check JAVA_HOME
      final javaHome = Platform.environment['JAVA_HOME'];
      if (javaHome == null || javaHome.isEmpty) {
        _results.add(ValidationResult(
          false,
          '⚠️  JAVA_HOME environment variable not set',
          ['Set JAVA_HOME to your Java 17 installation directory']
        ));
      } else {
        print('  ✅ JAVA_HOME: $javaHome');
      }
      
    } catch (e) {
      _results.add(ValidationResult(
        false,
        '❌ Error checking Java: $e',
        ['Install OpenJDK 17 and ensure it\'s in PATH']
      ));
    }
  }
  
  /// Validate Android development environment
  Future<void> _validateAndroid() async {
    print('\n🤖 Android Development');
    print('-' * 20);
    
    // Check Android SDK
    final androidHome = Platform.environment['ANDROID_HOME'] ?? 
                       Platform.environment['ANDROID_SDK_ROOT'];
    
    if (androidHome == null || androidHome.isEmpty) {
      _results.add(ValidationResult(
        false,
        '❌ ANDROID_HOME environment variable not set',
        ['Install Android Studio or Android SDK command line tools',
         'Set ANDROID_HOME to your Android SDK directory',
         'Add Android SDK tools to PATH']
      ));
      return;
    }
    
    print('  ✅ ANDROID_HOME: $androidHome');
    
    // Check SDK directory exists
    final sdkDir = Directory(androidHome);
    if (!sdkDir.existsSync()) {
      _results.add(ValidationResult(
        false,
        '❌ Android SDK directory not found: $androidHome',
        ['Verify Android SDK installation',
         'Update ANDROID_HOME to correct path']
      ));
      return;
    }
    
    // Check platform-tools
    final platformTools = Directory('$androidHome/platform-tools');
    if (!platformTools.existsSync()) {
      _results.add(ValidationResult(
        false,
        '❌ Android platform-tools not found',
        ['Install platform-tools via Android Studio SDK Manager',
         'Or run: sdkmanager "platform-tools"']
      ));
    } else {
      print('  ✅ Platform-tools found');
    }
    
    // Check required API level (34)
    final platforms = Directory('$androidHome/platforms');
    if (!platforms.existsSync()) {
      _results.add(ValidationResult(
        false,
        '❌ Android platforms directory not found',
        ['Install Android SDK platforms via Android Studio']
      ));
    } else {
      final api34 = Directory('$androidHome/platforms/android-34');
      if (!api34.existsSync()) {
        _results.add(ValidationResult(
          false,
          '❌ Android API 34 not found',
          ['Install Android 14.0 (API 34) via Android Studio SDK Manager',
           'Or run: sdkmanager "platforms;android-34"']
        ));
      } else {
        print('  ✅ Android API 34 found');
      }
    }
    
    // Check build-tools
    final buildTools = Directory('$androidHome/build-tools');
    if (!buildTools.existsSync()) {
      _results.add(ValidationResult(
        false,
        '❌ Android build-tools not found',
        ['Install build-tools via Android Studio SDK Manager',
         'Or run: sdkmanager "build-tools;34.0.0"']
      ));
    } else {
      final buildToolsVersions = buildTools.listSync()
        .whereType<Directory>()
        .map((dir) => dir.path.split('/').last)
        .where((name) => name.startsWith('34.'))
        .toList();
      
      if (buildToolsVersions.isEmpty) {
        _results.add(ValidationResult(
          false,
          '❌ Android build-tools 34.x not found',
          ['Install build-tools 34.0.0 via Android Studio SDK Manager']
        ));
      } else {
        print('  ✅ Build-tools found: ${buildToolsVersions.join(', ')}');
      }
    }
    
    // Check Android NDK
    final ndk = Directory('$androidHome/ndk');
    if (!ndk.existsSync()) {
      _results.add(ValidationResult(
        false,
        '⚠️  Android NDK not found (may be required for some dependencies)',
        ['Install Android NDK via Android Studio SDK Manager',
         'Or run: sdkmanager "ndk;26.1.10909125"']
      ));
    } else {
      final ndkVersions = ndk.listSync()
        .whereType<Directory>()
        .map((dir) => dir.path.split('/').last)
        .where((name) => name.startsWith('26.'))
        .toList();
      
      if (ndkVersions.isNotEmpty) {
        print('  ✅ NDK found: ${ndkVersions.join(', ')}');
      } else {
        print('  ⚠️  NDK versions found but none are 26.x');
      }
    }
    
    // Check ADB connectivity
    try {
      final adbResult = await Process.run('adb', ['version']);
      if (adbResult.exitCode == 0) {
        print('  ✅ ADB available');
        
        // Check for connected devices
        final devicesResult = await Process.run('adb', ['devices']);
        if (devicesResult.exitCode == 0) {
          final devices = devicesResult.stdout.toString()
            .split('\n')
            .where((line) => line.contains('\tdevice'))
            .length;
          
          if (devices > 0) {
            print('  ✅ $devices Android device(s) connected');
          } else {
            print('  ⚠️  No Android devices connected');
          }
        }
      }
    } catch (e) {
      print('  ⚠️  ADB not available in PATH');
    }
  }
  
  /// Validate iOS development environment (macOS only)
  Future<void> _validateiOS() async {
    if (!Platform.isMacOS) {
      print('\n🍎 iOS Development');
      print('-' * 20);
      print('  ⚠️  iOS development only available on macOS');
      return;
    }
    
    print('\n🍎 iOS Development');
    print('-' * 20);
    
    // Check Xcode
    try {
      final xcodeResult = await Process.run('xcode-select', ['-p']);
      if (xcodeResult.exitCode != 0) {
        _results.add(ValidationResult(
          false,
          '❌ Xcode not found',
          ['Install Xcode from Mac App Store',
           'Run: sudo xcode-select --install']
        ));
        return;
      }
      
      final xcodePath = xcodeResult.stdout.toString().trim();
      print('  ✅ Xcode found: $xcodePath');
      
      // Check Xcode version
      final xcodeVersionResult = await Process.run('xcodebuild', ['-version']);
      if (xcodeVersionResult.exitCode == 0) {
        final versionLine = xcodeVersionResult.stdout.toString().split('\n')[0];
        print('  ✅ $versionLine');
      }
      
      // Check iOS simulators
      final simulatorsResult = await Process.run('xcrun', ['simctl', 'list', 'devices', 'available']);
      if (simulatorsResult.exitCode == 0) {
        final simulators = simulatorsResult.stdout.toString();
        if (simulators.contains('iOS')) {
          print('  ✅ iOS simulators available');
        } else {
          print('  ⚠️  No iOS simulators found');
        }
      }
      
    } catch (e) {
      _results.add(ValidationResult(
        false,
        '❌ Error checking Xcode: $e',
        ['Install Xcode and command line tools']
      ));
    }
    
    // Check CocoaPods
    try {
      final podResult = await Process.run('pod', ['--version']);
      if (podResult.exitCode == 0) {
        final version = podResult.stdout.toString().trim();
        print('  ✅ CocoaPods $version');
      } else {
        _results.add(ValidationResult(
          false,
          '❌ CocoaPods not found',
          ['Install CocoaPods: sudo gem install cocoapods']
        ));
      }
    } catch (e) {
      _results.add(ValidationResult(
        false,
        '❌ CocoaPods not found',
        ['Install CocoaPods: sudo gem install cocoapods']
      ));
    }
  }
  
  /// Validate project-specific dependencies
  Future<void> _validateProjectDependencies() async {
    print('\n📦 Project Dependencies');
    print('-' * 20);
    
    // Check pubspec.yaml
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      _results.add(ValidationResult(
        false,
        '❌ pubspec.yaml not found - run from project root',
        ['Navigate to the DevPocket project root directory']
      ));
      return;
    }
    
    print('  ✅ pubspec.yaml found');
    
    // Check if dependencies are installed
    final pubLockFile = File('pubspec.lock');
    if (!pubLockFile.existsSync()) {
      _results.add(ValidationResult(
        false,
        '⚠️  Dependencies not installed',
        ['Run: flutter pub get']
      ));
    } else {
      print('  ✅ Dependencies lock file found');
    }
    
    // Check .dart_tool
    final dartTool = Directory('.dart_tool');
    if (!dartTool.existsSync()) {
      print('  ⚠️  .dart_tool directory not found - run "flutter pub get"');
    } else {
      print('  ✅ .dart_tool directory found');
    }
    
    // Check Android local.properties
    final localProperties = File('android/local.properties');
    if (!localProperties.existsSync()) {
      _results.add(ValidationResult(
        false,
        '⚠️  android/local.properties not found',
        ['Create android/local.properties with SDK path',
         'Copy from android/local.properties.example if available',
         'Run: flutter doctor to auto-generate']
      ));
    } else {
      print('  ✅ android/local.properties found');
      
      // Validate contents
      final contents = await localProperties.readAsString();
      if (!contents.contains('sdk.dir=')) {
        print('  ⚠️  android/local.properties missing sdk.dir');
      }
    }
    
    // Check iOS Pods (if on macOS)
    if (Platform.isMacOS) {
      final podfile = File('ios/Podfile');
      final podfileLock = File('ios/Podfile.lock');
      
      if (podfile.existsSync()) {
        print('  ✅ iOS Podfile found');
        if (!podfileLock.existsSync()) {
          print('  ⚠️  iOS dependencies not installed - run "cd ios && pod install"');
        } else {
          print('  ✅ iOS dependencies installed');
        }
      }
    }
  }
  
  /// Display validation results summary
  void _displayResults() {
    print('\n${'=' * 50}');
    print('📋 VALIDATION SUMMARY');
    print('=' * 50);
    
    final passed = _results.where((r) => r.isValid).length;
    final failed = _results.where((r) => !r.isValid).length;
    
    print('✅ Passed: $passed');
    print('❌ Failed: $failed');
    
    if (failed > 0) {
      print('\n🔧 REQUIRED FIXES:');
      print('-' * 20);
      
      for (final result in _results.where((r) => !r.isValid)) {
        print('\n${result.message}');
        for (final fix in result.fixes) {
          print('  → $fix');
        }
      }
      
      print('\n💡 After fixing issues, run this script again to verify.');
    } else {
      print('\n🎉 All validations passed! Your environment is ready for DevPocket development.');
      print('\nNext steps:');
      print('  1. Run: flutter pub get');
      print('  2. Run: flutter run');
      print('  3. Start developing! 🚀');
    }
  }
  
  /// Extract Flutter channel from version output
  String _extractChannel(String versionOutput) {
    final channelMatch = RegExp(r'Channel (\w+)').firstMatch(versionOutput);
    return channelMatch?.group(1) ?? 'unknown';
  }
}

/// Main entry point
void main(List<String> arguments) async {
  final validator = BuildEnvironmentValidator();
  await validator.validateEnvironment();
}