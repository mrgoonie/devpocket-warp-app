# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DevPocket is an AI-powered mobile terminal app built with Flutter. It combines traditional terminal functionality with AI assistance to help developers work from mobile devices. The project consists of:

- **Flutter Mobile App**: iOS/Android app with terminal, SSH, and AI features
- **Python Backend**: FastAPI server with WebSocket support, SSH/PTY execution, and AI integration
- **Documentation**: Comprehensive product specifications and implementation guides

## Architecture

### Frontend (Flutter)
- **Authentication Flow**: Splash → Onboarding → Login/Register → Main App
- **Main Navigation**: 5-tab structure (Vaults, Terminal, History, Code Editor, Settings)
- **Terminal Features**: Block-based UI, dual input modes (Command/Agent), PTY support
- **State Management**: Uses Riverpod for reactive state management
- **AI Integration**: BYOK (Bring Your Own Key) model with OpenRouter API

### Backend (Python FastAPI)
- **Database**: PostgreSQL for persistent data, Redis for caching
- **Real-time**: WebSocket connections for terminal sessions
- **SSH/PTY**: Full SSH client with pseudo-terminal support
- **AI Service**: OpenRouter integration using user-provided API keys
- **Authentication**: JWT-based with secure token management

### **📚 Resources**
- **Documentation**: [api.devpocket.app/redoc](https://api.devpocket.app/redoc)
- **API Reference**: [api.devpocket.app/docs](https://api.devpocket.app/docs)
- **Security**: [security@devpocket.app](mailto:security@devpocket.app)

## Key Features

### Terminal Capabilities
- **SSH Connections**: Full SSH client with saved profiles
- **Local PTY**: True terminal emulation on mobile
- **AI Command Generation**: Natural language to shell commands
- **Block-based Interface**: Warp-style command execution blocks
- **Multi-device Sync**: Command history across devices

### Security & Privacy
- **BYOK Model**: Users provide their own OpenRouter API keys
- **No AI Costs**: Zero AI infrastructure costs for the platform
- **Encrypted Storage**: Secure credential management
- **Biometric Auth**: Face ID/Touch ID support on iOS

## Development Setup

Since this appears to be a documentation-only repository (no pubspec.yaml or actual Flutter code yet), development commands will depend on the actual implementation.

### Expected Flutter Commands
```bash
# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run -d ios

# Run on Android emulator  
flutter run -d android

# Build for production
flutter build ios --release
flutter build android --release

# Run tests
flutter test
```

### Backend Development
```bash
# Install Python dependencies
pip install -r requirements.txt

# Start development server
python main.py
# or
uvicorn main:app --reload

# Run with specific configuration
python main.py --host 0.0.0.0 --port 8000
```

## Project Structure

```
devpocket-warp-app/
├── docs/                           # Product documentation
│   ├── devpocket-product-overview.md  # Complete product specification
│   ├── devpocket-flutter-app-structure-dart.md  # Flutter app architecture
│   ├── devpocket-server-implementation-py.md    # Backend implementation
│   └── ...                         # Additional planning docs
├── ios/                            # iOS platform files
│   ├── Runner/                     # iOS app configuration
│   ├── Pods/                       # CocoaPods dependencies
│   └── ...                         # iOS build artifacts
└── .gitignore                      # Git ignore rules
```

## Important Implementation Notes

### AI Integration (BYOK)
- Users must provide their own OpenRouter API keys
- No server-side AI costs - users control their spending
- API key validation before AI features are enabled
- Caching implemented to reduce user API costs by 60%

### Terminal Implementation
- Requires true PTY support for interactive commands
- SSH connections need paramiko library (Python backend)
- WebSocket real-time communication for terminal I/O
- Block-based UI similar to Warp terminal

### Mobile-First Design
- Touch-optimized terminal interactions
- Native mobile gestures (swipe, pinch, drag)
- Responsive design for phones and tablets
- Platform-specific UI adaptations (iOS/Android)

## Security Considerations

- Never store actual API keys - only validation flags
- Implement proper JWT token handling
- Use encrypted storage for SSH credentials
- Validate all user inputs to prevent command injection
- Implement rate limiting for AI API calls

## Business Model Notes

- **Freemium Structure**: Free tier with BYOK, paid tiers add sync/collaboration
- **BYOK Advantage**: 85-98% gross margins vs 70% industry average  
- **User Control**: No surprise AI charges, users manage their own usage
- **Trust Factor**: Transparent about AI costs and data handling