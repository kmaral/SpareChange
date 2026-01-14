import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  // Use a secure key in production - should be stored securely
  // For now using a constant, but in production you should use Flutter Secure Storage
  static const String _secretKey = 'SpareChange2026SecureKeyForEncrypt';

  late final Key _key;
  late final IV _iv;
  late final Encrypter _encrypter;

  void initialize() {
    // Create a 32-byte key from the secret
    final keyBytes = sha256.convert(utf8.encode(_secretKey)).bytes;
    _key = Key(Uint8List.fromList(keyBytes));

    // Use first 16 bytes of key as IV
    _iv = IV(Uint8List.fromList(keyBytes.sublist(0, 16)));

    _encrypter = Encrypter(AES(_key));
  }

  /// Encrypt a string value
  String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      print('Encryption error: $e');
      return plainText; // Fallback to plain text on error
    }
  }

  /// Decrypt a string value
  String decrypt(String encryptedText) {
    if (encryptedText.isEmpty) return '';
    try {
      final encrypted = Encrypted.fromBase64(encryptedText);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      print('Decryption error: $e');
      return encryptedText; // Fallback to returning as-is on error
    }
  }

  /// Encrypt a nullable string
  String? encryptNullable(String? plainText) {
    if (plainText == null || plainText.isEmpty) return plainText;
    return encrypt(plainText);
  }

  /// Decrypt a nullable string
  String? decryptNullable(String? encryptedText) {
    if (encryptedText == null || encryptedText.isEmpty) return encryptedText;
    return decrypt(encryptedText);
  }
}
