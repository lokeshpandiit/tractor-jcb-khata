import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tractor_jcb_khata/services/backup_encryption.dart';

void main() {
  const password = 'LxH-Backup-Passphrase-2026';

  test('encrypted backup hides data and restores it with the same password', () async {
    final payload = <String, dynamic>{
      'accountEmail': 'test@example.com',
      'data': <String, dynamic>{
        'cash_data': '[{"title":"Customer payment","amount":5000}]',
        'clients_data': '[{"name":"Private customer"}]',
      },
    };

    final encrypted = await BackupEncryptionService.encrypt(
      payload,
      password: password,
    );

    expect(encrypted['format'], encryptedBackupFormat);
    expect(jsonEncode(encrypted), isNot(contains('Private customer')));
    expect(jsonEncode(encrypted), isNot(contains('Customer payment')));

    final restored = await BackupEncryptionService.decrypt(
      encrypted,
      password: password,
    );
    expect(restored, payload);
  });

  test('encrypted backup rejects a wrong password', () async {
    final encrypted = await BackupEncryptionService.encrypt(
      <String, dynamic>{'data': <String, dynamic>{'cash_data': 'private'}},
      password: password,
    );

    await expectLater(
      BackupEncryptionService.decrypt(encrypted, password: 'Wrong-Password-000'),
      throwsA(isA<BackupPasswordInvalidException>()),
    );
  });

  test('new backup passwords must be at least 12 characters', () async {
    await expectLater(
      BackupEncryptionService.encrypt(
        <String, dynamic>{'data': <String, dynamic>{}},
        password: 'short',
      ),
      throwsArgumentError,
    );
  });


  test('every encryption creates a fresh salt and nonce', () async {
    final payload = <String, dynamic>{
      'data': <String, dynamic>{'cash_data': 'sensitive-records'},
    };

    final first = await BackupEncryptionService.encrypt(payload, password: password);
    final second = await BackupEncryptionService.encrypt(payload, password: password);

    expect(first['salt'], isNot(second['salt']));
    expect(first['nonce'], isNot(second['nonce']));
    expect(
      await BackupEncryptionService.decrypt(first, password: password),
      payload,
    );
    expect(
      await BackupEncryptionService.decrypt(second, password: password),
      payload,
    );
  });

  test('tampered ciphertext is rejected', () async {
    final encrypted = await BackupEncryptionService.encrypt(
      <String, dynamic>{'data': <String, dynamic>{'cash_data': 'private'}},
      password: password,
    );

    final tampered = Map<String, dynamic>.from(encrypted);
    final cipherBytes = base64Decode(tampered['cipherText'] as String);
    cipherBytes[0] = cipherBytes[0] ^ 1;
    tampered['cipherText'] = base64Encode(cipherBytes);

    await expectLater(
      BackupEncryptionService.decrypt(tampered, password: password),
      throwsA(isA<BackupPasswordInvalidException>()),
    );
  });

  test('legacy plaintext backup is detected for backward-compatible restore', () {
    final legacyBackup = <String, dynamic>{
      'accountEmail': 'test@example.com',
      'data': <String, dynamic>{'cash_data': 'legacy-json'},
    };
    expect(BackupEncryptionService.isEncryptedEnvelope(legacyBackup), isFalse);
  });

  test('account backup password storage keys are isolated by email', () {
    expect(
      backupPasswordStorageKey('one@example.com'),
      isNot(backupPasswordStorageKey('two@example.com')),
    );
    expect(
      backupPasswordStorageKey('TEST@example.com'),
      backupPasswordStorageKey(' test@example.com '),
    );
  });
}
