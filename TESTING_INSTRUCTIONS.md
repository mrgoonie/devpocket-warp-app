# DevPocket Mock User Testing Instructions

## Overview
I've created a mock authentication service that allows you to test the app's UI and screen layouts without needing a real backend server.

## Mock User Details
The mock service creates a demo user with the following details:
- **Username**: `demo_user`
- **Email**: `demo@devpocket.app`
- **Password**: Any password will work (try `password123`)
- **Subscription**: Pro tier with 14-day trial
- **Profile**: Demo User from DevPocket Inc., San Francisco

## How to Login

### Method 1: Regular Login
1. Run the app: `flutter run`
2. Navigate to the login screen
3. Enter any username (e.g., `demo_user`)
4. Enter any password (e.g., `password123`)
5. Tap "Login"

### Method 2: Social Login
- **Google Sign-in**: Works with mock data
- **GitHub Sign-in**: Works with mock data
- Both will create slightly different mock users

### Method 3: Registration
1. Go to registration screen
2. Fill in any valid email, username, and password
3. The system will accept the registration and log you in

## What You Can Test
Once logged in, you can explore:
- **Main Tab Navigation**: 5-tab structure (Vaults, Terminal, History, Code Editor, Settings)
- **User Profile**: View mock user details in settings
- **UI Components**: All screens and layouts
- **Navigation Flow**: Between different sections
- **Settings**: Various configuration screens

## Switching Between Mock and Real API
To switch back to the real API:
1. Open `lib/providers/auth_provider.dart`
2. Change `const bool useMockService = true;` to `false`
3. Hot restart the app

## Mock Service Features
- ✅ Realistic loading delays (1.5-2.5 seconds)
- ✅ Form validation
- ✅ Token management (stored securely)
- ✅ User profile data
- ✅ All authentication methods
- ✅ Logout functionality

## Credentials That Work
- **Username**: Any non-empty string
- **Password**: Any non-empty string (minimum 6 characters for registration)
- **Email**: Any valid email format for registration

## Debug Information
The app will print `🎭 Using MockAuthService for testing` in the console when using mock mode, and `🌐 Using real AuthService` when using the real API.

## Quick Start
```bash
# Run the app
flutter run

# Use these test credentials:
Username: demo_user
Password: password123
```

This setup allows you to fully test the app's UI, navigation, and user experience without needing the backend server running.