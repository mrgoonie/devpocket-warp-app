# DevPocket - Task Completion Workflow

## When a Development Task is Completed

### 1. Code Quality Checks
```bash
# Format all code
dart format .

# Analyze code for issues
flutter analyze

# Run all tests
flutter test

# Fix any linting issues
dart fix --apply
```

### 2. Functionality Testing
```bash
# Clean build
flutter clean && flutter pub get

# Test on iOS simulator
flutter run

# Test core features:
# - Authentication flow
# - Navigation between tabs
# - Terminal functionality
# - Settings and preferences
```

### 3. Build Verification
```bash
# Build iOS release (for App Store)
flutter build ios --release

# Verify iOS build in Xcode
open ios/Runner.xcworkspace
```

### 4. Documentation Updates
- Update README.md if needed
- Document new features or API changes
- Update version in pubspec.yaml if appropriate

### 5. Git Commit Process
```bash
# Stage changes
git add .

# Commit with conventional format (NO AI signatures)
git commit -m "feat: implement authentication and main navigation"

# Push to branch
git push origin feature-branch
```

### 6. Pre-Submission Checklist
- [ ] All screens navigate properly
- [ ] Authentication flow works
- [ ] Theme switching functions
- [ ] No build warnings or errors
- [ ] No console errors during runtime
- [ ] App launches without crashes
- [ ] iOS permissions configured correctly

### 7. Performance Verification
- Check app startup time
- Monitor memory usage
- Verify smooth animations
- Test on different iOS device sizes

### Important Notes
- NEVER include AI attribution signatures in commits
- Use conventional commit format: feat/fix/refactor/docs
- Focus commit messages on actual code changes
- Test thoroughly before marking task complete