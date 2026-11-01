import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/backup_encryption.dart';
import 'services/google_drive_backup.dart';
import 'services/google_sheets_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeLxhDailyBackup();
  runApp(const FleetKhataApp());
}

class FleetKhataApp extends StatelessWidget {
  const FleetKhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LxH ONE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE65100),
          primary: const Color(0xFFE65100),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class Vehicle {
  final String id;
  String name;
  String number;
  final String type;
  double defaultRate;

  Vehicle({required this.id, required this.name, required this.number, required this.type, required this.defaultRate});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'number': number, 'type': type, 'defaultRate': defaultRate};
  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'],
    name: json['name'],
    number: json['number'],
    type: json['type'],
    defaultRate: (json['defaultRate'] ?? 0).toDouble(),
  );
}

class Person {
  final String id;
  String name;
  String phone;
  final String role;
  double salaryAmount;
  String salaryType;

  Person({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.salaryAmount = 0,
    this.salaryType = 'Monthly',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'role': role,
    'salaryAmount': salaryAmount,
    'salaryType': salaryType,
  };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
    salaryAmount: (json['salaryAmount'] ?? 0).toDouble(),
    salaryType: json['salaryType']?.toString() ?? 'Monthly',
  );
}

class WorkLog {
  final String id;
  final String date;
  final String vehicleName;
  final String vehicleType;
  final String driverName;
  final String driverId;
  final String clientName;
  final String clientPhone;
  final String clientId;
  final String vehicleNumber;
  final double hours;
  final double rate;
  final double totalAmount;

  WorkLog({
    required this.id,
    required this.date,
    required this.vehicleName,
    required this.vehicleType,
    required this.driverName,
    this.driverId = '',
    required this.clientName,
    required this.clientPhone,
    this.clientId = '',
    this.vehicleNumber = '',
    required this.hours,
    required this.rate,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'vehicleName': vehicleName, 'vehicleType': vehicleType,
    'driverName': driverName, 'driverId': driverId,
    'clientName': clientName, 'clientPhone': clientPhone,
    'clientId': clientId, 'vehicleNumber': vehicleNumber,
    'hours': hours, 'rate': rate, 'totalAmount': totalAmount
  };

  factory WorkLog.fromJson(Map<String, dynamic> json) => WorkLog(
    id: json['id'] ?? '',
    date: json['date'] ?? '',
    vehicleName: json['vehicleName'] ?? '',
    vehicleType: json['vehicleType'] ?? '',
    driverName: json['driverName'] ?? '',
    driverId: json['driverId'] ?? '',
    clientName: json['clientName'] ?? '',
    clientPhone: json['clientPhone'] ?? '',
    clientId: json['clientId'] ?? '',
    vehicleNumber: json['vehicleNumber'] ?? '',
    hours: (json['hours'] ?? 0).toDouble(),
    rate: (json['rate'] ?? 0).toDouble(),
    totalAmount: (json['totalAmount'] ?? 0).toDouble(),
  );
}

class CashEntry {
  final String id;
  final String title;
  final double amount;
  final String type;
  final String date;
  final String partyId;
  final String partyName;

  CashEntry({
    String? id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.partyId = '',
    this.partyName = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'amount': amount, 'type': type, 'date': date,
    'partyId': partyId, 'partyName': partyName,
  };

  factory CashEntry.fromJson(Map<String, dynamic> json) => CashEntry(
    id: json['id']?.toString(),
    title: json['title'] ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
    type: json['type'] ?? '',
    date: json['date'] ?? '',
    partyId: json['partyId'] ?? '',
    partyName: json['partyName'] ?? '',
  );
}


class AdvanceRequest {
  final String id;
  final String name;
  final double amount;
  final String date;
  final String note;

  AdvanceRequest({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'date': date,
    'note': note,
  };

  factory AdvanceRequest.fromJson(Map<String, dynamic> json) => AdvanceRequest(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
    date: json['date']?.toString() ?? '',
    note: json['note']?.toString() ?? '',
  );
}

class DriverLedgerEntry {
  final String id;
  final String driverId;
  final String type;
  final double amount;
  final String reason;
  final String date;

  DriverLedgerEntry({
    required this.id,
    required this.driverId,
    required this.type,
    required this.amount,
    required this.reason,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'driverId': driverId,
    'type': type,
    'amount': amount,
    'reason': reason,
    'date': date,
  };

  factory DriverLedgerEntry.fromJson(Map<String, dynamic> json) =>
      DriverLedgerEntry(
        id: json['id']?.toString() ?? '',
        driverId: json['driverId']?.toString() ?? '',
        type: json['type']?.toString() ?? 'Advance',
        amount: (json['amount'] ?? 0).toDouble(),
        reason: json['reason']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
      );
}


String _normalizePhone(String value) {
  var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('91') && digits.length == 12) digits = digits.substring(2);
  if (digits.startsWith('0') && digits.length == 11) digits = digits.substring(1);
  return digits;
}


Future<void> _openSmsComposerWithMessage(BuildContext context, String rawPhone, String message) async {
  final phone = _normalizePhone(rawPhone);
  if (phone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile number is not valid.')));
    return;
  }
  try {
    await const MethodChannel('com.example.tractor_jcb_khata/sms').invokeMethod<bool>(
      'openSms',
      <String, String>{'phone': phone, 'message': message},
    );
  } on PlatformException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SMS app could not be opened: ${e.message ?? e.code}')),
    );
  } on MissingPluginException {
    final uri = Uri(scheme: 'smsto', path: phone, queryParameters: <String, String>{'body': message});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS app could not be opened.')));
    }
  }
}

Future<void> _openWhatsAppWithMessage(BuildContext context, String rawPhone, String message) async {
  var phone = _normalizePhone(rawPhone);
  if (phone.length == 10) phone = '91$phone';
  if (phone.length < 10 || phone.length > 15) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mobile number is not valid.')));
    return;
  }
  final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp could not be opened.')));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WhatsApp could not be opened: $e')));
  }
}


class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const FlutterSecureStorage _backupPasswordStorage = FlutterSecureStorage();

  int _currentIndex = 0;
  DateTime? selectedOutstandingDate;

  List<Vehicle> vehicles = [];
  List<Person> workers = [];
  List<Person> clients = [];
  List<WorkLog> logs = [];
  List<CashEntry> cashBook = [];
  List<AdvanceRequest> advanceRequests = [];
  List<DriverLedgerEntry> driverLedger = [];

  GoogleSignInAccount? _activeGoogleAccount;
  bool _authReady = false;
  bool _authBusy = false;
  String? _authError;
  bool _driveRestoreFailed = false;
  bool _offlineMode = false;

  String _accountKey(String key) {
    final email = _activeGoogleAccount?.email;
    return email == null ? key : accountStoragePrefix(email) + key;
  }

  @override
  void initState() {
    super.initState();
    _initializeAccount();
  }

  Future<void> _initializeAccount() async {
    try {
      final account = await GoogleDriveBackupService.signInSilently();
      if (account != null) {
        await _activateAccount(account);
      }
    } catch (e) {
      _authError = e.toString();
    } finally {
      if (mounted) setState(() => _authReady = true);
    }
  }

  Future<void> _useOfflineMode() async {
    setState(() {
      _offlineMode = true;
      _authError = null;
    });
    await _loadData();
  }

  Future<void> _signInGoogle() async {
    if (!GoogleDriveBackupService.isConfigured) {
      setState(() => _authError =
          'Google OAuth is not configured yet. Add GOOGLE_SERVER_CLIENT_ID in GitHub Actions and register this Android app in Google Cloud.');
      return;
    }
    setState(() {
      _authBusy = true;
      _authError = null;
      _offlineMode = false;
    });
    try {
      final account = await GoogleDriveBackupService.signIn();
      if (account == null) {
        _authError = 'Google sign-in was cancelled.';
      } else {
        await _activateAccount(account);
      }
    } catch (e) {
      _authError = e.toString();
    } finally {
      if (mounted) setState(() {
        _authBusy = false;
        _authReady = true;
      });
    }
  }

  Future<String?> _promptBackupPassword({
    required bool createNew,
    String? errorMessage,
  }) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? validationError = errorMessage;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(createNew ? 'Protect Your LxH ONE Backup' : 'Unlock Your LxH ONE Backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  createNew
                      ? 'Create a separate Backup Password. Use the same password when restoring on another phone.'
                      : 'Enter the Backup Password that was used on the phone where this backup was created.',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Backup Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (createNew) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Backup Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Important: Keep this password safe. LxH ONE cannot recover it. If you forget it, encrypted Drive backups cannot be opened.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 8),
                  Text(validationError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final password = passwordController.text;
                if (password.isEmpty) {
                  setDialogState(() => validationError = 'Backup Password is required.');
                  return;
                }
                if (createNew && password.length < 12) {
                  setDialogState(() => validationError = 'Use at least 12 characters for a stronger password.');
                  return;
                }
                if (createNew && password != confirmController.text) {
                  setDialogState(() => validationError = 'Both passwords do not match.');
                  return;
                }
                Navigator.pop(dialogContext, password);
              },
              child: Text(createNew ? 'Create Password' : 'Unlock Backup'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    confirmController.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _restoreBackupWithPassword(
    GoogleSignInAccount account,
  ) async {
    final storageKey = backupPasswordStorageKey(account.email);
    String? password = await _backupPasswordStorage.read(key: storageKey);
    Map<String, dynamic>? backup;
    var failedPasswordAttempts = 0;

    while (true) {
      try {
        backup = await GoogleDriveBackupService.restoreLatest(
          account,
          backupPassword: password,
        );
        break;
      } on BackupPasswordRequiredException {
        password = await _promptBackupPassword(createNew: false);
        if (password == null) {
          throw StateError('Backup restore was cancelled. Enter the Backup Password to continue.');
        }
      } on BackupPasswordInvalidException {
        failedPasswordAttempts++;
        if (failedPasswordAttempts >= 3) {
          throw StateError('Backup Password was incorrect three times. No cloud data was changed.');
        }
        password = await _promptBackupPassword(
          createNew: false,
          errorMessage: 'Incorrect Backup Password. Please try again.',
        );
        if (password == null) {
          throw StateError('Backup restore was cancelled. No cloud data was changed.');
        }
      }
    }

    // A missing password means this is a first backup or a legacy plaintext
    // backup. Upgrade it by creating the encryption password before app access.
    if (password == null || password.isEmpty) {
      password = await _promptBackupPassword(createNew: true);
      if (password == null) {
        throw StateError('Create a Backup Password before enabling encrypted Google Drive backup.');
      }
    }

    await _backupPasswordStorage.write(key: storageKey, value: password);
    return backup;
  }

  Future<void> _activateAccount(GoogleSignInAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = accountStoragePrefix(account.email);
    final scopedKeys = backupPreferenceKeys.map((key) => prefix + key);
    final hasScopedData = scopedKeys.any(prefs.containsKey);
    final hasUnsyncedLocalChanges =
        prefs.getBool(prefix + 'unsynced_local_changes') ?? false;
    Map<String, dynamic>? cloudBackup;
    _driveRestoreFailed = false;

    try {
      cloudBackup = await _restoreBackupWithPassword(account);
    } catch (e) {
      _driveRestoreFailed = true;
      _authError = 'Google account signed in, but Drive restore failed: ' + e.toString();
    }

    final cloudData = cloudBackup?['data'];
    if (cloudData is Map && !hasUnsyncedLocalChanges) {
      for (final entry in cloudData.entries) {
        final key = entry.key.toString();
        if (!backupPreferenceKeys.contains(key)) continue;
        final value = entry.value;
        final destinationKey = prefix + key;
        if (value is String) {
          await prefs.setString(destinationKey, value);
        } else if (value is bool) {
          await prefs.setBool(destinationKey, value);
        } else if (value is int) {
          await prefs.setInt(destinationKey, value);
        } else if (value is double) {
          await prefs.setDouble(destinationKey, value);
        } else if (value is List<String>) {
          await prefs.setStringList(destinationKey, value);
        }
      }
    } else if (cloudBackup == null &&
        !hasScopedData &&
        !(prefs.getBool('lxh_has_linked_google_account') ?? false) &&
        !_driveRestoreFailed) {
      // First-ever Google account on this installation: preserve legacy local
      // data by moving it into that account's isolated namespace.
      for (final key in backupPreferenceKeys) {
        final legacyString = prefs.getString(key);
        final legacyBool = prefs.getBool(key);
        if (legacyString != null) {
          await prefs.setString(prefix + key, legacyString);
        } else if (legacyBool != null) {
          await prefs.setBool(prefix + key, legacyBool);
        }
      }
    }

    await prefs.setBool(prefix + 'drive_restore_pending', _driveRestoreFailed);
    if (_driveRestoreFailed) {
      // Keep the app behind the login gate until Drive restore succeeds.
      // The background worker can retry, but must restore before any upload.
      await prefs.setString('active_google_email', account.email);
      _activeGoogleAccount = null;
      _offlineMode = false;
      return;
    }

    await prefs.setString('active_google_email', account.email);
    await prefs.setBool('lxh_has_linked_google_account', true);
    await prefs.setBool(prefix + 'account_initialized', true);
    _activeGoogleAccount = account;
    _offlineMode = false;
    await _loadData();
    await _saveData();
  }

  Future<void> _openBackupManager() async {
    final account = _activeGoogleAccount;
    if (account == null) return;

    final prefs = await SharedPreferences.getInstance();
    final prefix = accountStoragePrefix(account.email);
    var lastBackup = prefs.getString('lxh_last_backup_' + account.email);
    var lastBackupDate = DateTime.tryParse(lastBackup ?? '');
    var pending = prefs.getBool(prefix + 'unsynced_local_changes') ?? false;
    var sheetsId = prefs.getString(
      prefix + GoogleSheetsSyncService.spreadsheetIdPreferenceKey,
    );
    var sheetsPending = prefs.getBool(prefix + 'google_sheets_sync_pending') ?? true;
    var lastSheetsSync = prefs.getString('lxh_last_sheets_sync_' + account.email);
    var lastSheetsSyncDate = DateTime.tryParse(lastSheetsSync ?? '');
    var passwordSaved = (await _backupPasswordStorage.read(
      key: backupPasswordStorageKey(account.email),
    ))?.isNotEmpty ?? false;
    var busy = false;
    String? statusMessage;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_done, color: Color(0xFFE65100), size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Backup & Restore', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('Google Account'),
                  subtitle: Text(account.email),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline, color: Colors.green),
                  title: const Text('Backup Encryption'),
                  subtitle: Text(passwordSaved
                      ? 'AES-256-GCM enabled. Backup Password saved securely on this phone.'
                      : 'Backup Password is not saved on this phone.'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    pending ? Icons.sync_problem : Icons.cloud_done,
                    color: pending ? Colors.orange : Colors.green,
                  ),
                  title: const Text('Last Successful Backup'),
                  subtitle: Text(lastBackupDate == null
                      ? 'No successful backup recorded on this phone yet.'
                      : DateFormat('dd MMM yyyy, hh:mm a').format(lastBackupDate!.toLocal())),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.table_chart,
                    color: sheetsPending || sheetsId == null ? Colors.orange : Colors.green,
                  ),
                  title: const Text('Google Sheets — Customer & Driver Ledgers'),
                  subtitle: Text(
                    sheetsId == null
                        ? 'Spreadsheet not created yet.'
                        : (sheetsPending
                            ? 'Sync pending. The saved spreadsheet will be retried.'
                            : 'Last sync: ${lastSheetsSyncDate == null ? 'not recorded' : DateFormat('dd MMM yyyy, hh:mm a').format(lastSheetsSyncDate!.toLocal())}'),
                  ),
                ),
                if (sheetsId != null)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://docs.google.com/spreadsheets/d/$sheetsId/edit'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Google Sheets Ledger'),
                  ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          setSheetState(() {
                            busy = true;
                            statusMessage = 'Syncing customer and driver ledgers...';
                          });
                          await _syncToGoogleSheets();
                          if (!sheetContext.mounted) return;
                          final refreshed = await SharedPreferences.getInstance();
                          final newId = refreshed.getString(
                            prefix + GoogleSheetsSyncService.spreadsheetIdPreferenceKey,
                          );
                          final newPending = refreshed.getBool(prefix + 'google_sheets_sync_pending') ?? true;
                          final newLast = refreshed.getString('lxh_last_sheets_sync_' + account.email);
                          setSheetState(() {
                            busy = false;
                            sheetsId = newId;
                            sheetsPending = newPending;
                            lastSheetsSync = newLast;
                            lastSheetsSyncDate = DateTime.tryParse(newLast ?? '');
                            statusMessage = !newPending && newId != null
                                ? 'Google Sheets ledger synced successfully.'
                                : 'Sheets sync is still pending. Check Internet/API access and retry.';
                          });
                        },
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync Google Sheets Now'),
                ),
                if (pending)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Some local changes are waiting to sync to Drive. The next successful backup will be saved as a recovery version.',
                      style: TextStyle(color: Colors.deepOrange, fontSize: 12),
                    ),
                  ),
                if (statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(statusMessage!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ElevatedButton.icon(
                  onPressed: busy || !passwordSaved || _driveRestoreFailed
                      ? null
                      : () async {
                          setSheetState(() {
                            busy = true;
                            statusMessage = 'Creating encrypted Google Drive backup...';
                          });
                          await _backupToDrive();
                          if (!sheetContext.mounted) return;
                          final refreshed = await SharedPreferences.getInstance();
                          final newLast = refreshed.getString('lxh_last_backup_' + account.email);
                          final newPending = refreshed.getBool(prefix + 'unsynced_local_changes') ?? false;
                          setSheetState(() {
                            busy = false;
                            lastBackup = newLast;
                            lastBackupDate = DateTime.tryParse(newLast ?? '');
                            pending = newPending;
                            statusMessage = !newPending && newLast != null
                                ? 'Encrypted backup completed successfully.'
                                : 'Backup did not complete. Local data is safe; check Internet and retry.';
                          });
                        },
                  icon: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload),
                  label: Text(busy ? 'Backing up...' : 'Backup Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Daily automatic backup runs when Android schedules the background task and Internet is available. Keep your Backup Password safe for restoring on another phone.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeGoogleAccount() async {
    await _saveData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_google_email');
    await GoogleDriveBackupService.signOut();
    if (!mounted) return;
    setState(() {
      _activeGoogleAccount = null;
      _offlineMode = false;
      vehicles = [];
      workers = [];
      clients = [];
      logs = [];
      cashBook = [];
      advanceRequests = [];
      driverLedger = [];
      _authError = null;
      _authReady = true;
    });
  }

  Widget _buildLoginScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_sync, size: 54, color: Color(0xFFE65100)),
                const SizedBox(height: 12),
                const Text('LxH ONE Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Sign in with Google to keep your Tractor, JCB, Worker, Party and Khata data in your own Google Drive backup.',
                  textAlign: TextAlign.center,
                ),
                if (_authError != null) ...[
                  const SizedBox(height: 12),
                  Text(_authError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _authBusy ? null : _signInGoogle,
                    icon: const Icon(Icons.login),
                    label: Text(_authBusy ? 'Please wait...' : (_driveRestoreFailed ? 'Retry Google Drive Restore' : 'Continue with Google')),
                  ),
                ),
                if (!_driveRestoreFailed) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _authBusy ? null : _useOfflineMode,
                    child: const Text('Continue Without Google for Now'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }


  Future<void> _loadData() async {
    // Clear the previous profile before loading the selected Google account.
    vehicles = [];
    workers = [];
    clients = [];
    logs = [];
    cashBook = [];
    advanceRequests = [];
    driverLedger = [];
    final prefs = await SharedPreferences.getInstance();
    
    final vehiclesString = prefs.getString(_accountKey('vehicles_data'));
    if (vehiclesString != null) {
      final List decoded = jsonDecode(vehiclesString);
      vehicles = decoded.map((e) => Vehicle.fromJson(e)).toList();
    } else {
      vehicles = [
        Vehicle(id: '1', name: 'Mahindra 575 DI', number: 'HR-24-A-1020', type: 'Tractor', defaultRate: 800),
        Vehicle(id: '2', name: 'Swaraj 855 FE', number: 'HR-24-B-4500', type: 'Tractor', defaultRate: 850),
        Vehicle(id: '3', name: 'JCB 3DX Super', number: 'HR-24-E-9901', type: 'JCB', defaultRate: 1400),
      ];
    }

    final workersString = prefs.getString(_accountKey('workers_data'));
    if (workersString != null) {
      final List decoded = jsonDecode(workersString);
      workers = decoded.map((e) => Person.fromJson(e)).toList();
    } else {
      workers = [
        Person(id: 'w1', name: 'Ramesh Driver', phone: '9876543210', role: 'Worker'),
        Person(id: 'w2', name: 'Suresh Operator', phone: '9123456780', role: 'Worker'),
      ];
    }

    final clientsString = prefs.getString(_accountKey('clients_data'));
    if (clientsString != null) {
      final List decoded = jsonDecode(clientsString);
      clients = decoded.map((e) => Person.fromJson(e)).toList();
    } else {
      clients = [
        Person(id: 'c1', name: 'Satish Zamindar', phone: '9988776655', role: 'Client'),
        Person(id: 'c2', name: 'Amit Builder', phone: '9416012345', role: 'Client'),
      ];
    }

    final logsString = prefs.getString(_accountKey('logs_data'));
    if (logsString != null) {
      final List decoded = jsonDecode(logsString);
      final loadedLogs = decoded.map((e) => WorkLog.fromJson(e)).toList();
      logs = loadedLogs.map((log) {
        if (log.clientId.isNotEmpty) return log;
        final phone = _normalizePhone(log.clientPhone);
        final phoneMatches = clients.where((p) =>
          phone.isNotEmpty && _normalizePhone(p.phone) == phone
        ).toList();
        Person? match;
        if (phoneMatches.length == 1) {
          match = phoneMatches.first;
        } else if (phoneMatches.isEmpty) {
          final normalizedName = log.clientName.trim().toLowerCase();
          final nameMatches = clients.where((p) =>
            p.name.trim().toLowerCase() == normalizedName
          ).toList();
          if (nameMatches.length == 1) match = nameMatches.first;
        }
        return WorkLog(
          id: log.id, date: log.date, vehicleName: log.vehicleName,
          vehicleType: log.vehicleType, driverName: log.driverName,
          driverId: log.driverId,
          clientName: log.clientName, clientPhone: log.clientPhone,
          clientId: match?.id ?? '', vehicleNumber: log.vehicleNumber,
          hours: log.hours, rate: log.rate, totalAmount: log.totalAmount,
        );
      }).toList();
    }

    bool isLegacyAutoJama(CashEntry entry) {
      if (entry.type != 'Jama' || entry.partyId.isNotEmpty) return false;
      return logs.any((log) =>
        entry.title == log.clientName + ' (' + log.vehicleName + ')' &&
        entry.amount == log.totalAmount &&
        entry.date == log.date
      );
    }

    final cashString = prefs.getString(_accountKey('cash_data'));
    final migrationDone = prefs.getBool(_accountKey('khata_migration_v2_done')) ?? false;
    final archivedString = prefs.getString(_accountKey('legacy_auto_jama_data'));
    final archivedEntries = archivedString == null
        ? <CashEntry>[]
        : (jsonDecode(archivedString) as List).map((e) => CashEntry.fromJson(e)).toList();

    if (cashString != null) {
      final List decoded = jsonDecode(cashString);
      final loadedEntries = decoded.map((e) => CashEntry.fromJson(e)).toList();
      cashBook = loadedEntries;

      // A previous app revision archived every Jama entry, including real
      // receipts. Recover genuine receipts from that archive, but leave only
      // the exact old auto-generated bill rows archived.
      final genuineArchivedReceipts = archivedEntries.where((entry) =>
        entry.type == 'Jama' && !isLegacyAutoJama(entry)
      ).toList();
      for (final archivedReceipt in genuineArchivedReceipts) {
        final alreadyPresent = cashBook.any((entry) =>
          entry.id == archivedReceipt.id ||
          (entry.title == archivedReceipt.title &&
           entry.amount == archivedReceipt.amount &&
           entry.date == archivedReceipt.date &&
           entry.partyId == archivedReceipt.partyId)
        );
        if (!alreadyPresent) cashBook.add(archivedReceipt);
      }

      final legacyAutoJama = <CashEntry>[
        ...archivedEntries.where(isLegacyAutoJama),
        ...loadedEntries.where(isLegacyAutoJama),
      ];
      final uniqueLegacyAutoJama = <CashEntry>[];
      for (final entry in legacyAutoJama) {
        if (!uniqueLegacyAutoJama.any((saved) => saved.id == entry.id)) {
          uniqueLegacyAutoJama.add(entry);
        }
      }
      await prefs.setString(_accountKey('legacy_auto_jama_data'),
          jsonEncode(uniqueLegacyAutoJama.map((e) => e.toJson()).toList()));

      if (!migrationDone || genuineArchivedReceipts.isNotEmpty) {
        cashBook.removeWhere(isLegacyAutoJama);
        await prefs.setString(_accountKey('cash_data'),
            jsonEncode(cashBook.map((e) => e.toJson()).toList()));
      }
    }
    final advanceString = prefs.getString(_accountKey('advance_requests_data'));
    if (advanceString != null) {
      final List decoded = jsonDecode(advanceString);
      advanceRequests = decoded.map((e) => AdvanceRequest.fromJson(e)).toList();
    }
    final driverLedgerString = prefs.getString(_accountKey('driver_ledger_data'));
    if (driverLedgerString != null) {
      final List decoded = jsonDecode(driverLedgerString);
      driverLedger = decoded.map((e) => DriverLedgerEntry.fromJson(e)).toList();
    } else {
      driverLedger = [];
    }
    await prefs.setBool(_accountKey('khata_migration_v2_done'), true);
    await prefs.setString(_accountKey('logs_data'), jsonEncode(logs.map((e) => e.toJson()).toList()));
    if (mounted) setState(() {});
  }

  Future<void> _saveData() async {
    if (_activeGoogleAccount == null && !_offlineMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountKey('vehicles_data'), jsonEncode(vehicles.map((e) => e.toJson()).toList()));
    await prefs.setString(_accountKey('workers_data'), jsonEncode(workers.map((e) => e.toJson()).toList()));
    await prefs.setString(_accountKey('clients_data'), jsonEncode(clients.map((e) => e.toJson()).toList()));
    await prefs.setString(_accountKey('logs_data'), jsonEncode(logs.map((e) => e.toJson()).toList()));
    await prefs.setString(_accountKey('cash_data'), jsonEncode(cashBook.map((e) => e.toJson()).toList()));
    await prefs.setString(_accountKey('advance_requests_data'), jsonEncode(advanceRequests.map((e) => e.toJson()).toList()));
    await prefs.setString(
      _accountKey('driver_ledger_data'),
      jsonEncode(driverLedger.map((e) => e.toJson()).toList()),
    );
    await prefs.setBool(_accountKey('khata_migration_v2_done'), true);
    if (_activeGoogleAccount != null) {
      await _syncToGoogleSheets();
      await _backupToDrive();
    }
  }

  Future<void> _syncToGoogleSheets() async {
    final account = _activeGoogleAccount;
    if (account == null || _driveRestoreFailed) return;
    final prefs = await SharedPreferences.getInstance();
    final prefix = accountStoragePrefix(account.email);
    try {
      final auth = await account.authentication;
      final accessToken = auth.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError('Google authorization is missing for Sheets sync.');
      }

      final snapshot = <String, dynamic>{};
      for (final key in backupPreferenceKeys) {
        final stringValue = prefs.getString(prefix + key);
        final boolValue = prefs.getBool(prefix + key);
        if (stringValue != null) {
          snapshot[key] = stringValue;
        } else if (boolValue != null) {
          snapshot[key] = boolValue;
        }
      }

      final existingId = prefs.getString(
        prefix + GoogleSheetsSyncService.spreadsheetIdPreferenceKey,
      );
      final result = await GoogleSheetsSyncService.sync(
        accessToken: accessToken,
        accountEmail: account.email,
        snapshot: snapshot,
        spreadsheetId: existingId,
        onSpreadsheetIdCreated: (id) async {
          await prefs.setString(
            prefix + GoogleSheetsSyncService.spreadsheetIdPreferenceKey,
            id,
          );
        },
      );
      await prefs.setString(
        prefix + GoogleSheetsSyncService.spreadsheetIdPreferenceKey,
        result.spreadsheetId,
      );
      await prefs.setBool(prefix + 'google_sheets_sync_pending', false);
      await prefs.setString(
        'lxh_last_sheets_sync_' + account.email,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      await prefs.setBool(prefix + 'google_sheets_sync_pending', true);
      // Local save and encrypted Drive backup must continue even if Sheets is offline.
    }
  }

  Future<void> _backupToDrive() async {
    final account = _activeGoogleAccount;
    if (account == null || _driveRestoreFailed) return;
    final prefs = await SharedPreferences.getInstance();
    final prefix = accountStoragePrefix(account.email);
    final backupPassword = await _backupPasswordStorage.read(
      key: backupPasswordStorageKey(account.email),
    );
    if (backupPassword == null || backupPassword.isEmpty) {
      await prefs.setBool(prefix + 'unsynced_local_changes', true);
      return;
    }
    final hasUnsyncedLocalChanges =
        prefs.getBool(prefix + 'unsynced_local_changes') ?? false;
    try {
      final snapshot = <String, dynamic>{};
      for (final key in backupPreferenceKeys) {
        final stringValue = prefs.getString(prefix + key);
        final boolValue = prefs.getBool(prefix + key);
        if (stringValue != null) {
          snapshot[key] = stringValue;
        } else if (boolValue != null) {
          snapshot[key] = boolValue;
        }
      }
      // Mark the upload as pending before network I/O. If Android kills the
      // process mid-upload, the next attempt writes a separate recovery version.
      await prefs.setBool(prefix + 'unsynced_local_changes', true);
      await GoogleDriveBackupService.backup(
        account,
        snapshot,
        backupPassword: backupPassword,
        createNewVersion: hasUnsyncedLocalChanges,
      );
      await prefs.setBool(prefix + 'unsynced_local_changes', false);
      await prefs.setString('lxh_last_backup_' + account.email, DateTime.now().toIso8601String());
      if (mounted) setState(() => _driveRestoreFailed = false);
    } catch (e) {
      await prefs.setBool(prefix + 'unsynced_local_changes', true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Local data saved. Google Drive backup failed: ' + e.toString())),
        );
      }
    }
  }


  String _defaultSmsTemplate() =>
      'Namaste {partyName}, aapke yahan {date} ko {machineName} (No: {machineNumber}) ne {hours} ghante kaam kiya @ ₹{rate}/hr. Total Bill: ₹{totalBill}. - LxH ONE';

  String _defaultWhatsAppTemplate() =>
      '*Tractor/JCB Work Slip*\n\nParty: *{partyName}*\nDate: {date}\nMachine: {machineName}\nMachine No: {machineNumber}\nDriver: {driverName}\nTotal Time: *{hours} Hours*\nRate: ₹{rate}/hr\n-------------------------\n💰 *Total Bill: ₹{totalBill}*';

  String _renderMessageTemplate(String template, WorkLog log) {
    final values = <String, String>{
      '{partyName}': log.clientName,
      '{date}': log.date,
      '{machineName}': log.vehicleName,
      '{machineNumber}': log.vehicleNumber,
      '{driverName}': log.driverName,
      '{hours}': log.hours.toString(),
      '{rate}': log.rate.toStringAsFixed(0),
      '{totalBill}': log.totalAmount.toStringAsFixed(0),
    };
    var message = template;
    for (final entry in values.entries) {
      message = message.replaceAll(entry.key, entry.value);
    }
    return message;
  }

  Future<void> _openMessageSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final smsController = TextEditingController(
      text: prefs.getString(_accountKey('sms_message_template')) ?? _defaultSmsTemplate(),
    );
    final whatsappController = TextEditingController(
      text: prefs.getString(_accountKey('whatsapp_message_template')) ?? _defaultWhatsAppTemplate(),
    );
    final customerSmsController = TextEditingController(text: prefs.getString(_accountKey('customer_payment_sms_template')) ?? _defaultCustomerPaymentSmsTemplate());
    final customerWhatsAppController = TextEditingController(text: prefs.getString(_accountKey('customer_payment_whatsapp_template')) ?? _defaultCustomerPaymentWhatsAppTemplate());
    final driverSmsController = TextEditingController(text: prefs.getString(_accountKey('driver_statement_sms_template')) ?? _defaultDriverStatementSmsTemplate());
    final driverWhatsAppController = TextEditingController(text: prefs.getString(_accountKey('driver_statement_whatsapp_template')) ?? _defaultDriverStatementWhatsAppTemplate());
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Message Settings'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(alignment: Alignment.centerLeft, child: Text('SMS Message', style: TextStyle(fontWeight: FontWeight.bold))),
                TextField(controller: smsController, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerLeft, child: Text('WhatsApp Message', style: TextStyle(fontWeight: FontWeight.bold))),
                TextField(controller: whatsappController, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 8),
                const Text(
                  'Work bill fields: {partyName}, {date}, {machineName}, {machineNumber}, {driverName}, {hours}, {rate}, {totalBill}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerLeft, child: Text('Customer Payment Receipt — SMS', style: TextStyle(fontWeight: FontWeight.bold))),
                TextField(controller: customerSmsController, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 8),
                const Align(alignment: Alignment.centerLeft, child: Text('Customer Payment Receipt — WhatsApp', style: TextStyle(fontWeight: FontWeight.bold))),
                TextField(controller: customerWhatsAppController, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder())),
                const Text('Payment fields: {partyName}, {date}, {billTotal}, {previousPaid}, {paidNow}, {totalPaid}, {balanceDue}, {creditBalance}, {creditNote}, {balanceStatus}, {paymentDetails}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerLeft, child: Text('Driver Salary Statement — SMS', style: TextStyle(fontWeight: FontWeight.bold))),
                TextField(controller: driverSmsController, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 8),
                const Align(alignment: Alignment.centerLeft, child: Text('Driver Salary Statement — WhatsApp', style: TextStyle(fontWeight: FontWeight.bold))),
                TextField(controller: driverWhatsAppController, maxLines: 6, decoration: const InputDecoration(border: OutlineInputBorder())),
                const Text('Driver fields: {driverName}, {date}, {salaryType}, {salaryRate}, {totalSalaryDue}, {salaryPaid}, {advanceTaken}, {otherPayments}, {totalPaid}, {balance}, {signedBalance}, {balanceStatus}, {latestEntryType}, {latestEntryAmount}, {latestEntryReason}', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await prefs.setString(_accountKey('sms_message_template'), smsController.text);
              await prefs.setString(_accountKey('whatsapp_message_template'), whatsappController.text);
              await prefs.setString(_accountKey('customer_payment_sms_template'), customerSmsController.text);
              await prefs.setString(_accountKey('customer_payment_whatsapp_template'), customerWhatsAppController.text);
              await prefs.setString(_accountKey('driver_statement_sms_template'), driverSmsController.text);
              await prefs.setString(_accountKey('driver_statement_whatsapp_template'), driverWhatsAppController.text);
              await _saveData();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save Messages'),
          ),
        ],
      ),
    );
    smsController.dispose();
    whatsappController.dispose();
    customerSmsController.dispose();
    customerWhatsAppController.dispose();
    driverSmsController.dispose();
    driverWhatsAppController.dispose();
  }


  String _defaultCustomerPaymentSmsTemplate() =>
      'Namaste {partyName}, total work bill ₹{billTotal} tha. Pehle jama ₹{previousPaid}, abhi prapt ₹{paidNow}, kul jama ₹{totalPaid}. Baki ₹{balanceDue}. {balanceStatus}{creditNote} - LxH ONE';
  String _defaultCustomerPaymentWhatsAppTemplate() =>
      '*LxH ONE Payment Receipt*\n\nParty: *{partyName}*\nTotal Work Bill: ₹{billTotal}\nPrevious Jama: ₹{previousPaid}\nToday Received: *₹{paidNow}*\nTotal Jama: ₹{totalPaid}\n*Remaining Balance: ₹{balanceDue}*\n{balanceStatus}{creditNote}\nDate: {date}\n{paymentDetails}';
  String _defaultDriverStatementSmsTemplate() =>
      'Namaste {driverName}, {date} tak total salary due ₹{totalSalaryDue}, salary paid ₹{salaryPaid}, advance ₹{advanceTaken}, other payment ₹{otherPayments}. Total received ₹{totalPaid}. Balance: {signedBalance}. {balanceStatus}. Latest: {latestEntryType} ₹{latestEntryAmount} ({latestEntryReason}). - LxH ONE';
  String _defaultDriverStatementWhatsAppTemplate() =>
      '*LxH ONE — Driver Khata Statement*\n\nDriver: *{driverName}*\nSalary Setting: ₹{salaryRate}/{salaryType}\nTotal Salary Due: ₹{totalSalaryDue}\nSalary Paid: ₹{salaryPaid}\nAdvance Taken: ₹{advanceTaken}\nOther Payments: ₹{otherPayments}\nTotal Received: *₹{totalPaid}*\n*Balance: {signedBalance}*\n{balanceStatus}\n\nLatest Entry: {latestEntryType} — ₹{latestEntryAmount}\nReason: {latestEntryReason}\nDate: {date}';

  String _applyMessageValues(String template, Map<String, String> values) {
    var result = template;
    for (final entry in values.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  Future<void> _showCustomerPaymentReceiptOptions(Person party, CashEntry payment) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(children: [
          const ListTile(
            title: Text('Payment saved. Send updated balance?'),
            subtitle: Text('Customer ko received amount aur remaining balance bhejein.'),
          ),
          ListTile(
            leading: const Icon(Icons.sms_outlined, color: Colors.blue),
            title: const Text('Send by SMS'),
            onTap: () { Navigator.pop(sheetContext); _sendCustomerPaymentReceipt(party, payment, 'sms'); },
          ),
          ListTile(
            leading: const Icon(Icons.chat, color: Colors.green),
            title: const Text('Send by WhatsApp'),
            onTap: () { Navigator.pop(sheetContext); _sendCustomerPaymentReceipt(party, payment, 'whatsapp'); },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Not now'),
            onTap: () => Navigator.pop(sheetContext),
          ),
        ]),
      ),
    );
  }

  Future<void> _sendCustomerPaymentReceipt(Person party, CashEntry payment, String channel) async {
    final prefs = await SharedPreferences.getInstance();
    final billTotal = _partyBillTotal(party.id);
    final totalPaid = _partyReceivedTotal(party.id);
    final previousPaid = totalPaid - payment.amount;
    final rawBalance = billTotal - totalPaid;
    final balanceDue = rawBalance > 0 ? rawBalance : 0.0;
    final credit = rawBalance < 0 ? rawBalance.abs() : 0.0;
    final values = <String, String>{
      '{partyName}': party.name,
      '{date}': payment.date,
      '{billTotal}': billTotal.toStringAsFixed(0),
      '{previousPaid}': previousPaid.toStringAsFixed(0),
      '{paidNow}': payment.amount.toStringAsFixed(0),
      '{totalPaid}': totalPaid.toStringAsFixed(0),
      '{balanceDue}': balanceDue.toStringAsFixed(0),
      '{creditBalance}': credit.toStringAsFixed(0),
      '{creditNote}': credit > 0 ? ' (Aapka extra jama/credit ₹${credit.toStringAsFixed(0)} hai.)' : '',
      '{balanceStatus}': balanceDue > 0
          ? '₹${balanceDue.toStringAsFixed(0)} abhi baki hain.'
          : credit > 0 ? 'Aapka ₹${credit.toStringAsFixed(0)} advance/credit hamare paas hai.' : 'Aapka hisab poora clear hai.',
      '{paymentDetails}': payment.title,
    };
    final key = channel == 'sms' ? 'customer_payment_sms_template' : 'customer_payment_whatsapp_template';
    final fallback = channel == 'sms' ? _defaultCustomerPaymentSmsTemplate() : _defaultCustomerPaymentWhatsAppTemplate();
    final message = _applyMessageValues(prefs.getString(_accountKey(key)) ?? fallback, values);
    if (channel == 'sms') {
      await _openSmsComposerWithMessage(context, party.phone, message);
    } else {
      await _openWhatsAppWithMessage(context, party.phone, message);
    }
  }

  Future<void> _showDriverStatementOptions(Person driver, DriverLedgerEntry? latestEntry) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(children: [
          const ListTile(
            title: Text('Send Driver Khata Statement'),
            subtitle: Text('Salary, paid amount, advance aur remaining balance.'),
          ),
          ListTile(
            leading: const Icon(Icons.sms_outlined, color: Colors.blue),
            title: const Text('Send by SMS'),
            onTap: () { Navigator.pop(sheetContext); _sendDriverStatement(driver, latestEntry, 'sms'); },
          ),
          ListTile(
            leading: const Icon(Icons.chat, color: Colors.green),
            title: const Text('Send by WhatsApp'),
            onTap: () { Navigator.pop(sheetContext); _sendDriverStatement(driver, latestEntry, 'whatsapp'); },
          ),
          ListTile(leading: const Icon(Icons.close), title: const Text('Not now'), onTap: () => Navigator.pop(sheetContext)),
        ]),
      ),
    );
  }

  Future<void> _sendDriverStatement(Person driver, DriverLedgerEntry? latestEntry, String channel) async {
    final prefs = await SharedPreferences.getInstance();
    final driverEntries = driverLedger.where((e) => e.driverId == driver.id).toList();
    double total(String type) => driverEntries.where((e) => e.type == type).fold(0.0, (sum, e) => sum + e.amount);
    final salaryDue = total('Salary Due');
    final salaryPaid = total('Salary Paid');
    final advances = total('Advance');
    final other = total('Other Payment');
    final paidTotal = salaryPaid + advances + other;
    final balance = salaryDue - paidTotal;
    final signedBalance = balance < 0 ? '-₹${balance.abs().toStringAsFixed(0)}' : '₹${balance.toStringAsFixed(0)}';
    final status = balance > 0
        ? 'Aapki salary me se ₹${balance.toStringAsFixed(0)} dena baki hai.'
        : balance < 0
            ? 'Aapne total salary se ₹${balance.abs().toStringAsFixed(0)} zyada le liye hain. Agli salary me adjust hoga.'
            : 'Aapka salary hisab barabar hai.';
    final values = <String, String>{
      '{driverName}': driver.name,
      '{date}': latestEntry?.date ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
      '{salaryType}': driver.salaryType,
      '{salaryRate}': driver.salaryAmount.toStringAsFixed(0),
      '{totalSalaryDue}': salaryDue.toStringAsFixed(0),
      '{salaryPaid}': salaryPaid.toStringAsFixed(0),
      '{advanceTaken}': advances.toStringAsFixed(0),
      '{otherPayments}': other.toStringAsFixed(0),
      '{totalPaid}': paidTotal.toStringAsFixed(0),
      '{balance}': balance.toStringAsFixed(0),
      '{signedBalance}': signedBalance,
      '{balanceStatus}': status,
      '{latestEntryType}': latestEntry?.type ?? 'Statement',
      '{latestEntryAmount}': (latestEntry?.amount ?? 0).toStringAsFixed(0),
      '{latestEntryReason}': latestEntry?.reason ?? 'Current account summary',
    };
    final key = channel == 'sms' ? 'driver_statement_sms_template' : 'driver_statement_whatsapp_template';
    final fallback = channel == 'sms' ? _defaultDriverStatementSmsTemplate() : _defaultDriverStatementWhatsAppTemplate();
    final message = _applyMessageValues(prefs.getString(_accountKey(key)) ?? fallback, values);
    if (channel == 'sms') {
      await _openSmsComposerWithMessage(context, driver.phone, message);
    } else {
      await _openWhatsAppWithMessage(context, driver.phone, message);
    }
  }

  Future<void> _recordDriverPaymentInCashBook(Person driver, DriverLedgerEntry entry) async {
    if (entry.type != 'Salary Due') {
      cashBook.insert(0, CashEntry(
        title: 'Driver payment: ${driver.name} • ${entry.type} • ${entry.reason}',
        amount: entry.amount,
        type: 'Kharcha',
        date: entry.date,
      ));
    }
    await _saveData();
    if (mounted) setState(() {});
  }


  void _addAdvanceRequestDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Advance Maanga'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Kisne advance maanga?')),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Advance Amount (₹)'),
              ),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Reason / Details (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final amount = double.tryParse(amountController.text.trim()) ?? 0;
              if (name.isEmpty || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name aur valid advance amount bharein.')),
                );
                return;
              }
              setState(() {
                advanceRequests.insert(0, AdvanceRequest(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: name,
                  amount: amount,
                  date: DateFormat('dd MMM yyyy').format(DateTime.now()),
                  note: noteController.text.trim(),
                ));
              });
              await _saveData();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              nameController.dispose();
              amountController.dispose();
              noteController.dispose();
            },
            child: const Text('Save Request'),
          ),
        ],
      ),
    );
  }

  void _deleteAdvanceRequest(AdvanceRequest request) {
    setState(() => advanceRequests.removeWhere((item) => item.id == request.id));
    _saveData();
  }

  void _openWorkEntryModal() {
    if (vehicles.isEmpty || workers.isEmpty || clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work entry se pehle Vehicle, Driver aur Party add karein.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => WorkEntrySheet(
        vehicles: vehicles,
        workers: workers,
        clients: clients,
        onSave: (log) {
          setState(() {
            // Work record creates customer receivable only, not a cash receipt.
            logs.insert(0, log);
          });
          _saveData();
        },
      ),
    );
  }

  Future<void> _addVehicleDialog(String type) async {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final rateController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add $type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Vehicle / Machine Name'),
              ),
              TextField(
                controller: numberController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Vehicle Number'),
              ),
              TextField(
                controller: rateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Default Rate / Hour (₹)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final rate = double.tryParse(rateController.text.trim());
              if (nameController.text.trim().isEmpty ||
                  numberController.text.trim().isEmpty ||
                  rate == null || rate <= 0) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save Vehicle'),
          ),
        ],
      ),
    );

    if (!mounted) {
      nameController.dispose();
      numberController.dispose();
      rateController.dispose();
      return;
    }
    final name = nameController.text.trim();
    final number = numberController.text.trim().toUpperCase();
    final rate = double.tryParse(rateController.text.trim());
    nameController.dispose();
    numberController.dispose();
    rateController.dispose();

    if (saved != true || name.isEmpty || number.isEmpty || rate == null || rate <= 0) return;
    if (vehicles.any((v) => v.number.trim().toUpperCase() == number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This vehicle number is already saved.')),
      );
      return;
    }
    setState(() {
      vehicles.add(Vehicle(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        number: number,
        type: type,
        defaultRate: rate,
      ));
    });
    await _saveData();
  }

  void _deleteVehicle(Vehicle v) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Machine?'),
        content: Text('Kya aap "${v.name}" ko delete karna chahte hain?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                vehicles.removeWhere((item) => item.id == v.id);
              });
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deletePerson(Person p, String role) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete $role?'),
        content: Text('Kya aap "${p.name}" ko list se hatana chahte hain?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              final hasDriverHistory = role == 'Worker' &&
                  driverLedger.any((entry) => entry.driverId == p.id);
              final hasPartyHistory = role != 'Worker' &&
                  (logs.any((log) => log.clientId == p.id) ||
                   cashBook.any((entry) => entry.partyId == p.id));
              if (hasDriverHistory || hasPartyHistory) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      hasDriverHistory
                          ? 'Is driver ka khata record hai. History bachane ke liye driver delete nahi kiya ja sakta.'
                          : 'Is party ke work/payment records hain. History bachane ke liye party delete nahi ki ja sakti.',
                    ),
                  ),
                );
                return;
              }
              setState(() {
                if (role == 'Worker') {
                  workers.removeWhere((item) => item.id == p.id);
                } else {
                  clients.removeWhere((item) => item.id == p.id);
                }
              });
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteLog(int index, WorkLog log) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Kya aap ${log.clientName} ka ₹${log.totalAmount.toStringAsFixed(0)} ka work/bill record delete karna chahte hain? Payment history alag se surakshit rahegi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                logs.removeWhere((item) => item.id == log.id);
                // A bill deletion must never delete a real cash transaction.
              });
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Safe Contact Picker with Permission check to prevent minimizing crash
  void _addMultiplePersonsDialog(String role) async {
    try {
      var status = await Permission.contacts.status;
      if (!mounted) return;
      if (!status.isGranted) {
        status = await Permission.contacts.request();
        if (!mounted) return;
      }

      if (status.isGranted) {
        final Contact? contact = await FlutterContacts.openExternalPick();
        if (!mounted) return;
        if (contact != null) {
          String name = contact.displayName;
          String phone = '';
          if (contact.phones.isNotEmpty) {
            phone = contact.phones.first.number.replaceAll(RegExp(r'\D'), '');
          }

          if (name.isNotEmpty && phone.isNotEmpty) {
            setState(() {
              final newP = Person(
                id: DateTime.now().toString() + phone,
                name: name,
                phone: phone,
                role: role,
              );
              if (role == 'Worker') {
                workers.add(newP);
              } else {
                clients.add(newP);
              }
            });
            _saveData();
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission is required to pick contacts!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking contact: $e')),
      );
    }
  }

  void _showSendOptions(WorkLog log) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'Send Work Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined, color: Colors.blue),
              title: const Text('SMS'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sendSMS(log);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.green),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sendWhatsApp(log);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsApp(WorkLog log) async {
    var cleanPhone = _normalizePhone(log.clientPhone);
    if (cleanPhone.length == 10) cleanPhone = '91' + cleanPhone;
    if (cleanPhone.length < 10 || cleanPhone.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Party ka mobile number sahi nahi hai.')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final template = prefs.getString(_accountKey('whatsapp_message_template')) ?? _defaultWhatsAppTemplate();
    final message = _renderMessageTemplate(template, log);
    final uri = Uri.parse('https://wa.me/' + cleanPhone + '?text=' + Uri.encodeComponent(message));
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WhatsApp could not be opened: ' + e.toString())),
      );
    }
  }

  Future<void> _sendSMS(WorkLog log) async {
    final cleanPhone = _normalizePhone(log.clientPhone);
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Party ka mobile number sahi nahi hai.')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final template = prefs.getString(_accountKey('sms_message_template')) ?? _defaultSmsTemplate();
    final message = _renderMessageTemplate(template, log);
    try {
      await const MethodChannel('com.example.tractor_jcb_khata/sms').invokeMethod<bool>(
        'openSms',
        <String, String>{'phone': cleanPhone, 'message': message},
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SMS app could not be opened: ' + (e.message ?? e.code))),
      );
    } on MissingPluginException {
      final uri = Uri(
        scheme: 'smsto',
        path: cleanPhone,
        queryParameters: <String, String>{'body': message},
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS app could not be opened.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildFleetTab('Tractor'),
      _buildFleetTab('JCB'),
      _buildPeopleTab('Worker'),
      _buildPeopleTab('Client'),
      _buildCashTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('LxH ONE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFE65100),
        elevation: 2,
        actions: [
          if (_activeGoogleAccount != null || _offlineMode)
            IconButton(
              tooltip: 'Message Settings',
              onPressed: _openMessageSettings,
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
          if (_activeGoogleAccount != null)
            IconButton(
              tooltip: 'Backup Status',
              onPressed: _openBackupManager,
              icon: const Icon(Icons.cloud_sync, color: Colors.white),
            ),
          if (_activeGoogleAccount != null)
            IconButton(
              tooltip: 'Change Google Account',
              onPressed: _changeGoogleAccount,
              icon: const Icon(Icons.account_circle, color: Colors.white),
            ),
          if (_offlineMode)
            IconButton(
              tooltip: 'Sign in with Google',
              onPressed: _signInGoogle,
              icon: const Icon(Icons.cloud_sync, color: Colors.white),
            ),
        ],
      ),
      body: !_authReady
          ? const Center(child: CircularProgressIndicator())
          : (_activeGoogleAccount == null && !_offlineMode ? _buildLoginScreen() : screens[_currentIndex]),
      bottomNavigationBar: (_activeGoogleAccount == null && !_offlineMode) ? null : NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.agriculture), label: 'Tractor'),
          NavigationDestination(icon: Icon(Icons.construction), label: 'JCB'),
          NavigationDestination(icon: Icon(Icons.engineering), label: 'Worker'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Parties'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Khata'),
        ],
      ),
    );
  }

  Widget _buildFleetTab(String type) {
    final filteredVehicles = vehicles.where((v) => v.type == type).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$type Fleet List', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
              ),
              onPressed: () => _addVehicleDialog(type),
              icon: const Icon(Icons.add),
              label: Text('Add $type'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredVehicles.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Abhi koi vehicle saved nahi hai.')),
          )
        else
          ...filteredVehicles.map((v) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: type == 'Tractor' ? Colors.green.shade100 : Colors.amber.shade100,
                child: Icon(type == 'Tractor' ? Icons.agriculture : Icons.construction, color: Colors.brown),
              ),
              title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('No: ${v.number} | Rate: ₹${v.defaultRate.toStringAsFixed(0)}/hr'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit vehicle',
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                    onPressed: () => _editRateDialog(v),
                  ),
                  IconButton(
                    tooltip: 'Delete vehicle',
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteVehicle(v),
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  void _editRateDialog(Vehicle v) {
    final nameCtrl = TextEditingController(text: v.name);
    final numCtrl = TextEditingController(text: v.number);
    final rateCtrl = TextEditingController(text: v.defaultRate.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Machine: ${v.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Number')),
            TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate/hr (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                v.name = nameCtrl.text;
                v.number = numCtrl.text;
                v.defaultRate = double.tryParse(rateCtrl.text) ?? v.defaultRate;
              });
              _saveData();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _openDriverKhata(Person driver) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverKhataScreen(
          driver: driver,
          entries: driverLedger,
          onChanged: () async {
            await _saveData();
          },
          onEntrySaved: (entry) async {
            await _recordDriverPaymentInCashBook(driver, entry);
          },
          onSendStatement: (entry) async {
            await _showDriverStatementOptions(driver, entry);
          },
        ),
      ),
    );
  }

  Widget _buildPeopleTab(String role) {
    final list = role == 'Worker' ? workers : clients;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(role == 'Worker' ? 'Drivers / Workers' : 'Clients / Parties', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _addMultiplePersonsDialog(role),
              icon: const Icon(Icons.person_add),
              label: const Text('Add New'),
            )
          ],
        ),
        const SizedBox(height: 12),
        ...list.map((p) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(p.name.isNotEmpty ? p.name[0] : 'P')),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(p.phone),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (role == 'Worker')
                  IconButton(
                    icon: const Icon(Icons.account_balance_wallet, color: Color(0xFFE65100)),
                    tooltip: 'Driver Khata',
                    onPressed: () => _openDriverKhata(p),
                  ),
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: () => launchUrl(Uri.parse('tel:${p.phone}'), mode: LaunchMode.externalApplication),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _deletePerson(p, role),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildCashTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Material(
            color: Colors.white,
            child: TabBar(
              labelColor: Color(0xFFE65100),
              tabs: [Tab(text: 'Len-Den'), Tab(text: 'ग्राहक बकाया'), Tab(text: 'Cash Book')],
            ),
          ),
          Expanded(child: TabBarView(children: [
            _buildTransactionsTab(), _buildOutstandingTab(), _buildCashBookTab(),
          ])),
        ],
      ),
    );
  }

  double _partyBillTotal(String partyId) => logs
      .where((log) => log.clientId == partyId)
      .fold(0.0, (sum, log) => sum + log.totalAmount);

  double _partyReceivedTotal(String partyId) => cashBook
      .where((entry) => entry.type == 'Jama' && entry.partyId == partyId)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  Widget _buildTransactionsTab() {
    final totalJama = cashBook.where((c) => c.type == 'Jama').fold(0.0, (sum, c) => sum + c.amount);
    final totalKharcha = cashBook.where((c) => c.type == 'Kharcha').fold(0.0, (sum, c) => sum + c.amount);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _khataSummaryCard('Jama', totalJama, Colors.green)),
          const SizedBox(width: 10),
          Expanded(child: _khataSummaryCard('Kharcha', totalKharcha, Colors.red)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _addTransactionDialog('Jama'),
            icon: const Icon(Icons.add), label: const Text('Paisa Mila (Jama)'),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _addTransactionDialog('Kharcha'),
            icon: const Icon(Icons.remove), label: const Text('Paisa Diya'),
          )),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addAdvanceRequestDialog,
            icon: const Icon(Icons.request_quote),
            label: const Text('Advance Maanga (Request Record)'),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Advance Requests', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (advanceRequests.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Abhi koi advance request record nahi hai.'),
          )
        else
          ...advanceRequests.map((request) => Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.request_quote, color: Color(0xFFE65100)),
              ),
              title: Text(request.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(request.note.isEmpty ? request.date : request.date + ' • ' + request.note),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('₹' + request.amount.toStringAsFixed(0),
                    style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold)),
                  IconButton(
                    tooltip: 'Delete request',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteAdvanceRequest(request),
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Widget _khataSummaryCard(String label, double amount, Color color) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('₹${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ]),
    ));
  }

  Widget _buildOutstandingTab() {
    final partiesWithActivity = clients.where((party) =>
      logs.any((log) => log.clientId == party.id) ||
      cashBook.any((entry) => entry.partyId == party.id)
    ).toList();

    final totalOutstanding = partiesWithActivity.fold<double>(0.0, (sum, party) {
      final due = _partyBillTotal(party.id) - _partyReceivedTotal(party.id);
      return sum + (due > 0 ? due : 0);
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final visibleWorkLogs = logs.where((log) {
      try {
        final date = DateFormat('dd MMM yyyy').parseStrict(log.date);
        if (selectedOutstandingDate != null) {
          return date.year == selectedOutstandingDate!.year &&
              date.month == selectedOutstandingDate!.month &&
              date.day == selectedOutstandingDate!.day;
        }
        final age = today.difference(DateTime(date.year, date.month, date.day)).inDays;
        return age >= 0 && age <= 2;
      } catch (_) {
        return false;
      }
    }).toList()
      ..sort((a, b) => DateFormat('dd MMM yyyy').parse(b.date)
          .compareTo(DateFormat('dd MMM yyyy').parse(a.date)));

    final unlinkedLogs = logs.where((log) => log.clientId.isEmpty).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Work Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (selectedOutstandingDate != null)
              TextButton(
                onPressed: () => setState(() => selectedOutstandingDate = null),
                child: const Text('Last 3 Days'),
              ),
            IconButton(
              tooltip: 'Past Work Records Calendar',
              icon: const Icon(Icons.calendar_month, color: Color(0xFFE65100)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedOutstandingDate ?? DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  setState(() => selectedOutstandingDate = picked);
                }
              },
            ),
          ],
        ),
        Text(
          selectedOutstandingDate == null
              ? 'Recent Work Records (Today + Previous 2 Days)'
              : 'Work Records: ${DateFormat('dd MMM yyyy').format(selectedOutstandingDate!)}',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openWorkEntryModal,
            icon: const Icon(Icons.add),
            label: const Text('New Work Entry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (visibleWorkLogs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Selected period mein koi Work Record nahi hai.'),
            ),
          )
        else
          ...visibleWorkLogs.map((log) {
            final originalIndex = logs.indexWhere((item) => item.id == log.id);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(log.date, style: TextStyle(color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        Text(
                          '₹${log.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 17),
                        ),
                        IconButton(
                          tooltip: 'Delete work record',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: originalIndex < 0 ? null : () => _deleteLog(originalIndex, log),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text('${log.vehicleType} • ${log.vehicleName} • No: ${log.vehicleNumber.isEmpty ? '—' : log.vehicleNumber}'),
                    Text('Driver: ${log.driverName}'),
                    Text('Duration: ${log.hours} hrs @ ₹${log.rate}/hr', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showSendOptions(log),
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Send Bill'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const Divider(height: 32),
        Card(
          color: Colors.orange.shade50,
          child: ListTile(
            title: const Text('Total ग्राहक बकाया', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text(
              '₹${totalOutstanding.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 20, color: Colors.deepOrange, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Customer Outstanding Summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (partiesWithActivity.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Parties ke saved Work Records yahan dikhai denge.'),
          )
        else
          ...partiesWithActivity.map((party) {
            final bill = _partyBillTotal(party.id);
            final paid = _partyReceivedTotal(party.id);
            final due = bill - paid;
            return Card(
              child: ListTile(
                title: Text(party.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Bill ₹${bill.toStringAsFixed(0)}  •  Jama ₹${paid.toStringAsFixed(0)}'),
                trailing: Text(
                  '₹${(due > 0 ? due : 0).toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: due > 0 ? Colors.red : Colors.green),
                ),
                onTap: () => _showPartyLedger(party),
              ),
            );
          }),
        if (unlinkedLogs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${unlinkedLogs.length} purane Work Records kisi current Party se uniquely match nahi hue. Unka data surakshit hai, lekin Party-wise बकाया mein shamil nahi kiya gaya.',
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showPartyLedger(Person party) {
    final partyLogs = logs.where((log) => log.clientId == party.id).toList();
    final payments = cashBook.where((entry) => entry.type == 'Jama' && entry.partyId == party.id).toList();
    final bill = partyLogs.fold(0.0, (sum, log) => sum + log.totalAmount);
    final paid = payments.fold(0.0, (sum, entry) => sum + entry.amount);
    final due = bill - paid;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(party.name),
        content: SizedBox(width: double.maxFinite, height: 380, child: ListView(children: [
          Text('Total Work Bill: ₹${bill.toStringAsFixed(0)}'),
          Text('Total Jama: ₹${paid.toStringAsFixed(0)}'),
          Text('बकाया: ₹${(due > 0 ? due : 0).toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const Divider(),
          const Text('Work Records', style: TextStyle(fontWeight: FontWeight.bold)),
          if (partyLogs.isEmpty) const Text('No work records.')
          else ...partyLogs.map((log) => ListTile(
            dense: true, contentPadding: EdgeInsets.zero,
            title: Text('${log.vehicleType} • ${log.vehicleName}'),
            subtitle: Text('${log.date} • ${log.hours} hrs'),
            trailing: Text('₹${log.totalAmount.toStringAsFixed(0)}'),
          )),
          const Divider(),
          const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold)),
          if (payments.isEmpty) const Text('No payments received.')
          else ...payments.map((entry) => ListTile(
            dense: true, contentPadding: EdgeInsets.zero,
            title: Text(entry.title), subtitle: Text(entry.date),
            trailing: Text('+₹${entry.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green)),
          )),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          ElevatedButton(onPressed: () {
            Navigator.pop(dialogContext);
            _addTransactionDialog('Jama', partyId: party.id);
          }, child: const Text('Payment Add')),
        ],
      ),
    );
  }

  Widget _buildCashBookTab() {
    final totalJama = cashBook.where((c) => c.type == 'Jama').fold(0.0, (sum, c) => sum + c.amount);
    final totalKharcha = cashBook.where((c) => c.type == 'Kharcha').fold(0.0, (sum, c) => sum + c.amount);
    final balance = totalJama - totalKharcha;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(
        title: const Text('Cash Balance', style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text('₹${balance.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: balance >= 0 ? Colors.green : Colors.red)),
      )),
      Row(children: [
        Expanded(child: _khataSummaryCard('Total Jama', totalJama, Colors.green)),
        Expanded(child: _khataSummaryCard('Total Kharcha', totalKharcha, Colors.red)),
      ]),
      const SizedBox(height: 8),
      ...cashBook.map((entry) => ListTile(
        leading: Icon(entry.type == 'Jama' ? Icons.arrow_downward : Icons.arrow_upward,
            color: entry.type == 'Jama' ? Colors.green : Colors.red),
        title: Text(entry.title),
        subtitle: Text(entry.partyName.isEmpty ? entry.date : '${entry.partyName} • ${entry.date}'),
        trailing: Text('${entry.type == 'Jama' ? '+' : '-'} ₹${entry.amount.toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: entry.type == 'Jama' ? Colors.green : Colors.red)),
      )),
    ]);
  }

  void _addTransactionDialog(String type, {String? partyId}) {
    final detailController = TextEditingController();
    final amountController = TextEditingController();
    String? selectedPartyId = partyId ?? (clients.isNotEmpty ? clients.first.id : null);
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(type == 'Jama' ? 'Paisa Mila (Jama)' : 'Paisa Diya (Kharcha)'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (type == 'Jama') ...[
              DropdownButtonFormField<String>(
                value: selectedPartyId,
                decoration: const InputDecoration(labelText: 'Select Party'),
                items: clients.map((party) => DropdownMenuItem(value: party.id, child: Text(party.name))).toList(),
                onChanged: (value) => setDialogState(() => selectedPartyId = value),
              ),
              const SizedBox(height: 8),
            ],
            TextField(controller: detailController,
              decoration: InputDecoration(labelText: type == 'Jama' ? 'Details (optional)' : 'Kharcha Details (e.g. Diesel)')),
            TextField(controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹)')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(onPressed: () async {
              final amount = double.tryParse(amountController.text.trim()) ?? 0;
              if (amount <= 0 || (type == 'Jama' &&
                  (selectedPartyId == null || !clients.any((p) => p.id == selectedPartyId)))) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valid amount aur Party select karein.')));
                return;
              }
              final matches = clients.where((p) => p.id == selectedPartyId).toList();
              final Person? party = matches.isEmpty ? null : matches.first;
              final partyName = party?.name ?? '';
              final detail = detailController.text.trim();
              final payment = CashEntry(
                title: detail.isNotEmpty ? detail : (type == 'Jama' ? 'Payment received from $partyName' : 'Kharcha'),
                amount: amount,
                type: type,
                date: DateFormat('dd MMM yyyy').format(DateTime.now()),
                partyId: type == 'Jama' ? selectedPartyId ?? '' : '',
                partyName: type == 'Jama' ? partyName : '',
              );
              setState(() => cashBook.insert(0, payment));
              Navigator.pop(dialogContext);
              detailController.dispose();
              amountController.dispose();
              await _saveData();
              if (mounted && type == 'Jama' && party != null) {
                await _showCustomerPaymentReceiptOptions(party, payment);
              }
            }, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

}

class WorkEntrySheet extends StatefulWidget {
  final List<Vehicle> vehicles;
  final List<Person> workers;
  final List<Person> clients;
  final Function(WorkLog) onSave;

  const WorkEntrySheet({
    super.key,
    required this.vehicles,
    required this.workers,
    required this.clients,
    required this.onSave,
  });

  @override
  State<WorkEntrySheet> createState() => _WorkEntrySheetState();
}

class _WorkEntrySheetState extends State<WorkEntrySheet> {
  Vehicle? selectedVehicle;
  Person? selectedWorker;
  Person? selectedClient;

  final hoursCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  double calculatedTotal = 0.0;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.vehicles.isNotEmpty) {
      selectedVehicle = widget.vehicles.first;
      rateCtrl.text = selectedVehicle!.defaultRate.toStringAsFixed(0);
    }
    if (widget.workers.isNotEmpty) selectedWorker = widget.workers.first;
    if (widget.clients.isNotEmpty) selectedClient = widget.clients.first;
    hoursCtrl.addListener(_recalculate);
    rateCtrl.addListener(_recalculate);
  }

  void _recalculate() {
    final hours = double.tryParse(hoursCtrl.text) ?? 0;
    final rate = double.tryParse(rateCtrl.text) ?? 0;
    if (mounted) setState(() => calculatedTotal = hours * rate);
  }

  @override
  void dispose() {
    hoursCtrl.dispose();
    rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('New Work Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            DropdownButtonFormField<Vehicle>(
              value: selectedVehicle,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Select Tractor / JCB'),
              items: widget.vehicles.map((vehicle) => DropdownMenuItem(
                value: vehicle,
                child: Text('${vehicle.type} • ${vehicle.name} • ${vehicle.number}'),
              )).toList(),
              onChanged: (vehicle) {
                setState(() {
                  selectedVehicle = vehicle;
                  if (vehicle != null) rateCtrl.text = vehicle.defaultRate.toStringAsFixed(0);
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<Person>(
              value: selectedWorker,
              decoration: const InputDecoration(labelText: 'Select Driver / Worker'),
              items: widget.workers.map((worker) => DropdownMenuItem(
                value: worker,
                child: Text(worker.name),
              )).toList(),
              onChanged: (worker) => setState(() => selectedWorker = worker),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<Person>(
              value: selectedClient,
              decoration: const InputDecoration(labelText: 'Select Client (Party)'),
              items: widget.clients.map((client) => DropdownMenuItem(
                value: client,
                child: Text('${client.name} (${client.phone})'),
              )).toList(),
              onChanged: (client) => setState(() => selectedClient = client),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hoursCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Hours (Ghante)', hintText: 'eg. 3.5'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Rate / Hour (₹)', hintText: 'eg. 800'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Work Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}')),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Date'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('₹${calculatedTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final hours = double.tryParse(hoursCtrl.text) ?? 0;
                final rate = double.tryParse(rateCtrl.text) ?? 0;
                if (selectedVehicle == null ||
                    selectedWorker == null ||
                    selectedClient == null ||
                    hours <= 0 ||
                    rate <= 0 ||
                    calculatedTotal <= 0) return;

                final log = WorkLog(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  date: DateFormat('dd MMM yyyy').format(selectedDate),
                  vehicleName: selectedVehicle!.name,
                  vehicleType: selectedVehicle!.type,
                  driverName: selectedWorker!.name,
                  driverId: selectedWorker!.id,
                  clientName: selectedClient!.name,
                  clientPhone: selectedClient!.phone,
                  clientId: selectedClient!.id,
                  vehicleNumber: selectedVehicle!.number,
                  hours: hours,
                  rate: rate,
                  totalAmount: calculatedTotal,
                );
                widget.onSave(log);
                Navigator.pop(context);
              },
              child: const Text('Save Work Record', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class DriverKhataScreen extends StatefulWidget {
  final Person driver;
  final List<DriverLedgerEntry> entries;
  final VoidCallback onChanged;
  final Future<void> Function(DriverLedgerEntry entry) onEntrySaved;
  final Future<void> Function(DriverLedgerEntry? entry) onSendStatement;

  const DriverKhataScreen({
    super.key,
    required this.driver,
    required this.entries,
    required this.onChanged,
    required this.onEntrySaved,
    required this.onSendStatement,
  });

  @override
  State<DriverKhataScreen> createState() => _DriverKhataScreenState();
}

class _DriverKhataScreenState extends State<DriverKhataScreen> {
  DateTime? selectedDate;

  List<DriverLedgerEntry> get _driverEntries => widget.entries
      .where((entry) => entry.driverId == widget.driver.id)
      .toList();

  double _totalFor(String type) => _driverEntries
      .where((entry) => entry.type == type)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  String _money(double amount) => amount < 0
      ? '-₹${amount.abs().toStringAsFixed(0)}'
      : '₹${amount.toStringAsFixed(0)}';

  Future<void> _setSalary() async {
    final amountController = TextEditingController(
      text: widget.driver.salaryAmount > 0
          ? widget.driver.salaryAmount.toStringAsFixed(0)
          : '',
    );
    String salaryType = widget.driver.salaryType;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Driver Salary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: salaryType,
                decoration: const InputDecoration(labelText: 'Salary Type'),
                items: const [
                  DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => salaryType = value);
                  }
                },
              ),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: salaryType == 'Daily'
                      ? 'Daily Salary (₹)'
                      : 'Monthly Salary (₹)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) {
      amountController.dispose();
      return;
    }
    final amount = double.tryParse(amountController.text.trim());
    amountController.dispose();
    if (saved == true && amount != null && amount > 0) {
      setState(() {
        widget.driver.salaryAmount = amount;
        widget.driver.salaryType = salaryType;
      });
      widget.onChanged();
    }
  }

  Future<void> _addLedgerEntry() async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    String type = 'Advance';
    DateTime entryDate = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Driver Khata Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Entry Type'),
                  items: const [
                    DropdownMenuItem(value: 'Salary Due', child: Text('Salary Due')),
                    DropdownMenuItem(value: 'Salary Paid', child: Text('Salary Paid')),
                    DropdownMenuItem(value: 'Advance', child: Text('Advance')),
                    DropdownMenuItem(value: 'Other Payment', child: Text('Other Payment')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        type = value;
                        if (type == 'Salary Due' && widget.driver.salaryAmount > 0) {
                          amountController.text =
                              widget.driver.salaryAmount.toStringAsFixed(0);
                        }
                      });
                    }
                  },
                ),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                ),
                TextField(
                  controller: reasonController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Details',
                    hintText: 'e.g. Monthly salary, festival advance, medical need',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(DateFormat('dd MMM yyyy').format(entryDate)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Date'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: entryDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => entryDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) return;
                if (reasonController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) {
      amountController.dispose();
      reasonController.dispose();
      return;
    }
    final amount = double.tryParse(amountController.text.trim());
    final reason = reasonController.text.trim();
    amountController.dispose();
    reasonController.dispose();

    if (saved == true && amount != null && amount > 0 && reason.isNotEmpty) {
      final entry = DriverLedgerEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        driverId: widget.driver.id,
        type: type,
        amount: amount,
        reason: reason,
        date: DateFormat('dd MMM yyyy').format(entryDate),
      );
      setState(() => widget.entries.insert(0, entry));
      await widget.onEntrySaved(entry);
      if (mounted) await widget.onSendStatement(entry);
    }
  }

  Future<void> _pickHistoryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = _driverEntries;
    final now = DateTime.now();
    final visibleEntries = allEntries.where((entry) {
      DateTime date;
      try {
        date = DateFormat('dd MMM yyyy').parseStrict(entry.date);
      } catch (_) {
        return false;
      }
      if (selectedDate != null) {
        return date.year == selectedDate!.year &&
            date.month == selectedDate!.month &&
            date.day == selectedDate!.day;
      }
      final difference = DateTime(now.year, now.month, now.day)
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
      return difference >= 0 && difference <= 2;
    }).toList();

    final salaryDue = _totalFor('Salary Due');
    final salaryPaid = _totalFor('Salary Paid');
    final advances = _totalFor('Advance');
    final otherPayments = _totalFor('Other Payment');
    // All actual payments given to the driver reduce the salary balance.
    final totalReceivedByDriver = salaryPaid + advances + otherPayments;
    final balance = salaryDue - totalReceivedByDriver;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.driver.name} Khata'),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Salary: ${_money(widget.driver.salaryAmount)} / ${widget.driver.salaryType}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _setSalary,
                      icon: const Icon(Icons.edit),
                      label: const Text('Set Salary'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.0,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _summaryCard('Salary Due', salaryDue, Colors.orange),
              _summaryCard('Salary Paid', salaryPaid, Colors.green),
              _summaryCard('Advance', advances, Colors.blue),
              _summaryCard(balance >= 0 ? 'Balance Due' : 'Extra Taken', balance, balance >= 0 ? Colors.red : Colors.deepPurple),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Total Given to Driver'),
              subtitle: Text('Salary paid + advance + other payments: ${_money(totalReceivedByDriver)}'),
              trailing: Text(
                balance < 0 ? '-${_money(balance.abs())}' : _money(balance),
                style: TextStyle(fontWeight: FontWeight.bold, color: balance < 0 ? Colors.deepPurple : Colors.red),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => widget.onSendStatement(_driverEntries.isEmpty ? null : _driverEntries.first),
            icon: const Icon(Icons.send),
            label: const Text('Send Salary / Advance Statement'),
          ),
          ElevatedButton.icon(
            onPressed: _addLedgerEntry,
            icon: const Icon(Icons.add),
            label: const Text('Add Khata Entry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  selectedDate == null
                      ? 'Recent Transactions (Last 3 Days)'
                      : 'Transactions: ${DateFormat('dd MMM yyyy').format(selectedDate!)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (selectedDate != null)
                TextButton(
                  onPressed: () => setState(() => selectedDate = null),
                  child: const Text('Recent'),
                ),
              IconButton(
                onPressed: _pickHistoryDate,
                icon: const Icon(Icons.calendar_month, color: Color(0xFFE65100)),
                tooltip: 'Older transactions',
              ),
            ],
          ),
          if (visibleEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No transactions found.')),
            )
          else
            ...visibleEntries.map((entry) {
              final isDue = entry.type == 'Salary Due';
              final color = isDue ? Colors.green : Colors.red;
              final sign = isDue ? '+' : '-';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(
                      isDue ? Icons.arrow_downward : Icons.arrow_upward,
                      color: color,
                    ),
                  ),
                  title: Text(entry.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${entry.reason}\n${entry.date}'),
                  isThreeLine: true,
                  trailing: Text(
                    '$sign ${_money(entry.amount)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              _money(amount),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
