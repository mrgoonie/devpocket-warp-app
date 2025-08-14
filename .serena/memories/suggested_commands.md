# DevPocket - Suggested Commands

## Development Commands

### Flutter Commands
```bash
# Create new Flutter project (if needed)
flutter create devpocket_warp_app

# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run

# Run on iOS device  
flutter run -d ios

# Clean build cache
flutter clean && flutter pub get

# Generate code (if using code generation)
flutter packages pub run build_runner build

# Run tests
flutter test
```

### iOS-Specific Commands
```bash
# Open Xcode workspace
open ios/Runner.xcworkspace

# Install CocoaPods dependencies
cd ios && pod install

# Build for iOS
flutter build ios

# Clean iOS build
cd ios && xcodebuild clean
```

### Code Quality Commands
```bash
# Format code
dart format .

# Analyze code
flutter analyze

# Fix common issues
dart fix --apply
```

### Git Commands
```bash
# Conventional commits format
git commit -m "feat: add authentication flow"
git commit -m "fix: resolve terminal connection issue"
git commit -m "refactor: improve state management"
git commit -m "docs: update README with setup instructions"
```

### Debugging Commands
```bash
# Debug on device
flutter run --debug

# Profile app performance
flutter run --profile

# Build release version
flutter build ios --release

# Get device logs
flutter logs
```

## System Utilities (Darwin/macOS)
- `ls -la` - List directory contents with details
- `find . -name "*.dart"` - Find Dart files
- `grep -r "searchterm" lib/` - Search in source code
- `cd` - Change directory
- `pwd` - Show current directory