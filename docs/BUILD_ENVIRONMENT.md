# DevPocket Build Environment Setup Guide

This guide provides comprehensive instructions for setting up a development environment for the DevPocket Flutter terminal application, supporting both iOS and Android platforms.

## Quick Start

```bash
# 1. Clone and setup
git clone <repository-url> && cd devpocket-warp-app

# 2. Validate environment
dart scripts/validate_build_env.dart

# 3. Setup dependencies  
./scripts/setup_dependencies.sh

# 4. Install Flutter dependencies
flutter pub get

# 5. Run on device
flutter run
```

## Prerequisites

### System Requirements

- **Operating System**: macOS 12.0+ (for iOS development) or Linux/Windows (Android only)
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 10GB free space minimum
- **Network**: Stable internet connection for dependencies

### Required Software

#### 1. Flutter SDK
- **Version**: 3.24.0 or higher (currently using 3.32.7)
- **Channel**: Stable recommended
- **Installation**: [Flutter Installation Guide](https://docs.flutter.dev/get-started/install)

```bash
# Verify Flutter installation
flutter doctor -v
```

#### 2. Android Development

##### Android SDK
- **Android SDK**: API Level 34 (Android 14)
- **Build Tools**: 34.0.0 or higher
- **Platform Tools**: Latest version
- **Android NDK**: 26.1.10909125

##### Java Development Kit
- **Version**: OpenJDK 17 (LTS)
- **Provider**: Eclipse Temurin, Oracle, or OpenJDK

```bash
# Verify Java installation
java -version
javac -version

# Should output Java 17.x.x
```

##### Android Studio (Recommended)
- **Version**: Electric Eel (2022.1.1) or higher
- **Components**: Android SDK, Android SDK Platform-Tools, Android SDK Build-Tools
- **Download**: [Android Studio](https://developer.android.com/studio)

#### 3. iOS Development (macOS only)

##### Xcode
- **Version**: 15.0 or higher
- **Command Line Tools**: Latest version
- **Simulator**: iOS 16.0+ simulators

```bash
# Install Xcode command line tools
sudo xcode-select --install

# Verify Xcode installation
xcode-select -p
```

##### CocoaPods
- **Version**: 1.15.0 or higher

```bash
# Install CocoaPods
sudo gem install cocoapods

# Verify installation
pod --version
```

## Environment Setup

### 1. Flutter Environment

```bash
# Add Flutter to PATH (add to ~/.zshrc or ~/.bashrc)
export PATH="$PATH:[PATH_TO_FLUTTER_GIT_DIRECTORY]/flutter/bin"

# Reload shell configuration
source ~/.zshrc

# Enable flutter development
flutter config --enable-web
```

### 2. Android Environment

#### Option A: Using Android Studio (Recommended)
1. Download and install [Android Studio](https://developer.android.com/studio)
2. Open Android Studio
3. Go to **Settings** → **Appearance & Behavior** → **System Settings** → **Android SDK**
4. Install:
   - Android 14.0 (API 34)
   - Android SDK Build-Tools 34.0.0
   - Android SDK Platform-Tools

#### Option B: Command Line Setup
```bash
# Install Android SDK command line tools
# Download from: https://developer.android.com/studio#downloads

# Set environment variables (add to ~/.zshrc or ~/.bashrc)
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin

# Install required packages
sdkmanager --install "platform-tools" "platforms;android-34" "build-tools;34.0.0"
sdkmanager --install "ndk;26.1.10909125"
```

### 3. Android NDK Setup

The Android NDK is required for building native code dependencies.

```bash
# Install via Android Studio SDK Manager or command line
sdkmanager --install "ndk;26.1.10909125"

# Set NDK path (add to ~/.zshrc or ~/.bashrc)
export ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/26.1.10909125
```

### 4. Java JDK 17 Setup

#### macOS (Using Homebrew)
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Java 17
brew install openjdk@17

# Set JAVA_HOME (add to ~/.zshrc or ~/.bashrc)
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export PATH="$JAVA_HOME/bin:$PATH"
```

#### Ubuntu/Debian
```bash
# Update package list
sudo apt update

# Install Java 17
sudo apt install openjdk-17-jdk

# Set JAVA_HOME (add to ~/.bashrc)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
```

## Project Configuration

### 1. Android Configuration

#### Local Properties
Create `android/local.properties` (or copy from `android/local.properties.example`):

```properties
# Android SDK path
sdk.dir=/Users/[USERNAME]/Library/Android/sdk
ndk.dir=/Users/[USERNAME]/Library/Android/sdk/ndk/26.1.10909125

# Build optimization
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configureondemand=true
```

#### Gradle Properties Optimization
The `android/gradle.properties` file includes performance optimizations:

```properties
# Build performance optimizations
org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.daemon=true
org.gradle.configureondemand=true

# Android optimizations
android.useAndroidX=true
android.enableJetifier=true
android.enableR8.fullMode=true
```

### 2. Flutter Dependencies

```bash
# Install project dependencies
flutter pub get

# Verify dependencies
flutter pub deps
```

### 3. iOS Dependencies (macOS only)

```bash
# Navigate to iOS directory
cd ios

# Install CocoaPods dependencies
pod install

# Return to project root
cd ..
```

## Verification

### 1. Environment Validation Script

Run the automated environment checker:

```bash
dart scripts/validate_build_env.dart
```

This script checks:
- Flutter SDK version and configuration
- Android SDK and build tools
- Java JDK version
- NDK installation
- iOS development tools (macOS only)
- Project dependencies

### 2. Manual Verification

#### Flutter Doctor
```bash
flutter doctor -v
```

Expected output should show ✓ (checkmarks) for:
- Flutter (Channel stable, version 3.24+)
- Android toolchain
- Xcode (macOS only)
- Connected devices

#### Test Builds

##### Android Debug Build
```bash
flutter build apk --debug
```

##### Android Release Build (requires signing)
```bash
flutter build apk --release
```

##### iOS Build (macOS only)
```bash
flutter build ios --debug --no-codesign
```

### 3. Test Application

```bash
# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d android
flutter run -d ios
```

## Troubleshooting

### Common Issues

#### 1. Flutter Doctor Issues

**Android SDK not found:**
```bash
flutter config --android-sdk /path/to/android/sdk
```

**Android licenses not accepted:**
```bash
flutter doctor --android-licenses
```

#### 2. Build Issues

**Gradle build fails:**
```bash
# Clean and rebuild
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

**iOS build issues (macOS):**
```bash
# Clean iOS build
cd ios
rm -rf Pods
rm Podfile.lock
pod install
cd ..
flutter clean
flutter run
```

#### 3. Performance Issues

**Slow Gradle builds:**
- Increase memory allocation in `gradle.properties`
- Enable Gradle daemon and parallel builds
- Use Gradle build cache

**Slow Flutter builds:**
```bash
# Enable build caching
flutter config --build-dir=build

# Use hot reload during development
flutter run --hot
```

### Platform-Specific Issues

#### Android

**NDK not found:**
```bash
# Verify NDK installation
ls $ANDROID_HOME/ndk/

# Reinstall if necessary
sdkmanager --install "ndk;26.1.10909125"
```

**Java version conflicts:**
```bash
# Check Java version
java -version

# Set correct JAVA_HOME
export JAVA_HOME=/path/to/java17
```

#### iOS (macOS only)

**CocoaPods issues:**
```bash
# Update CocoaPods
sudo gem install cocoapods

# Clean and reinstall
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

**Xcode issues:**
```bash
# Update Xcode command line tools
sudo xcode-select --install

# Reset Xcode settings (if needed)
sudo xcode-select --reset
```

## Development Workflow

### 1. Daily Development

```bash
# Start development session
flutter pub get
flutter run --hot

# Hot reload: Press 'r' in terminal
# Hot restart: Press 'R' in terminal
# Quit: Press 'q' in terminal
```

### 2. Testing

```bash
# Run all tests
flutter test

# Run specific test files
flutter test test/services/auth_service_test.dart

# Run integration tests
flutter test integration_test/
```

### 3. Building for Distribution

```bash
# Android APK (debug)
flutter build apk --debug

# Android App Bundle (release)
flutter build appbundle --release

# iOS (release)
flutter build ios --release
```

## Performance Optimization

### 1. Build Performance

- **Parallel builds**: Enable in Gradle properties
- **Incremental builds**: Avoid `flutter clean` unless necessary
- **Build cache**: Use Gradle and Flutter build caching
- **Memory allocation**: Increase JVM heap size

### 2. Development Performance

- **Hot reload**: Use for UI changes
- **Hot restart**: Use for logic changes
- **Incremental compilation**: Enable in IDE
- **Target specific devices**: Avoid running on multiple devices

## Environment Variables Summary

Add these to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.):

```bash
# Flutter
export PATH="$PATH:/path/to/flutter/bin"

# Android
export ANDROID_HOME=$HOME/Library/Android/sdk
export ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/26.1.10909125
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Java
export JAVA_HOME=/path/to/java17
export PATH="$JAVA_HOME/bin:$PATH"
```

## Continuous Integration

This project includes automated CI/CD pipelines that use the same environment setup. See:
- `.github/workflows/ci.yml` - Main CI pipeline
- `.github/workflows/test.yml` - Test execution
- `.github/workflows/build.yml` - Build artifacts
- `.github/workflows/deploy.yml` - Deployment validation

## Getting Help

### Resources
- [Flutter Documentation](https://docs.flutter.dev/)
- [Android Developer Guide](https://developer.android.com/guide)
- [iOS Developer Guide](https://developer.apple.com/documentation/)

### Support Channels
- **Project Issues**: Create GitHub issue with environment details
- **Flutter Issues**: [Flutter GitHub Issues](https://github.com/flutter/flutter/issues)
- **Android Issues**: [Android Issue Tracker](https://issuetracker.google.com/issues?q=componentid:192708)

### Environment Information Collection

When reporting issues, include:

```bash
# Collect environment information
flutter doctor -v > flutter_doctor.txt
dart --version > dart_version.txt
java -version > java_version.txt

# Include contents in issue report
```

---

**Last Updated**: 2025-08-24  
**Flutter Version**: 3.32.7  
**Android SDK**: API 34  
**Minimum iOS**: 12.0