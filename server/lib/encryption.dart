import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  late final enc.Key _key;
  late final enc.Encrypter _encrypter;

  EncryptionService(String keyString) {
    final padded = keyString.padRight(32, '0').substring(0, 32);
    _key = enc.Key.fromUtf8(padded);
    _encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
  }

  String encrypt(String text) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(text, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  String decrypt(String encryptedText) {
    final parts = encryptedText.split(':');
    if (parts.length < 2) return encryptedText;
    final iv = enc.IV.fromBase64(parts[0]);
    final data = parts.sublist(1).join(':');
    return _encrypter.decrypt64(data, iv: iv);
  }

  /// One-way hash for lookups (email_hash, username_hash)
  String hash(String text) {
    return sha256.convert(utf8.encode(text.toLowerCase().trim())).toString();
  }

  /// Hash password with random salt
  String hashPassword(String password) {
    final random = Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    final saltB64 = base64Url.encode(salt);
    final hash = Hmac(sha256, salt).convert(utf8.encode(password));
    return '$saltB64:${hash.toString()}';
  }

  /// Verify password against stored hash
  bool verifyPassword(String password, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;
    final salt = base64Url.decode(parts[0]);
    final hash = Hmac(sha256, salt).convert(utf8.encode(password));
    return hash.toString() == parts[1];
  }
}
