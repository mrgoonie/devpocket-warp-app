# DevPocket - Project Overview

## Project Purpose
DevPocket is an AI-Powered Mobile Terminal app for DevOps/SRE professionals - "The Ultimate AI-Powered SSH Client". It combines traditional SSH capabilities with AI assistance, block-based terminal interface similar to Warp.dev, and mobile-first UX design.

## Key Features
- **SSH Client**: Connection profiles, jump hosts, auto-reconnect
- **AI Integration**: BYOK (Bring Your Own Key) model with OpenRouter API
- **Block-Based Terminal**: Warp-style command blocks for better organization
- **Mobile-First**: iOS target with touch-optimized UX
- **Cloud Sync**: Command history synchronization across devices
- **Dual Input Modes**: Command Mode vs Agent Mode toggle

## Target Platform
- Primary: iOS (existing iOS folder configured)
- Secondary: Android (future)
- Framework: Flutter with Dart

## Architecture
- **Authentication Flow**: Splash → Onboarding → Login/Register → Main App
- **Main Navigation**: 5-tab bottom navigation (Vaults, Terminal, History, Editor, Settings)
- **State Management**: Riverpod providers for all state
- **Design System**: Neobrutalism theme with light/dark/auto modes

## Tech Stack
- Flutter SDK with Dart
- State Management: flutter_riverpod
- Terminal: xterm package
- Real-time: web_socket_channel
- Authentication: JWT + Google Sign-in
- Storage: flutter_secure_storage + shared_preferences
- HTTP: http package
- UI Components: Material Design with custom theming