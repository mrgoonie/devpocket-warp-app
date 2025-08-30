import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import '../models/ssh_profile_models.dart';

/// Handles SSH authentication logic
class SshConnectionAuth {
  /// Create authenticated SSH client based on profile
  static Future<SSHClient> createAuthenticatedClient(
    SSHSocket socket, 
    SshProfile profile
  ) async {
    late SSHClient client;
    
    switch (profile.authType) {
      case SshAuthType.password:
        client = SSHClient(
          socket,
          username: profile.username,
          onPasswordRequest: () => profile.password ?? '',
        );
        break;
        
      case SshAuthType.key:
        final keyPair = await _parsePrivateKey(
          profile.privateKey!,
          profile.passphrase,
        );
        
        if (keyPair == null) {
          throw Exception('Invalid private key format');
        }
        
        client = SSHClient(
          socket,
          username: profile.username,
          identities: [keyPair],
        );
        break;
    }
    
    return client;
  }
  
  /// Parse private key with optional passphrase
  static Future<SSHKeyPair?> _parsePrivateKey(String privateKey, String? passphrase) async {
    try {
      // Handle different key formats and normalize line endings
      String normalizedKey = privateKey.trim();
      
      // Ensure proper line endings for SSH key format
      normalizedKey = normalizedKey.replaceAll(RegExp(r'\r\n|\r'), '\n');
      
      // Try parsing with passphrase if provided
      if (passphrase != null && passphrase.isNotEmpty) {
        try {
          final keyPairs = SSHKeyPair.fromPem(normalizedKey, passphrase);
          return keyPairs.isNotEmpty ? keyPairs.first : null;
        } catch (e) {
          debugPrint('Failed to parse key with passphrase: $e');
          // Try without passphrase as fallback
        }
      }
      
      // Try parsing without passphrase
      final keyPairs = SSHKeyPair.fromPem(normalizedKey);
      return keyPairs.isNotEmpty ? keyPairs.first : null;
      
    } catch (e) {
      debugPrint('Failed to parse SSH private key: $e');
      
      // Additional parsing attempts for different key formats
      try {
        // Try base64 decoding if it looks like raw base64
        if (!privateKey.contains('BEGIN') && !privateKey.contains('END')) {
          final decoded = base64.decode(privateKey);
          final keyPairs = SSHKeyPair.fromPem(utf8.decode(decoded));
          return keyPairs.isNotEmpty ? keyPairs.first : null;
        }
      } catch (decodeError) {
        debugPrint('Base64 decode failed: $decodeError');
      }
      
      return null;
    }
  }
  
  /// Validate SSH profile authentication configuration
  static String? validateAuthProfile(SshProfile profile) {
    switch (profile.authType) {
      case SshAuthType.password:
        if (profile.password == null || profile.password!.isEmpty) {
          return 'Password is required for password authentication';
        }
        break;
        
      case SshAuthType.key:
        if (profile.privateKey == null || profile.privateKey!.isEmpty) {
          return 'Private key is required for key authentication';
        }
        
        // Basic validation of key format
        if (!profile.privateKey!.contains('BEGIN') || !profile.privateKey!.contains('PRIVATE KEY')) {
          return 'Invalid private key format';
        }
        break;
    }
    
    // Validate common fields
    if (profile.username.isEmpty) {
      return 'Username is required';
    }
    
    if (profile.host.isEmpty) {
      return 'Host is required';
    }
    
    if (profile.port <= 0 || profile.port > 65535) {
      return 'Port must be between 1 and 65535';
    }
    
    return null; // Profile is valid
  }
  
  /// Test SSH connection without creating a full session
  static Future<bool> testConnection(SshProfile profile) async {
    try {
      final validationError = validateAuthProfile(profile);
      if (validationError != null) {
        throw Exception(validationError);
      }
      
      final socket = await SSHSocket.connect(profile.host, profile.port);
      final client = await createAuthenticatedClient(socket, profile);
      
      // Test connection by attempting to execute a simple command
      final session = await client.execute('echo "test"');
      await utf8.decoder.bind(session.stdout).join();
      
      client.close();
      return true;
      
    } catch (e) {
      debugPrint('SSH connection test failed: $e');
      return false;
    }
  }
}