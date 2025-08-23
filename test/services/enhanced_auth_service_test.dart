import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/user_model.dart';

void main() {
  group('User.fromJson', () {
    test('should parse user data from backend response format', () {
      // Simulate the backend API response format
      final jsonResponse = {
        'id': 'a03f5f23-2afe-4981-a717-6683bd0bd203',
        'email': 'goon.nguyen@gmail.com',
        'username': 'mrgoonie',
        'email_verified': false,
        'created_at': '2025-08-22T07:38:18.985Z',
        'updated_at': '2025-08-22T07:38:18.985Z',
      };

      // Test parsing
      final user = User.fromJson(jsonResponse);

      expect(user.id, equals('a03f5f23-2afe-4981-a717-6683bd0bd203'));
      expect(user.email, equals('goon.nguyen@gmail.com'));
      expect(user.username, equals('mrgoonie'));
      expect(user.emailVerified, equals(false));
      expect(user.createdAt, equals(DateTime.parse('2025-08-22T07:38:18.985Z')));
      expect(user.updatedAt, equals(DateTime.parse('2025-08-22T07:38:18.985Z')));
    });

    test('should handle both snake_case and camelCase field names', () {
      // Test with camelCase format
      final camelCaseJson = {
        'id': 'test-id',
        'email': 'test@example.com',
        'username': 'testuser',
        'emailVerified': true,
        'createdAt': '2025-08-22T07:38:18.985Z',
        'updatedAt': '2025-08-22T07:38:18.985Z',
      };

      final userCamelCase = User.fromJson(camelCaseJson);

      // Test with snake_case format (backend format)
      final snakeCaseJson = {
        'id': 'test-id',
        'email': 'test@example.com',
        'username': 'testuser',
        'email_verified': true,
        'created_at': '2025-08-22T07:38:18.985Z',
        'updated_at': '2025-08-22T07:38:18.985Z',
      };

      final userSnakeCase = User.fromJson(snakeCaseJson);

      // Both should produce the same result
      expect(userCamelCase.emailVerified, equals(userSnakeCase.emailVerified));
      expect(userCamelCase.createdAt, equals(userSnakeCase.createdAt));
      expect(userCamelCase.updatedAt, equals(userSnakeCase.updatedAt));
    });

    test('should handle missing optional fields gracefully', () {
      final minimalJson = {
        'id': 'test-id',
        'email': 'test@example.com',
        'username': 'testuser',
        'created_at': '2025-08-22T07:38:18.985Z',
      };

      final user = User.fromJson(minimalJson);

      expect(user.id, equals('test-id'));
      expect(user.email, equals('test@example.com'));
      expect(user.username, equals('testuser'));
      expect(user.emailVerified, equals(false)); // Default value
      expect(user.subscriptionTier, equals('free')); // Default value
      expect(user.isInTrial, equals(false)); // Default value
      expect(user.avatarUrl, isNull);
      expect(user.firstName, isNull);
      expect(user.lastName, isNull);
    });
  });
}