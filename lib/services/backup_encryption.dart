import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

const String encryptedBackupFormat = 'lxh-one-encrypted-backup-v1';
const String backupPasswordStorageKeyPrefix = 'lxhone_backup_password_';
const int _pbkdf2Iterations = 310000;
const int _saltLength = 16;
const String _aadText = 'LxH-ONE-DRIVE-BACKUP-v1';

String backupPasswordStorageKey(String email) =>
    backupPasswordStorageKeyPrefix +
    base64Url.encode(utf8.encode(email.trim().toLowerCase())).replaceAll('=', '');

class BackupPasswordRequiredException implements Exception {
  const BackupPasswordRequiredException();

  @override
  String toString() =>
      'This Google Drive backup is encrypted. Enter the Backup Password used when it was created.';
}

class BackupPasswordInvalidException implements Exception {
  const BackupPasswordInvalidException();

  @override
  String toString() =>
      'The Backup Password is incorrect, or the encrypted backup has been damaged.';
}

class BackupEncryptionService {
  BackupEncryptionService._();

  static final AesGcm _cipher = AesGcm.with256bits();
  static final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  );

  static bool isEncryptedEnvelope(Map<String, dynamic> value) =>
      value['format'] == encryptedBackupFormat;

  static Future<Map<String, dynamic>> encrypt(
    Map<String, dynamic> payload, {
    required String password,
  }) async {
    if (password.length < 12) {
      throw ArgumentError('Backup Password must contain at least 12 characters.');
    }

    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    final key = await _deriveKey(password, salt);
    final clearBytes = utf8.encode(jsonEncode(payload));

    final secretBox = await _cipher.encrypt(
      clearBytes,
      secretKey: key,
      aad: utf8.encode(_aadText),
    );

    return <String, dynamic>{
      'format': encryptedBackupFormat,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _pbkdf2Iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  static Future<Map<String, dynamic>> decrypt(
    Map<String, dynamic> envelope, {
    required String password,
  }) async {
    try {
      if (!isEncryptedEnvelope(envelope) ||
          envelope['kdf'] != 'PBKDF2-HMAC-SHA256' ||
          envelope['cipher'] != 'AES-256-GCM' ||
          envelope['iterations'] != _pbkdf2Iterations) {
        throw const BackupPasswordInvalidException();
      }

      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final cipherText = base64Decode(envelope['cipherText'] as String);
      final mac = base64Decode(envelope['mac'] as String);

      if (salt.length != _saltLength || nonce.length != _cipher.nonceLength ||
          mac.length != _cipher.macAlgorithm.macLength) {
        throw const BackupPasswordInvalidException();
      }

      final key = await _deriveKey(password, salt);
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(mac),
      );
      final clearBytes = await _cipher.decrypt(
        secretBox,
        secretKey: key,
        aad: utf8.encode(_aadText),
      );
      final decoded = jsonDecode(utf8.decode(clearBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BackupPasswordInvalidException();
      }
      return decoded;
    } on BackupPasswordInvalidException {
      rethrow;
    } catch (_) {
      throw const BackupPasswordInvalidException();
    }
  }

  static Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return _kdf.deriveKeyFromPassword(password: password, nonce: salt);
  }
}
