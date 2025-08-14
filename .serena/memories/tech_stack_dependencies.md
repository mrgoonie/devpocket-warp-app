# DevPocket - Tech Stack & Dependencies

## Core Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.9     # State management
  xterm: ^3.4.0                # Terminal emulator
  web_socket_channel: ^2.4.0   # WebSocket connections
  google_sign_in: ^6.1.5       # Google OAuth
  flutter_secure_storage: ^9.0.0 # Secure key storage
  shared_preferences: ^2.2.2   # Local preferences
  http: ^1.1.0                 # HTTP requests
  uuid: ^4.1.0                 # UUID generation
  intl: ^0.18.0                # Internationalization
```

## Additional Packages Needed
- `flutter_svg` for SVG icons
- `lottie` for animations
- `package_info_plus` for app version
- `url_launcher` for external links
- `local_auth` for biometric authentication (iOS)
- `connectivity_plus` for network status

## iOS Configuration
- iOS folder already exists and configured
- Swift-based AppDelegate
- Podfile configured for dependencies
- Xcode project ready

## Flutter Configuration
- Uses Material Design with custom Neobrutalism theming
- Dark theme primary: Color(0xFF0D1117)
- JetBrains Mono for terminal, system fonts for UI
- Responsive design for different screen sizes