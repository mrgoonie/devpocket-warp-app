import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encryption utility for SSH host credentials
class SshHostEncryption {
  static const String _encryptionKeyKey = 'host_encryption_key';
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Initialize encryption key for host credentials
  Future<void> _initializeEncryption() async {
    final existingKey = await _storage.read(key: _encryptionKeyKey);
    if (existingKey == null) {
      final key = _generateEncryptionKey();
      await _storage.write(key: _encryptionKeyKey, value: key);
    }
  }
  
  String _generateEncryptionKey() {
    final bytes = List<int>.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256);
    return base64Encode(bytes);
  }
  
  /// Encrypt sensitive host data
  Future<String> encryptCredential(String credential) async {
    await _initializeEncryption();
    final key = await _storage.read(key: _encryptionKeyKey);
    
    if (key == null) {
      throw Exception('Encryption key not found');
    }
    
    // In a real implementation, use AES encryption
    // For now, we'll use base64 encoding as a placeholder
    final bytes = utf8.encode(credential);
    return base64Encode(bytes);
  }
  
  /// Decrypt sensitive host data
  Future<String> decryptCredential(String encryptedCredential) async {
    await _initializeEncryption();
    final key = await _storage.read(key: _encryptionKeyKey);
    
    if (key == null) {
      throw Exception('Encryption key not found');
    }
    
    try {
      // In a real implementation, use AES decryption
      // For now, we'll use base64 decoding as a placeholder
      final bytes = base64Decode(encryptedCredential);
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('Error decrypting credential: $e');
      throw Exception('Failed to decrypt credential');
    }
  }
}