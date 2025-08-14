# DevPocket - Code Style & Conventions

## Dart/Flutter Code Style

### File Organization
- `lib/` - Main application code
- `lib/screens/` - UI screens organized by feature
- `lib/providers/` - Riverpod providers for state management
- `lib/services/` - API and business logic services
- `lib/models/` - Data models and DTOs
- `lib/widgets/` - Reusable UI components
- `lib/themes/` - Theme and styling definitions
- `lib/utils/` - Helper functions and constants

### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/Functions: `camelCase`
- Constants: `SCREAMING_SNAKE_CASE`
- Private members: prefix with `_`

### Widget Structure
- Use `ConsumerStatefulWidget` with Riverpod
- Separate build methods for complex widgets
- Extract reusable components
- Use proper error handling with try-catch blocks

### State Management
- All app state managed through Riverpod providers
- Async operations with `AsyncValue`
- Proper loading and error states
- Clean separation of concerns

### Error Handling
- Comprehensive try-catch blocks
- User-friendly error messages
- Meaningful error states with recovery suggestions
- Debug information for developers

### Security Practices
- Use flutter_secure_storage for sensitive data
- Proper JWT token management
- Validate all user inputs
- Secure API key storage (BYOK model)