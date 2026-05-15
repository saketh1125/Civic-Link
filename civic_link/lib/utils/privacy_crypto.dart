/// Civic-Link Privacy Cryptography Utilities
///
/// Implements Zero-Liability hashing for PII protection.
/// All email operations use SHA-256 to prevent raw PII transmission.
///
/// Usage:
/// ```dart
/// final hashed = PrivacyCrypto.hashEmail('officer@police.gov.in');
/// print(hashed.emailHash); // SHA-256 string
/// print(hashed.domain);    // 'police.gov.in'
/// ```

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Result of email hashing operation containing both hash and domain.
class HashedEmail {
  /// Lowercase SHA-256 hash of the full email address
  final String emailHash;

  /// Extracted domain portion (everything after @)
  final String emailDomain;

  const HashedEmail({
    required this.emailHash,
    required this.emailDomain,
  });

  @override
  String toString() => 'HashedEmail(hash: $emailHash, domain: $emailDomain)';
}

/// Zero-Liability cryptography for Civic-Link authentication.
///
/// This class ensures raw emails NEVER leave the device.
/// Backend receives only SHA-256 hashes and domains.
class PrivacyCrypto {
  PrivacyCrypto._(); // Private constructor - static utility class

  /// Validates and extracts domain from email address.
  ///
  /// Throws [ArgumentError] if email is empty or malformed.
  static String _extractDomain(String email) {
    if (email.isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }

    final atIndex = email.lastIndexOf('@');
    if (atIndex == -1 || atIndex == email.length - 1) {
      throw ArgumentError('Invalid email format: missing domain');
    }

    return email.substring(atIndex + 1).toLowerCase().trim();
  }

  /// Generates SHA-256 hash of lowercase email.
  ///
  /// Returns hex-encoded SHA-256 string (64 characters).
  static String _hashEmail(String email) {
    final normalized = email.toLowerCase().trim();
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Transforms raw email into privacy-safe components.
  ///
  /// Returns [HashedEmail] containing SHA-256 hash and domain.
  /// Raw email is immediately discarded after hashing.
  ///
  /// Example:
  /// ```dart
  /// final result = PrivacyCrypto.hashEmail('Officer.John@Police.Gov.In');
  /// result.emailHash; // 'a3f5c8...' (64 chars)
  /// result.emailDomain; // 'police.gov.in'
  /// ```
  static HashedEmail hashEmail(String email) {
    final domain = _extractDomain(email);
    final hash = _hashEmail(email);

    return HashedEmail(
      emailHash: hash,
      emailDomain: domain,
    );
  }

  /// Quick validation for whitelisted domains.
  ///
  /// Returns true if domain is in approved list.
  /// Used for pre-flight domain validation before API calls.
  static bool isDomainAllowed(String domain, List<String> whitelist) {
    final normalized = domain.toLowerCase().trim();
    return whitelist.contains(normalized);
  }
}
