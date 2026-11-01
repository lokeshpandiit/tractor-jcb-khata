import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'backup_encryption.dart';
const String _driveScope = 'https://www.googleapis.com/auth/drive.file';
const String _driveFolderName = 'LxH ONE Backup';
const String _backupTaskName = 'lxhDailyDriveBackup';
const String _serverClientId =
    String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

const List<String> backupPreferenceKeys = <String>[
  'vehicles_data',
  'workers_data',
  'clients_data',
  'logs_data',
  'cash_data',
  'advance_requests_data',
  'driver_ledger_data',
  'sms_message_template',
  'whatsapp_message_template',
  'customer_payment_sms_template',
  'customer_payment_whatsapp_template',
  'driver_statement_sms_template',
  'driver_statement_whatsapp_template',
  'khata_migration_v2_done',
  'legacy_auto_jama_data',
  'account_initialized',
];

String accountStoragePrefix(String email) =>
    'lxhone_account_${base64Url.encode(utf8.encode(email.trim().toLowerCase())).replaceAll('=', '')}_';

class GoogleDriveBackupService {
  GoogleDriveBackupService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[_driveScope],
    serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
  );

  static GoogleSignInAccount? _currentUser;

  static bool get isConfigured => _serverClientId.isNotEmpty;
  static GoogleSignInAccount? get currentUser => _currentUser;

  static Future<GoogleSignInAccount?> signIn() async {
    _ensureConfigured();
    _currentUser = await _googleSignIn.signIn();
    return _currentUser;
  }

  static Future<GoogleSignInAccount?> signInSilently() async {
    if (!isConfigured) return null;
    _currentUser = await _googleSignIn.signInSilently();
    return _currentUser;
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  static void _ensureConfigured() {
    if (!isConfigured) {
      throw StateError(
        'Google Drive login is not configured yet. Add the Google OAuth Web Client ID as the GOOGLE_SERVER_CLIENT_ID GitHub Actions secret.',
      );
    }
  }

  static Future<Map<String, dynamic>?> restoreLatest(
    GoogleSignInAccount account, {
    String? backupPassword,
  }) async {
    _ensureConfigured();
    final client = http.Client();
    try {
      final auth = await account.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError('Google Drive authorization is missing. Sign in again to grant Drive access.');
      }
      final headers = <String, String>{'Authorization': 'Bearer $accessToken'};
      final folderId = await _findOrCreateBackupFolder(client, headers);
      final listUri = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': "'$folderId' in parents and mimeType = 'application/json' and trashed = false",
        'spaces': 'drive',
        'pageSize': '100',
        'orderBy': 'modifiedTime desc',
        'fields': 'files(id,name,mimeType,modifiedTime)',
      });

      final listResponse = await client.get(listUri, headers: headers);
      _checkResponse(listResponse, 'Could not list LxH ONE Drive backups');
      final decoded = jsonDecode(listResponse.body) as Map<String, dynamic>;
      final files = (decoded['files'] as List<dynamic>? ?? <dynamic>[]);
      if (files.isEmpty) return null;

      final fileId = (files.first as Map<String, dynamic>)['id'] as String?;
      if (fileId == null || fileId.isEmpty) return null;

      final downloadUri = Uri.https(
        'www.googleapis.com',
        '/drive/v3/files/$fileId',
        <String, String>{'alt': 'media'},
      );
      final downloadResponse = await client.get(downloadUri, headers: headers);
      _checkResponse(downloadResponse, 'Could not download the latest backup');

      final backup = jsonDecode(utf8.decode(downloadResponse.bodyBytes));
      if (backup is! Map<String, dynamic>) {
        throw const FormatException('Drive backup file is not a valid JSON object.');
      }
      Map<String, dynamic> restored = backup;
      if (BackupEncryptionService.isEncryptedEnvelope(backup)) {
        if (backupPassword == null || backupPassword.isEmpty) {
          throw const BackupPasswordRequiredException();
        }
        restored = await BackupEncryptionService.decrypt(
          backup,
          password: backupPassword,
        );
      }

      final ownerEmail = (restored['accountEmail'] ?? '').toString().toLowerCase();
      if (ownerEmail.isNotEmpty && ownerEmail != account.email.toLowerCase()) {
        throw StateError('This backup belongs to a different Google account. It was not restored.');
      }
      return restored;
    } finally {
      client.close();
    }
  }

  static Future<void> backup(
    GoogleSignInAccount account,
    Map<String, dynamic> data, {
    required String backupPassword,
    bool createNewVersion = false,
  }) async {
    _ensureConfigured();
    final client = http.Client();
    try {
      final auth = await account.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError('Google Drive authorization is missing. Sign in again to grant Drive access.');
      }
      final headers = <String, String>{'Authorization': 'Bearer $accessToken'};
      final folderId = await _findOrCreateBackupFolder(client, headers);
      final now = DateTime.now();
      final date = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final recoveryTime = now.hour.toString().padLeft(2, '0') + '-' +
          now.minute.toString().padLeft(2, '0') + '-' +
          now.second.toString().padLeft(2, '0') + '-' +
          now.millisecond.toString().padLeft(3, '0');
      final fileName = createNewVersion
          ? 'LxH ONE Backup ' + date + ' Local Recovery ' + recoveryTime + '.json'
          : 'LxH ONE Backup ' + date + '.json';
      final backupPayload = <String, dynamic>{
        'schemaVersion': 1,
        'accountEmail': account.email,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'data': data,
      };
      final encryptedPayload = await BackupEncryptionService.encrypt(
        backupPayload,
        password: backupPassword,
      );

      final query = "'$folderId' in parents and name = '$fileName' and trashed = false";
      final listUri = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': query,
        'spaces': 'drive',
        'pageSize': '10',
        'fields': 'files(id,name)',
      });
      final listResponse = await client.get(listUri, headers: headers);
      _checkResponse(listResponse, 'Could not check today\'s Drive backup');
      final listJson = jsonDecode(listResponse.body) as Map<String, dynamic>;
      final existing = (listJson['files'] as List<dynamic>? ?? <dynamic>[]);
      final existingId = existing.isEmpty
          ? null
          : (existing.first as Map<String, dynamic>)['id'] as String?;

      if (existingId != null && existingId.isNotEmpty) {
        final updateUri = Uri.https(
          'www.googleapis.com',
          '/upload/drive/v3/files/$existingId',
          <String, String>{'uploadType': 'media'},
        );
        final response = await client.patch(
          updateUri,
          headers: <String, String>{
            ...headers,
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(encryptedPayload),
        );
        _checkResponse(response, 'Could not update today\'s Drive backup');
      } else {
        final boundary = 'lxh_${Random.secure().nextInt(1 << 32)}';
        final metadata = <String, dynamic>{
          'name': fileName,
          'mimeType': 'application/json',
          'parents': <String>[folderId],
        };
        final multipartBody = '--$boundary\r\n'
            'Content-Type: application/json; charset=UTF-8\r\n\r\n'
            '${jsonEncode(metadata)}\r\n'
            '--$boundary\r\n'
            'Content-Type: application/json; charset=UTF-8\r\n\r\n'
            '${jsonEncode(encryptedPayload)}\r\n'
            '--$boundary--';
        final uploadUri = Uri.https(
          'www.googleapis.com',
          '/upload/drive/v3/files',
          <String, String>{
            'uploadType': 'multipart',
            'fields': 'id,name,modifiedTime',
          },
        );
        final response = await client.post(
          uploadUri,
          headers: <String, String>{
            ...headers,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: multipartBody,
        );
        _checkResponse(response, 'Could not upload the Drive backup');
      }
    } finally {
      client.close();
    }
  }

  static Future<String> _findOrCreateBackupFolder(
    http.Client client,
    Map<String, String> headers,
  ) async {
    final query = "'root' in parents and name = '$_driveFolderName' "
        "and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': query,
      'spaces': 'drive',
      'pageSize': '10',
      'fields': 'files(id,name)',
    });
    final response = await client.get(uri, headers: headers);
    _checkResponse(response, 'Could not find the LxH ONE Backup folder');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final files = (decoded['files'] as List<dynamic>? ?? <dynamic>[]);
    if (files.isNotEmpty) {
      final id = (files.first as Map<String, dynamic>)['id'] as String?;
      if (id != null && id.isNotEmpty) return id;
    }

    final createResponse = await client.post(
      Uri.https('www.googleapis.com', '/drive/v3/files', {
        'fields': 'id,name',
      }),
      headers: <String, String>{
        ...headers,
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'name': _driveFolderName,
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': <String>['root'],
      }),
    );
    _checkResponse(createResponse, 'Could not create the LxH ONE Backup folder');
    final created = jsonDecode(createResponse.body) as Map<String, dynamic>;
    final id = created['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Google Drive did not return a backup folder ID.');
    }
    return id;
  }

  static void _checkResponse(http.Response response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final details = response.body.length > 500
          ? response.body.substring(0, 500)
          : response.body;
      throw StateError('$action. HTTP ${response.statusCode}: $details');
    }
  }
}

@pragma('vm:entry-point')
void lxhDailyBackupDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _backupTaskName || !GoogleDriveBackupService.isConfigured) {
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('active_google_email');
      if (email == null || email.isEmpty) return true;

      final signIn = GoogleSignIn(
        scopes: <String>[_driveScope],
        serverClientId: _serverClientId,
      );
      final account = await signIn.signInSilently();
      if (account == null || account.email.toLowerCase() != email.toLowerCase()) {
        return false;
      }

      final auth = await account.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null || accessToken.isEmpty) return false;
      final prefix = accountStoragePrefix(email);
      final backupPassword = await const FlutterSecureStorage().read(
        key: backupPasswordStorageKey(email),
      );
      if (backupPassword == null || backupPassword.isEmpty) return false;

      final previouslyInitialized = prefs.getBool(prefix + 'account_initialized') ?? false;
      final hasUnsyncedLocalChanges =
          prefs.getBool(prefix + 'unsynced_local_changes') ?? false;

      // If an earlier foreground restore failed, complete it before uploading
      // anything so an empty device cannot overwrite a real cloud backup.
      if (prefs.getBool(prefix + 'drive_restore_pending') ?? false) {
        final remoteBackup = await GoogleDriveBackupService.restoreLatest(account, backupPassword: backupPassword);

        // On a first login with no cloud file yet, leave legacy data migration
        // to the foreground app instead of uploading an empty snapshot.
        if (remoteBackup == null && !previouslyInitialized) return true;

        final remoteData = remoteBackup?['data'];
        // When this phone has newer unsynced work, preserve it locally and
        // upload a separate recovery file rather than replacing the Drive file.
        if (remoteData is Map && !hasUnsyncedLocalChanges) {
          for (final entry in remoteData.entries) {
            final key = entry.key.toString();
            if (!backupPreferenceKeys.contains(key)) continue;
            final value = entry.value;
            if (value is String) {
              await prefs.setString(prefix + key, value);
            } else if (value is bool) {
              await prefs.setBool(prefix + key, value);
            } else if (value is int) {
              await prefs.setInt(prefix + key, value);
            } else if (value is double) {
              await prefs.setDouble(prefix + key, value);
            } else if (value is List<String>) {
              await prefs.setStringList(prefix + key, value);
            }
          }
        }
        await prefs.setBool(prefix + 'drive_restore_pending', false);
        await prefs.setBool(prefix + 'account_initialized', true);
      }

      if (!(prefs.getBool(prefix + 'account_initialized') ?? false)) {
        return true;
      }

      final snapshot = <String, dynamic>{};
      for (final key in backupPreferenceKeys) {
        final value = prefs.get(prefix + key);
        if (value != null) snapshot[key] = value;
      }
      // If Android terminates this worker while uploading, the next run knows
      // the local snapshot may not have reached Drive and preserves it separately.
      await prefs.setBool(prefix + 'unsynced_local_changes', true);
      await GoogleDriveBackupService.backup(
        account,
        snapshot,
        backupPassword: backupPassword,
        createNewVersion: hasUnsyncedLocalChanges,
      );
      await prefs.setBool(prefix + 'unsynced_local_changes', false);
      await prefs.setString(
        'lxh_last_backup_' + account.email,
        DateTime.now().toIso8601String(),
      );
      return true;
    } catch (_) {
      try {
        final retryPrefs = await SharedPreferences.getInstance();
        final retryEmail = retryPrefs.getString('active_google_email');
        if (retryEmail != null && retryEmail.isNotEmpty) {
          await retryPrefs.setBool(
            accountStoragePrefix(retryEmail) + 'unsynced_local_changes',
            true,
          );
        }
      } catch (_) {
        // WorkManager will retry; do not let a secondary preference error escape.
      }
      return false;
    }
  });
}

Future<void> initializeLxhDailyBackup() async {
  if (!GoogleDriveBackupService.isConfigured) return;
  await Workmanager().initialize(lxhDailyBackupDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'lxh-daily-drive-backup',
    _backupTaskName,
    frequency: const Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
