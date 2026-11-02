import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;
import 'package:http/http.dart' as http;

class _GoogleAuthClient extends http.BaseClient {
  final String token;
  final http.Client _inner = http.Client();
  _GoogleAuthClient(this.token);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }
  @override
  void close() => _inner.close();
}

void main() {
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
  final String id; String name; String phone; final String role; bool active;
  Person({required this.id, required this.name, required this.phone, required this.role, this.active = true});
  Map<String, dynamic> toJson() => {'id':id,'name':name,'phone':phone,'role':role,'active':active};
  factory Person.fromJson(Map<String,dynamic> j) => Person(id:j['id']??'',name:j['name']??'',phone:j['phone']??'',role:j['role']??'',active:j['active'] as bool? ?? true);
}

class LedgerEntry {
  final String id,kind,personName,title,date; final double amount,interest;
  LedgerEntry({required this.id,required this.kind,required this.personName,required this.title,required this.amount,this.interest=0,required this.date});
  Map<String,dynamic> toJson()=>{'id':id,'kind':kind,'personName':personName,'title':title,'amount':amount,'interest':interest,'date':date};
  factory LedgerEntry.fromJson(Map<String,dynamic> j)=>LedgerEntry(id:j['id']??'',kind:j['kind']??'',personName:j['personName']??'',title:j['title']??'',amount:(j['amount']??0).toDouble(),interest:(j['interest']??0).toDouble(),date:j['date']??'');
}

class WorkLog {
  final String id;
  final String date;
  final String vehicleName;
  final String vehicleType;
  final String driverName;
  final String clientName;
  final String clientPhone;
  final double hours;
  final double rate;
  final double totalAmount;

  WorkLog({
    required this.id,
    required this.date,
    required this.vehicleName,
    required this.vehicleType,
    required this.driverName,
    required this.clientName,
    required this.clientPhone,
    required this.hours,
    required this.rate,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'vehicleName': vehicleName, 'vehicleType': vehicleType,
    'driverName': driverName, 'clientName': clientName, 'clientPhone': clientPhone,
    'hours': hours, 'rate': rate, 'totalAmount': totalAmount
  };

  factory WorkLog.fromJson(Map<String, dynamic> json) => WorkLog(
    id: json['id'] ?? '',
    date: json['date'] ?? '',
    vehicleName: json['vehicleName'] ?? '',
    vehicleType: json['vehicleType'] ?? '',
    driverName: json['driverName'] ?? '',
    clientName: json['clientName'] ?? '',
    clientPhone: json['clientPhone'] ?? '',
    hours: (json['hours'] ?? 0).toDouble(),
    rate: (json['rate'] ?? 0).toDouble(),
    totalAmount: (json['totalAmount'] ?? 0).toDouble(),
  );
}

class CashEntry {
  final String title;
  final double amount;
  final String type;
  final String date;
  final String partyName;

  CashEntry({
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.partyName = '',
  });

  Map<String, dynamic> toJson() => {
    'title': title, 'amount': amount, 'type': type, 'date': date,
    'partyName': partyName,
  };

  factory CashEntry.fromJson(Map<String, dynamic> json) => CashEntry(
    title: (json['title'] ?? '').toString(),
    amount: (json['amount'] ?? 0).toDouble(),
    type: (json['type'] ?? '').toString(),
    date: (json['date'] ?? '').toString(),
    partyName: (json['partyName'] ?? '').toString(),
  );
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _tabReady = false;
  DateTime? selectedFilterDate;
  Timer? _driveBackupDebounce;
  bool _driveBackupInProgress = false;
  int _dataRevision = 0;

  List<Vehicle> vehicles = [];
  List<Person> workers = [];
  List<Person> clients = [];
  List<WorkLog> logs = [];
  List<CashEntry> cashBook = [];
  List<LedgerEntry> ledgerEntries = [];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [gdrive.DriveApi.driveFileScope],
    serverClientId: '975729106198-4bv34dncp6tk3hov5lbbg8a4psp2r6q9.apps.googleusercontent.com',
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentIndex = (prefs.getInt('lxh_current_tab_index') ?? 0).clamp(0, 4);

    final vehiclesString = prefs.getString('vehicles_data');
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

    final workersString = prefs.getString('workers_data');
    if (workersString != null) {
      final List decoded = jsonDecode(workersString);
      workers = decoded.map((e) => Person.fromJson(e)).toList();
    } else {
      workers = [
        Person(id: 'w1', name: 'Ramesh Driver', phone: '9876543210', role: 'Worker'),
        Person(id: 'w2', name: 'Suresh Operator', phone: '9123456780', role: 'Worker'),
      ];
    }

    final clientsString = prefs.getString('clients_data');
    if (clientsString != null) {
      final List decoded = jsonDecode(clientsString);
      clients = decoded.map((e) => Person.fromJson(e)).toList();
    } else {
      clients = [
        Person(id: 'c1', name: 'Satish Zamindar', phone: '9988776655', role: 'Client'),
        Person(id: 'c2', name: 'Amit Builder', phone: '9416012345', role: 'Client'),
      ];
    }

    final logsString = prefs.getString('logs_data');
    if (logsString != null) {
      final List decoded = jsonDecode(logsString);
      logs = decoded.map((e) => WorkLog.fromJson(e)).toList();
    }

    final cashString = prefs.getString('cash_data');
    if (cashString != null) {
      final List decoded = jsonDecode(cashString);
      cashBook = decoded.map((e) => CashEntry.fromJson(e)).toList();
    }

    final ledgerString = prefs.getString('ledger_entries_data');
    if (ledgerString != null) { final List decoded = jsonDecode(ledgerString); ledgerEntries = decoded.map((e) => LedgerEntry.fromJson(e)).toList(); }
    if (mounted) setState(() => _tabReady = true);
    _maybeShowDailyBackupPrompt();
  }

  Future<void> _maybeShowDailyBackupPrompt() async {
    // Historical method name retained; this never displays a popup.
    await _uploadPendingDriveBackup();
  }

  void _scheduleDriveBackup() {
    _driveBackupDebounce?.cancel();
    _driveBackupDebounce = Timer(const Duration(seconds: 2), () {
      _uploadPendingDriveBackup();
    });
  }

  Future<void> _uploadPendingDriveBackup() async {
    if (!mounted || _driveBackupInProgress) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('drive_backup_pending') != true) return;
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) await _uploadDailyDriveBackup(account);
    } catch (_) {
      // Leave pending=true and retry on the next edit or app launch. No popup.
    }
  }

  Future<gdrive.DriveApi> _driveApiFor(GoogleSignInAccount account) async {
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null || token.isEmpty) throw Exception('Google Drive access token nahi mila. Dobara sign in karein.');
    return gdrive.DriveApi(_GoogleAuthClient(token));
  }

  Future<String> _getOrCreateDriveFolder(gdrive.DriveApi api) async {
    final result = await api.files.list(q: "name = 'LxH ONE Backups' and mimeType = 'application/vnd.google-apps.folder' and trashed = false", spaces: 'drive', pageSize: 100, $fields: 'files(id,name)');
    if (result.files != null && result.files!.isNotEmpty) return result.files!.first.id!;
    final folder = await api.files.create(gdrive.File(name: 'LxH ONE Backups', mimeType: 'application/vnd.google-apps.folder'));
    if (folder.id == null) throw Exception('Google Drive backup folder create nahi hua.');
    return folder.id!;
  }

  Future<void> _uploadDailyDriveBackup(GoogleSignInAccount account) async {
    if (_driveBackupInProgress) return;
    _driveBackupInProgress = true;
    final uploadRevision = _dataRevision;
    var uploadCompleted = false;
    try {
    final api = await _driveApiFor(account);
    final folderId = await _getOrCreateDriveFolder(api);
    final file = await _createBackupFile();
    final dateName = 'LxH_ONE_Backup_' + DateFormat('yyyy-MM-dd').format(DateTime.now()) + '.json';
    final existing = await api.files.list(q: "'" + folderId + "' in parents and name = '" + dateName + "' and trashed = false", spaces: 'drive', pageSize: 100, $fields: 'files(id,name)');
    final media = gdrive.Media(file.openRead(), await file.length(), contentType: 'application/json');
    if (existing.files != null && existing.files!.isNotEmpty) {
      final matchingFiles = existing.files!;
      await api.files.update(gdrive.File(name: dateName), matchingFiles.first.id!, uploadMedia: media);
      // Clean up duplicates from any earlier versions: keep one dated file only.
      for (final duplicate in matchingFiles.skip(1)) {
        if (duplicate.id != null) await api.files.delete(duplicate.id!);
      }
    } else {
      await api.files.create(gdrive.File(name: dateName, parents: [folderId]), uploadMedia: media);
    }
    uploadCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_drive_backup_date', DateFormat('yyyy-MM-dd').format(DateTime.now()));
    await prefs.setString('last_drive_backup_account', account.email);
    final stillCurrent = uploadRevision == _dataRevision;
    await prefs.setBool('drive_backup_pending', !stillCurrent);
    // Re-check after the asynchronous preference write to close the race
    // where an edit starts just before the pending flag is cleared.
    if (uploadRevision != _dataRevision) {
      await prefs.setBool('drive_backup_pending', true);
    }
    if (mounted && stillCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup Google Drive mein save ho gaya: ' + dateName)));
    }
    } finally {
      _driveBackupInProgress = false;
      final latestPrefs = await SharedPreferences.getInstance();
      if (uploadCompleted &&
          latestPrefs.getBool('drive_backup_pending') == true &&
          mounted) {
        _scheduleDriveBackup();
      }
    }
  }

  Future<void> _backupToGoogleDrive() async {
    try { final account = await _googleSignIn.signIn(); if (account == null) return; await _uploadDailyDriveBackup(account); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Drive backup failed: $e'))); }
  }

  Future<void> _restoreFromGoogleDrive() async {
    try {
      final account = await _googleSignIn.signIn() ?? await _googleSignIn.signInSilently();
      if (account == null) return;
      final api = await _driveApiFor(account);
      final folderId = await _getOrCreateDriveFolder(api);
      final result = await api.files.list(q: "'" + folderId + "' in parents and trashed = false", spaces: 'drive', orderBy: 'name desc', pageSize: 100, $fields: 'files(id,name,modifiedTime)');
      final backups = (result.files ?? []).where((f) => (f.name ?? '').endsWith('.json')).toList();
      if (backups.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Is Google account ke Drive folder mein backup nahi mila.'))); return; }
      if (!mounted) return;
      final selected = await showDialog<gdrive.File>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Google Drive se Restore'),
        content: SizedBox(width: 420, height: 360, child: ListView(children: backups.map((f) => ListTile(leading: const Icon(Icons.description), title: Text(f.name ?? 'Dated backup'), subtitle: Text(f.modifiedTime == null ? '' : DateFormat('dd MMM yyyy, hh:mm a').format(f.modifiedTime!.toLocal())), onTap: () => Navigator.pop(ctx, f))).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ));
      if (selected == null || selected.id == null) return;
      final media = await api.files.get(selected.id!, downloadOptions: gdrive.DownloadOptions.fullMedia) as gdrive.Media;
      final bytes = await media.stream.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
      await _restoreBackupBytes(bytes);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Drive restore failed: $e'))); }
  }

  Future<File> _createBackupFile() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'app': 'LxH ONE',
      'schemaVersion': 1,
      'createdAtUtc': now.toIso8601String(),
      'appVersion': '1.0.0+1',
      'vehicles': vehicles.map((e) => e.toJson()).toList(),
      'workers': workers.map((e) => e.toJson()).toList(),
      'clients': clients.map((e) => e.toJson()).toList(),
      'workLogs': logs.map((e) => e.toJson()).toList(),
      'cashBook': cashBook.map((e) => e.toJson()).toList(),
      'ledgerEntries': ledgerEntries.map((e) => e.toJson()).toList(),
    };
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'LxH_ONE_Backup_' + DateFormat('yyyy-MM-dd').format(DateTime.now()) + '.json';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    await prefs.setString('latest_backup_file', file.path);
    return file;
  }

  Future<void> _importBackupFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (picked == null || picked.files.isEmpty || picked.files.single.bytes == null) return;
      await _restoreBackupBytes(picked.files.single.bytes!);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not restore backup: $e'))); }
  }

  Future<void> _restoreBackupBytes(List<int> bytes) async {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['app'] != 'LxH ONE' ||
          decoded['schemaVersion'] != 1) {
        throw Exception('This is not a supported LxH ONE backup file.');
      }

      List<Map<String, dynamic>> readList(String key) {
        final value = decoded[key];
        if (value is! List) throw Exception('Backup is missing "$key" data.');
        return value.map((item) {
          if (item is! Map) throw Exception('Backup contains invalid "$key" data.');
          return Map<String, dynamic>.from(item);
        }).toList();
      }

      // Parse every section before touching current local data.
      final restoredVehicles = readList('vehicles').map(Vehicle.fromJson).toList();
      final restoredWorkers = readList('workers').map(Person.fromJson).toList();
      final restoredClients = readList('clients').map(Person.fromJson).toList();
      final restoredLogs = readList('workLogs').map(WorkLog.fromJson).toList();
      final restoredCash = readList('cashBook').map(CashEntry.fromJson).toList();
      final restoredLedger = (decoded['ledgerEntries'] as List? ?? []).map((e) => LedgerEntry.fromJson(Map<String,dynamic>.from(e))).toList();

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore Backup?'),
          content: Text(
            'Backup date: ${decoded['createdAtUtc'] ?? 'Unknown'}\\n\\n'
            'This will replace the current data on this phone with the backup data. '
            'Your current data will be overwritten. Continue only if this is the correct backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore Data'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final prefs = await SharedPreferences.getInstance();
      // Keep a rollback snapshot before replacing any current local keys.
      final rollback = <String, String?>{
        'vehicles_data': prefs.getString('vehicles_data'),
        'workers_data': prefs.getString('workers_data'),
        'clients_data': prefs.getString('clients_data'),
        'logs_data': prefs.getString('logs_data'),
        'cash_data': prefs.getString('cash_data'),
        'ledger_entries_data': prefs.getString('ledger_entries_data'),
      };
      try {
        await prefs.setString('vehicles_data', jsonEncode(restoredVehicles.map((e) => e.toJson()).toList()));
        await prefs.setString('workers_data', jsonEncode(restoredWorkers.map((e) => e.toJson()).toList()));
        await prefs.setString('clients_data', jsonEncode(restoredClients.map((e) => e.toJson()).toList()));
        await prefs.setString('logs_data', jsonEncode(restoredLogs.map((e) => e.toJson()).toList()));
        await prefs.setString('cash_data', jsonEncode(restoredCash.map((e) => e.toJson()).toList()));
        await prefs.setString('ledger_entries_data', jsonEncode(restoredLedger.map((e) => e.toJson()).toList()));
      } catch (_) {
        for (final entry in rollback.entries) {
          if (entry.value == null) {
            await prefs.remove(entry.key);
          } else {
            await prefs.setString(entry.key, entry.value!);
          }
        }
        rethrow;
      }

      setState(() {
        vehicles = restoredVehicles;
        workers = restoredWorkers;
        clients = restoredClients;
        logs = restoredLogs;
        cashBook = restoredCash;
        ledgerEntries = restoredLedger;
        selectedFilterDate = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully. All records are back in their sections.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not restore backup: $e')),
        );
      }
    }
  }

  Future<void> _saveData() async {
    // Increment before the first await so an in-flight Drive upload can detect
    // a change even while the local preferences are still being written.
    _dataRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vehicles_data', jsonEncode(vehicles.map((e) => e.toJson()).toList()));
    await prefs.setString('workers_data', jsonEncode(workers.map((e) => e.toJson()).toList()));
    await prefs.setString('clients_data', jsonEncode(clients.map((e) => e.toJson()).toList()));
    await prefs.setString('logs_data', jsonEncode(logs.map((e) => e.toJson()).toList()));
    await prefs.setString('cash_data', jsonEncode(cashBook.map((e) => e.toJson()).toList()));
    await prefs.setString('ledger_entries_data', jsonEncode(ledgerEntries.map((e) => e.toJson()).toList()));
    // Mark data dirty; Drive upload will happen silently on next app open
    // if the user has already connected a Google account.
    await prefs.setBool('drive_backup_pending', true);
    _scheduleDriveBackup();
  }

  void _recordCashMovement({
    required String title,
    required double amount,
    required bool cashIn,
  }) {
    cashBook.insert(
      0,
      CashEntry(
        title: title,
        amount: amount,
        type: cashIn ? 'Cash In' : 'Cash Out',
        date: DateFormat('dd MMM yyyy').format(DateTime.now()),
      ),
    );
  }

  void _openWorkEntryModal(String vehicleType) {
    if (vehicles.isEmpty || workers.isEmpty || clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pehle machine, driver aur client add karein.')));
      return;
    }
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => WorkEntrySheet(
      vehicleType: 'Work', vehicles: vehicles, workers: workers, clients: clients,
      onSave: (log) { setState(() => logs.insert(0, log)); _saveData(); },
    ));
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
        content: Text('Kya aap ${log.clientName} ka ₹${log.totalAmount.toStringAsFixed(0)} ka record delete karna chahte hain?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                logs.removeAt(index);
                cashBook.removeWhere((c) => c.title == '${log.clientName} (${log.vehicleName})' && c.amount == log.totalAmount && c.date == log.date);
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

  // Android system picker grants access only to the contact selected by the user.
  // No broad READ_CONTACTS permission is required for this flow.
  Future<void> _addMultiplePersonsDialog(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lxh_current_tab_index', _currentIndex);
      final Contact? contact = await FlutterContacts.openExternalPick();
      if (!mounted || contact == null) return;
      final name = contact.displayName.trim();
      final phone = contact.phones.isNotEmpty
          ? contact.phones.first.number.replaceAll(RegExp(r'\D'), '')
          : '';
      if (name.isEmpty || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected contact has no name or phone number.')),
        );
        return;
      }
      setState(() {
        final newPerson = Person(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          phone: phone,
          role: role,
        );
        if (role == 'Worker') {
          workers.add(newPerson);
        } else {
          clients.add(newPerson);
        }
      });
      await _saveData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open contact picker: $e')),
      );
    }
  }

  String? _normalizedIndianPhone(String rawPhone) {
    var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) digits = '91$digits';
    if (digits.length != 12 || !digits.startsWith('91')) return null;
    return digits;
  }

  String _workSlipMessage(WorkLog log) {
    return 'TRACTOR / JCB WORK SLIP\n'
        'Party: ${log.clientName}\n'
        'Date: ${log.date}\n'
        'Machine: ${log.vehicleName} (${log.vehicleType})\n'
        'Driver: ${log.driverName}\n'
        'Working Hours: ${log.hours}\n'
        'Rate: ₹${log.rate.toStringAsFixed(0)} per hour\n'
        'Total Bill: ₹${log.totalAmount.toStringAsFixed(0)}\n'
        '- LxH ONE';
  }

  Future<void> _sendWhatsApp(WorkLog log) async {
    final phone = _normalizedIndianPhone(log.clientPhone);
    if (phone == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client ka valid 10-digit mobile number nahi hai.')),
      );
      return;
    }
    final uri = Uri.https('wa.me', '/$phone', {'text': _workSlipMessage(log)});
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp could not be opened.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WhatsApp open nahi hua: $e')),
      );
    }
  }

  Future<void> _sendSMS(WorkLog log) async {
    final phone = _normalizedIndianPhone(log.clientPhone);
    if (phone == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client ka valid 10-digit mobile number nahi hai.')),
      );
      return;
    }
    final uri = Uri(
      scheme: 'sms',
      path: '+$phone',
      queryParameters: {'body': _workSlipMessage(log)},
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS app open nahi hua.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SMS app open nahi hua: $e')),
      );
    }
  }

  Widget _clientWorkSlipTile(WorkLog log) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${log.date} • ${log.vehicleName}'),
      subtitle: Text(
        '${log.hours} hrs × ₹${log.rate.toStringAsFixed(0)} • Bill ₹${log.totalAmount.toStringAsFixed(0)}',
      ),
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            tooltip: 'Send Work Slip on WhatsApp',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chat, color: Colors.green),
            onPressed: () => _sendWhatsApp(log),
          ),
          IconButton(
            tooltip: 'Send Work Slip by SMS',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.sms, color: Colors.blue),
            onPressed: () => _sendSMS(log),
          ),
        ],
      ),
    );
  }

  Widget _driverWorkHistoryTile(WorkLog log) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${log.date} • ${log.vehicleName}'),
      subtitle: Text(
        'Party: ${log.clientName} • ${log.hours} hrs • Client bill ₹${log.totalAmount.toStringAsFixed(0)}',
      ),
    );
  }

  @override
  void dispose() {
    _driveBackupDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildFleetTab('Machine Name'),
      _buildPeopleTab('Worker'),
      _buildPeopleTab('Client'),
      _buildCashTab(),
      _buildTransactionsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(tooltip: 'Restore from Google Drive', icon: const Icon(Icons.cloud_download, color: Colors.white), onPressed: _restoreFromGoogleDrive),
          IconButton(tooltip: 'Backup to Google Drive', icon: const Icon(Icons.cloud_upload, color: Colors.white), onPressed: _backupToGoogleDrive),
        ],
        title: const Text('LxH ONE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFE65100),
        elevation: 2,
      ),
      body: _tabReady
          ? screens[_currentIndex]
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) async {
          setState(() => _currentIndex = idx);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('lxh_current_tab_index', idx);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.agriculture), label: 'Machine Name'),
          NavigationDestination(icon: Icon(Icons.engineering), label: 'Drivers'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Parties'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Khata/Cash'),
          NavigationDestination(icon: Icon(Icons.swap_vert_circle), label: 'Transactions'),
        ],
      ),
    );
  }

  Widget _buildFleetTab(String type) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Expanded(child: Text('Machine Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white), onPressed: _addMachineDialog, icon: const Icon(Icons.add), label: const Text('Add Machine')),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () => _openWorkEntryModal('All'),
          icon: const Icon(Icons.work),
          label: const Text('New Work Entry'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), foregroundColor: const Color(0xFFE65100), side: const BorderSide(color: Color(0xFFE65100))),
        )),
        const SizedBox(height: 12),
        ...vehicles.map((v) => Card(child: ListTile(
          leading: CircleAvatar(
            backgroundColor: v.type == 'Tractor' ? Colors.green.shade100 : Colors.amber.shade100,
            child: Icon(v.type == 'Tractor' ? Icons.agriculture : Icons.construction, color: Colors.brown),
          ),
          title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${v.type} • No: ${v.number} • Rate: ₹${v.defaultRate.toStringAsFixed(0)}/hr'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _editRateDialog(v)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteVehicle(v)),
          ]),
        ))),
        if (vehicles.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No machines added yet.'))),
      ],
    );
  }

  void _addMachineDialog() {
    final name = TextEditingController();
    final number = TextEditingController();
    final rate = TextEditingController();
    String machineType = 'Tractor';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: const Text('Add Machine'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: machineType, decoration: const InputDecoration(labelText: 'Machine Type'),
          items: const [DropdownMenuItem(value: 'Tractor', child: Text('Tractor')), DropdownMenuItem(value: 'JCB', child: Text('JCB'))],
          onChanged: (v) => setDialogState(() => machineType = v ?? 'Tractor')),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Machine Name')),
        TextField(controller: number, decoration: const InputDecoration(labelText: 'Machine Number')),
        TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rate / Hour (₹)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          final parsedRate = double.tryParse(rate.text) ?? 0;
          if (name.text.trim().isEmpty || number.text.trim().isEmpty || parsedRate <= 0) return;
          setState(() => vehicles.add(Vehicle(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name.text.trim(), number: number.text.trim(), type: machineType, defaultRate: parsedRate)));
          _saveData(); Navigator.pop(ctx);
        }, child: const Text('Save Machine')),
      ],
    )));
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

  Widget _buildPeopleTab(String role) {
    final driver = role == 'Worker';
    final list = driver ? workers : [...clients.where((p)=>p.active), ...clients.where((p)=>!p.active)];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(driver ? 'Drivers' : 'Clients / Parties', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ElevatedButton.icon(onPressed: ()=>_addMultiplePersonsDialog(role), icon: const Icon(Icons.person_add), label: const Text('Add New')),
      ]),
      if (!driver) const Padding(padding: EdgeInsets.only(top:12,bottom:4), child: Text('ACTIVE • KAAM CHAL RAHA HAI',style:TextStyle(color:Colors.green,fontWeight:FontWeight.bold))),
      ...list.where((p)=>driver || p.active).map((p)=>_personTile(p,driver)),
      if (!driver && clients.any((p)=>!p.active)) ...[
        const Padding(padding:EdgeInsets.only(top:14,bottom:4),child:Text('COMPLETED • KAAM POORA',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.grey))),
        ...list.where((p)=>!p.active).map((p)=>_personTile(p,false)),
      ],
      if (list.isEmpty) const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('Abhi koi record nahi hai.'))),
    ]);
  }

  Widget _personTile(Person p,bool driver) {
    final due = driver ? _driverDue(p) : _clientDue(p);
    return Card(child:ListTile(
      leading:CircleAvatar(child:Text(p.name.isEmpty?'?':p.name[0].toUpperCase())),
      title:Text(p.name,style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text(driver ? p.phone : '${p.active ? "Active" : "Completed"} • ${p.phone}'),
      trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text('₹${due.abs().toStringAsFixed(0)}',style:TextStyle(fontWeight:FontWeight.bold,color:due>0?Colors.orange:Colors.green)),const Icon(Icons.chevron_right)]),
      onTap:()=>_showPersonLedger(p,driver),
    ));
  }

  double _bill(Person p)=>logs.where((l)=>l.clientName==p.name).fold(0.0,(v,l)=>v+l.totalAmount);
  double _received(Person p)=>ledgerEntries.where((e)=>e.kind=='clientPayment'&&e.personName==p.name).fold(0.0,(v,e)=>v+e.amount);
  double _earned(Person p)=>ledgerEntries.where((e)=>e.kind=='driverEarning'&&e.personName==p.name).fold(0.0,(v,e)=>v+e.amount);
  double _advance(Person p)=>ledgerEntries.where((e)=>e.kind=='driverAdvance'&&e.personName==p.name).fold(0.0,(v,e)=>v+e.amount);
  double _driverPaid(Person p)=>ledgerEntries.where((e)=>e.kind=='driverPayment'&&e.personName==p.name).fold(0.0,(v,e)=>v+e.amount);
  double _clientDue(Person p)=>_bill(p)-_received(p);
  double _driverDue(Person p)=>_earned(p)-_advance(p)-_driverPaid(p);

  void _showPersonLedger(Person p,bool driver) {
    showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
      title:Text('${p.name} ka Hisab'),
      content:SizedBox(width:420,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
        if(driver)...[
          _ledgerLine('Total Earning (Manual)',_earned(p)),_ledgerLine('Advance Given',_advance(p)),_ledgerLine('Other Payment Given',_driverPaid(p)),_ledgerLine('Remaining Payable',_driverDue(p)),
          const Divider(),const Text('Earning / Payment History',style:TextStyle(fontWeight:FontWeight.bold)),
          ...ledgerEntries.where((e)=>e.personName==p.name&&e.kind.startsWith('driver')).map((e)=>ListTile(contentPadding:EdgeInsets.zero,title:Text(e.title),subtitle:Text(e.date),trailing:Text('₹${e.amount.toStringAsFixed(0)}'))),
          const Divider(),
          const Text('Work History (Assigned Jobs)',style:TextStyle(fontWeight:FontWeight.bold)),
          ...logs.where((l)=>l.driverName==p.name).map(_driverWorkHistoryTile),
          if (logs.every((l)=>l.driverName!=p.name))
            const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('Abhi koi work entry assign nahi hai.')),
          OutlinedButton(onPressed:()async{await _addPersonEntry('driverEarning',p);refresh((){});},child:const Text('Add Earning')),
          OutlinedButton(onPressed:()async{await _addPersonEntry('driverAdvance',p);refresh((){});},child:const Text('Add Advance')),
          OutlinedButton(onPressed:()async{await _addPersonEntry('driverPayment',p);refresh((){});},child:const Text('Add Payment Given')),
        ]else...[
          _ledgerLine('Total Bill',_bill(p)),_ledgerLine('Payment Received',_received(p)),_ledgerLine('Remaining Due',_clientDue(p)),
          const Divider(),const Text('Work History',style:TextStyle(fontWeight:FontWeight.bold)),
          ...logs.where((l)=>l.clientName==p.name).map(_clientWorkSlipTile),
          const Divider(),const Text('Payment History',style:TextStyle(fontWeight:FontWeight.bold)),
          ...ledgerEntries.where((e)=>e.kind=='clientPayment'&&e.personName==p.name).map((e)=>ListTile(contentPadding:EdgeInsets.zero,title:Text(e.title),subtitle:Text(e.date),trailing:Text('₹${e.amount.toStringAsFixed(0)}'))),
          OutlinedButton(onPressed:()async{await _addPersonEntry('clientPayment',p);refresh((){});},child:const Text('Add Payment Received')),
          OutlinedButton(onPressed:()async{p.active=!p.active;await _saveData();setState((){});refresh((){});},child:Text(p.active?'Mark Completed':'Mark Active')),
        ],
        Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(onPressed:()=>_sendLedgerWhatsApp(p,driver),icon:const Icon(Icons.chat),label:const Text('WhatsApp Hisab')),
          OutlinedButton.icon(onPressed:()=>_sendLedgerSMS(p,driver),icon:const Icon(Icons.sms),label:const Text('SMS Hisab')),
        ]),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))],
    )));
  }

  Widget _ledgerLine(String label,double amount)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Flexible(child:Text(label)),Text('₹${amount.toStringAsFixed(0)}',style:const TextStyle(fontWeight:FontWeight.bold))]));

  Future<void> _addPersonEntry(String kind,Person p) async {
    final amount=TextEditingController(),note=TextEditingController();
    final names={'driverEarning':'Add Earning','driverAdvance':'Add Advance','driverPayment':'Add Payment Given','clientPayment':'Add Payment Received'};
    await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text(names[kind]!),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount (₹)')),
      TextField(controller:note,decoration:const InputDecoration(labelText:'Note (optional)')),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),ElevatedButton(onPressed:(){
      final value=double.tryParse(amount.text)??0;if(value<=0)return;
      final entryTitle = note.text.trim().isEmpty ? names[kind]! : note.text.trim();
      setState(() {
        ledgerEntries.insert(0,LedgerEntry(id:DateTime.now().microsecondsSinceEpoch.toString(),kind:kind,personName:p.name,title:entryTitle,amount:value,date:DateFormat('dd MMM yyyy').format(DateTime.now())));
        if (kind == 'clientPayment') {
          _recordCashMovement(title: 'Client payment received - ${p.name}', amount: value, cashIn: true);
        } else if (kind == 'driverAdvance' || kind == 'driverPayment') {
          _recordCashMovement(title: '${names[kind]} - ${p.name}', amount: value, cashIn: false);
        }
      });
      _saveData();Navigator.pop(ctx);
    },child:const Text('Save'))]));
  }

  void _sendLedgerSMS(Person p, bool driver) async {
    final total = driver ? _earned(p) : _bill(p);
    final paid = driver ? _advance(p) + _driverPaid(p) : _received(p);
    final due = total - paid;
    final message = driver
        ? 'Namaste ${p.name}, Total earning: ₹${total.toStringAsFixed(0)}, Advance: ₹${_advance(p).toStringAsFixed(0)}, Payment given: ₹${_driverPaid(p).toStringAsFixed(0)}, Remaining payable: ₹${due.toStringAsFixed(0)}. - LxH ONE'
        : 'Namaste ${p.name}, Total bill: ₹${total.toStringAsFixed(0)}, Payment received: ₹${paid.toStringAsFixed(0)}, Remaining due: ₹${due.toStringAsFixed(0)}. - LxH ONE';
    final phone = p.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number available nahi hai.'))); return; }
    final uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SMS app open nahi hua: $e'))); }
  }

  void _sendLedgerWhatsApp(Person p,bool driver) async {
    final total=driver?_earned(p):_bill(p),paid=driver?_advance(p)+_driverPaid(p):_received(p),due=total-paid;
    final message=driver?'Namaste ${p.name},\nTotal earning: ₹${total.toStringAsFixed(0)}\nAdvance: ₹${_advance(p).toStringAsFixed(0)}\nPayment given: ₹${_driverPaid(p).toStringAsFixed(0)}\nRemaining payable: ₹${due.toStringAsFixed(0)}':'Namaste ${p.name},\nTotal bill: ₹${total.toStringAsFixed(0)}\nPayment received: ₹${paid.toStringAsFixed(0)}\nRemaining due: ₹${due.toStringAsFixed(0)}';
    final phone=p.phone.replaceAll(RegExp(r'\D'),'');
    final normalizedPhone=phone.startsWith('91')?phone:'91$phone';
    final uri=Uri.https('wa.me','/$normalizedPhone',{'text':message});
    await launchUrl(uri,mode:LaunchMode.externalApplication);
  }


  Widget _buildCashTab() {
    final expenses = ledgerEntries.where((e) => e.kind == 'expense').toList();
    final loans = ledgerEntries.where((e) => e.kind == 'loan').toList();
    final expenseTotal = expenses.fold(0.0, (v, e) => v + e.amount);
    final loanPrincipal = loans.fold(0.0, (v, e) => v + e.amount);
    final loanInterest = loans.fold(0.0, (v, e) => v + e.interest);

    bool isCashIn(CashEntry entry) => entry.type.toLowerCase() == 'cash in';
    final cashInEntries = cashBook.where(isCashIn).toList();
    final cashOutEntries = cashBook.where((e) => !isCashIn(e)).toList();
    final cashInTotal = cashInEntries.fold(0.0, (v, e) => v + e.amount);
    final cashOutTotal = cashOutEntries.fold(0.0, (v, e) => v + e.amount);
    final workBilled = logs.fold(0.0, (v, e) => v + e.totalAmount);
    final clientPayments = ledgerEntries
        .where((e) => e.kind == 'clientPayment')
        .fold(0.0, (v, e) => v + e.amount);
    final clientOutstanding = workBilled - clientPayments;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Extra Kharch / Len-Den', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _ledgerLine('Total Expense', expenseTotal),
              _ledgerLine('Loan Principal Given', loanPrincipal),
              _ledgerLine('Expected Interest', loanInterest),
              _ledgerLine('Expected Total Return', loanPrincipal + loanInterest),
            ]),
          ),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(
            onPressed: () => _addGeneralEntry('expense'),
            icon: const Icon(Icons.remove_circle),
            label: const Text('Add Expense'),
          ),
          ElevatedButton.icon(
            onPressed: () => _addGeneralEntry('loan'),
            icon: const Icon(Icons.account_balance),
            label: const Text('Give Loan'),
          ),
        ]),
        const SizedBox(height: 16),
        const Text('Expenses Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
        ...expenses.map((e) => ListTile(
          leading: const Icon(Icons.receipt_long, color: Colors.red),
          title: Text(e.title),
          subtitle: Text(e.date),
          trailing: Text('₹${e.amount.toStringAsFixed(0)}'),
        )),
        const Divider(),
        const Text('Loan Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
        ...loans.map((e) => ListTile(
          leading: const Icon(Icons.account_balance, color: Colors.blue),
          title: Text(e.title),
          subtitle: Text('${e.date} • Principal ₹${e.amount.toStringAsFixed(0)} • Interest ₹${e.interest.toStringAsFixed(0)}'),
          trailing: Text('₹${(e.amount + e.interest).toStringAsFixed(0)}'),
        )),
        const SizedBox(height: 18),
        const Divider(),
        const Text('Cash Book', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _ledgerLine('Cash Received', cashInTotal),
              _ledgerLine('Cash Paid', cashOutTotal),
              _ledgerLine('Net Cash Movement', cashInTotal - cashOutTotal),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _ledgerLine('Work Billed (Credit)', workBilled),
              _ledgerLine('Client Payments Received', clientPayments),
              _ledgerLine('Client Outstanding', clientOutstanding),
              const SizedBox(height: 6),
              const Text(
                'Work Entry ko cash receipt nahi maana gaya hai. Client se payment milne par hi Cash Received mein add hota hai.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ]),
          ),
        ),
        const Text('Cash Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        ...cashBook.map((e) {
          final cashIn = isCashIn(e);
          return ListTile(
            leading: Icon(
              cashIn ? Icons.call_received : Icons.call_made,
              color: cashIn ? Colors.green : Colors.red,
            ),
            title: Text(e.title),
            subtitle: Text('${e.date} • ${cashIn ? "Cash In" : "Cash Out"}'),
            trailing: Text(
              '${cashIn ? "+" : "-"}₹${e.amount.toStringAsFixed(0)}',
              style: TextStyle(color: cashIn ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
          );
        }),
        if (cashBook.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('Abhi koi cash transaction nahi hai.')),
          ),
      ],
    );
  }

  Future<void> _addGeneralEntry(String kind) async {
    final person=TextEditingController(),amount=TextEditingController(),interest=TextEditingController(),note=TextEditingController();
    final loan=kind=='loan';
    await showDialog(context:context,builder:(ctx)=>AlertDialog(
      title:Text(loan?'Give Loan':'Add Expense'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:loan?person:note,decoration:InputDecoration(labelText:loan?'Person Name':'Expense Detail (Diesel / Repair etc.)')),
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:loan?'Principal Amount (₹)':'Expense Amount (₹)')),
        if(loan)TextField(controller:interest,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Expected Interest (₹)')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        ElevatedButton(onPressed:(){
          final value=double.tryParse(amount.text)??0,interestValue=double.tryParse(interest.text)??0;
          final who=person.text.trim();
          if(value<=0||(loan&&who.isEmpty))return;
          final entryTitle = loan ? who : (note.text.trim().isEmpty ? 'Expense' : note.text.trim());
          setState(() {
            ledgerEntries.insert(0,LedgerEntry(id:DateTime.now().microsecondsSinceEpoch.toString(),kind:kind,personName:loan?who:'',title:entryTitle,amount:value,interest:interestValue,date:DateFormat('dd MMM yyyy').format(DateTime.now())));
            _recordCashMovement(
              title: loan ? 'Loan given - $who' : 'Expense - $entryTitle',
              amount: value,
              cashIn: false,
            );
          });
          _saveData();Navigator.pop(ctx);
        },child:const Text('Save')),
      ],
    ));
  }

  void _addExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kharcha Add Karein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Detail (eg. Diesel)')),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                setState(() {
                  cashBook.insert(0, CashEntry(
                    title: titleController.text.isEmpty ? 'Kharcha' : titleController.text,
                    amount: double.tryParse(amountController.text) ?? 0,
                    type: 'Cash Out',
                    date: DateFormat('dd MMM yyyy').format(DateTime.now()),
                  ));
                });
                _saveData();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }
}

class WorkEntrySheet extends StatefulWidget {
  final String vehicleType;
  final List<Vehicle> vehicles;
  final List<Person> workers;
  final List<Person> clients;
  final Function(WorkLog) onSave;

  const WorkEntrySheet({
    super.key,
    required this.vehicleType,
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
  
  final machineNameCtrl = TextEditingController();
  final machineNoCtrl = TextEditingController();
  final hoursCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  double calculatedTotal = 0.0;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.vehicles.isNotEmpty) {
      selectedVehicle = widget.vehicles.first;
      machineNameCtrl.text = selectedVehicle!.name;
      machineNoCtrl.text = selectedVehicle!.number;
      rateCtrl.text = selectedVehicle!.defaultRate.toStringAsFixed(0);
    }
    if (widget.workers.isNotEmpty) selectedWorker = widget.workers.first;
    if (widget.clients.isNotEmpty) selectedClient = widget.clients.first;

    hoursCtrl.addListener(_recalculate);
    rateCtrl.addListener(_recalculate);
  }

  void _recalculate() {
    final hrs = double.tryParse(hoursCtrl.text) ?? 0.0;
    final r = double.tryParse(rateCtrl.text) ?? 0.0;
    setState(() {
      calculatedTotal = hrs * r;
    });
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
            Text('New ${widget.vehicleType} Entry', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            DropdownButtonFormField<Vehicle>(
              value: selectedVehicle,
              decoration: const InputDecoration(labelText: 'Select Machine'),
              items: widget.vehicles.map((v) => DropdownMenuItem(value: v, child: Text('${v.name} • ${v.type}'))).toList(),
              onChanged: (v) => setState(() { selectedVehicle = v; if (v != null) { machineNameCtrl.text = v.name; machineNoCtrl.text = v.number; rateCtrl.text = v.defaultRate.toStringAsFixed(0); _recalculate(); } }),
            ),
            const SizedBox(height: 10),
            TextFormField(controller: machineNoCtrl, readOnly: true, decoration: const InputDecoration(labelText: 'Machine Number')),
            const SizedBox(height: 10),
            DropdownButtonFormField<Person>(
              value: selectedWorker,
              decoration: const InputDecoration(labelText: 'Select Driver / Worker'),
              items: widget.workers.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
              onChanged: (w) => setState(() => selectedWorker = w),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<Person>(
              value: selectedClient,
              decoration: const InputDecoration(labelText: 'Select Client (Party)'),
              items: widget.clients.map((c) => DropdownMenuItem(value: c, child: Text('${c.name} (${c.phone})'))).toList(),
              onChanged: (c) => setState(() => selectedClient = c),
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
                Expanded(child: TextFormField(controller: rateCtrl, readOnly: true, decoration: const InputDecoration(labelText: 'Machine Rate / Hour (₹)'))),
              ],
            ),
            const SizedBox(height: 16),
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
                if (machineNameCtrl.text.isNotEmpty && selectedWorker != null && selectedClient != null && calculatedTotal > 0) {
                  final log = WorkLog(
                    id: DateTime.now().toString(),
                    date: DateFormat('dd MMM yyyy').format(selectedDate),
                    vehicleName: selectedVehicle!.name,
                    vehicleType: selectedVehicle!.type,
                    driverName: selectedWorker!.name,
                    clientName: selectedClient!.name,
                    clientPhone: selectedClient!.phone,
                    hours: double.tryParse(hoursCtrl.text) ?? 0,
                    rate: selectedVehicle!.defaultRate,
                    totalAmount: calculatedTotal,
                  );
                  widget.onSave(log);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save Record', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
