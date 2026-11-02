import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  static const MethodChannel _contactPickerChannel =
      MethodChannel('lxh_one/contact_picker');

  int _currentIndex = 0;
  bool _tabReady = false;
  DateTime? selectedFilterDate;
  DateTime selectedLogsMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Timer? _driveBackupDebounce;
  bool _driveBackupInProgress = false;
  bool _consumingPendingContact = false;
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
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _tabReady) {
      _consumePendingContact();
    }
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
    if (ledgerString != null) {
      final List decoded = jsonDecode(ledgerString);
      ledgerEntries = decoded.map((e) => LedgerEntry.fromJson(e)).toList();
      // Older versions incorrectly treated diesel paid to a driver as money
      // paid to the driver personally. Remove those entries from Driver Khata;
      // the expense and cash-out records remain intact.
      final beforeCleanup = ledgerEntries.length;
      ledgerEntries.removeWhere((e) =>
          e.kind == 'driverPayment' &&
          e.title.toLowerCase().contains('diesel') &&
          e.title.toLowerCase().contains('paid for driver'));
      if (ledgerEntries.length != beforeCleanup) {
        await prefs.setString('ledger_entries_data',
            jsonEncode(ledgerEntries.map((e) => e.toJson()).toList()));
      }
    }
    if (mounted) setState(() => _tabReady = true);
    await _consumePendingContact();
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

  Future<void> _uploadDailyDriveBackup(
    GoogleSignInAccount account, {
    bool showSuccessMessage = false,
  }) async {
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
    if (showSuccessMessage && mounted && stillCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup Google Drive mein save ho gaya: ' + dateName)),
      );
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
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;
      await _uploadDailyDriveBackup(account, showSuccessMessage: true);
    } catch (e) {
      if (!mounted) return;
      final details = e.toString();
      final lower = details.toLowerCase();
      final message = (lower.contains('developer_error') ||
              lower.contains('sign_in_failed') ||
              lower.contains('p0.b: 10') ||
              lower.contains('apiexception: 10') ||
              lower.contains('clientconfigurationerror'))
          ? 'Google Sign-In SHA-1 / package configuration match nahi kar raha. Stable signing key ko Google Cloud Android OAuth client mein register karein.'
          : 'Google Drive backup failed: $details';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 7)),
      );
    }
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
        selectedLogsMonth = DateTime(DateTime.now().year, DateTime.now().month);
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
    String partyName = '',
  }) {
    cashBook.insert(
      0,
      CashEntry(
        title: title,
        amount: amount,
        type: cashIn ? 'Cash In' : 'Cash Out',
        date: DateFormat('dd MMM yyyy').format(DateTime.now()),
        partyName: partyName,
      ),
    );
  }

  void _openWorkEntryModal(String vehicleType) {
    final missing = <String>[];
    if (vehicles.isEmpty) missing.add('machine');
    if (workers.isEmpty) missing.add('driver');
    if (clients.isEmpty) missing.add('party');
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Work Entry se pehle ${missing.join(', ')} add karein.')),
      );
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

  void _deleteLog(WorkLog log, {VoidCallback? refreshPage}) {
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
                logs.removeWhere((existing) => existing.id == log.id);
                // Work records are receivables, not cash movements.
                // Leave independent cash transactions untouched.
              });
              _saveData();
              refreshPage?.call();
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
      // Persist the selected tab so returning from Android's picker never
      // navigates the user back to the first tab.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lxh_current_tab_index', _currentIndex);

      final picked = await _contactPickerChannel.invokeMapMethod<String, dynamic>(
        'pickPhoneContact',
        <String, dynamic>{'role': role},
      );
      if (!mounted || picked == null) return;
      await _savePickedPerson(role, picked);
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contact select nahi ho paya: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select contact: $e')),
      );
    }
  }

  Future<void> _savePickedPerson(String role, Map<String, dynamic> picked) async {
    if (!mounted || (role != 'Worker' && role != 'Client')) return;
    final name = (picked['name'] ?? '').toString().trim();
    final phone = (picked['phone'] ?? '').toString().replaceAll(RegExp(r'\\D'), '');
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected contact has no name or phone number.')),
      );
      return;
    }

    final target = role == 'Worker' ? workers : clients;
    if (target.any((person) =>
        person.phone.replaceAll(RegExp(r'\\D'), '') == phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ye contact pehle se list mein hai.')),
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
  }

  Future<void> _consumePendingContact() async {
    if (!mounted || !_tabReady || _consumingPendingContact) return;
    _consumingPendingContact = true;
    try {
      final picked = await _contactPickerChannel
          .invokeMapMethod<String, dynamic>('consumePendingContact');
      if (!mounted || picked == null) return;
      final role = (picked['role'] ?? '').toString();
      await _savePickedPerson(role, picked);
    } catch (_) {
      // Nothing to recover on ordinary app resumes. A picked contact is
      // persisted natively only when Android recreated the activity.
    } finally {
      _consumingPendingContact = false;
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

  String _workSlipDefaultTemplate() =>
      'TRACTOR / JCB WORK SLIP\n'
      'Party: {name}\n'
      'Date: {date}\n'
      'Machine: {machine} ({type})\n'
      'Driver: {driver}\n'
      'Working Hours: {hours}\n'
      'Rate: ₹{rate} per hour\n'
      'Total Bill: ₹{total}\n'
      '- LxH ONE';

  String _applyMessageFields(String template, Map<String, String> fields) {
    var message = template;
    fields.forEach((key, value) {
      message = message.replaceAll('{$key}', value);
    });
    return message;
  }

  Future<String> _workSlipMessage(WorkLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final template = prefs.getString('message_template_work_slip') ?? _workSlipDefaultTemplate();
    return _applyMessageFields(template, {
      'name': log.clientName,
      'date': log.date,
      'machine': log.vehicleName,
      'type': log.vehicleType,
      'driver': log.driverName,
      'hours': log.hours.toString(),
      'rate': log.rate.toStringAsFixed(0),
      'total': log.totalAmount.toStringAsFixed(0),
    });
  }

  Future<void> _sendWhatsApp(WorkLog log) async {
    final phone = _normalizedIndianPhone(log.clientPhone);
    if (phone == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client ka valid 10-digit mobile number nahi hai.')),
      );
      return;
    }
    final message = await _workSlipMessage(log);
    final uri = Uri.https('wa.me', '/$phone', {'text': message});
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
      queryParameters: {'body': await _workSlipMessage(log)},
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

  List<WorkLog> _workHistoryFor(Person person, bool driver) {
    final entries = logs
        .where((log) => driver
            ? log.driverName == person.name
            : log.clientName == person.name)
        .toList();
    entries.sort((a, b) {
      final aDate = _parseWorkLogDate(a.date);
      final bDate = _parseWorkLogDate(b.date);
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });
    return entries;
  }

  Widget _recentWorkHistorySection(Person person, bool driver) {
    final entries = _workHistoryFor(person, driver);
    final recentEntries = entries.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          driver ? 'Recent Work History (Assigned Jobs)' : 'Recent Work History',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (recentEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Abhi koi work entry nahi hai.'),
          ),
        ...recentEntries.map(driver ? _driverWorkHistoryTile : _clientWorkSlipTile),
        if (entries.length > 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showAllWorkHistory(person, driver),
              icon: const Icon(Icons.history),
              label: Text('View All (${entries.length})'),
            ),
          ),
      ],
    );
  }

  void _showAllWorkHistory(Person person, bool driver) {
    final entries = _workHistoryFor(person, driver);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 560,
          height: MediaQuery.of(dialogContext).size.height * 0.76,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${person.name} • All Work History',
                  style: Theme.of(dialogContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('${entries.length} work entries'),
                const Divider(),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(child: Text('Abhi koi work entry nahi hai.'))
                      : ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) => driver
                              ? _driverWorkHistoryTile(entries[index])
                              : _clientWorkSlipTile(entries[index]),
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<LedgerEntry> _sortedLedgerHistory(List<LedgerEntry> source) {
    final entries = source.toList();
    entries.sort((a, b) {
      DateTime? parse(String value) {
        try {
          return DateFormat('dd MMM yyyy').parseStrict(value);
        } catch (_) {
          return null;
        }
      }
      final aDate = parse(a.date);
      final bDate = parse(b.date);
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });
    return entries;
  }

  Widget _recentLedgerHistorySection(String title, List<LedgerEntry> source) {
    final entries = _sortedLedgerHistory(source);
    final recentEntries = entries.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (recentEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Abhi koi entry nahi hai.'),
          ),
        ...recentEntries.map((entry) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.title),
          subtitle: Text(entry.date),
          trailing: Text('₹${entry.amount.toStringAsFixed(0)}'),
        )),
        if (entries.length > 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showAllLedgerHistory(title, entries),
              icon: const Icon(Icons.history),
              label: Text('View All (${entries.length})'),
            ),
          ),
      ],
    );
  }

  void _showAllLedgerHistory(String title, List<LedgerEntry> source) {
    final entries = _sortedLedgerHistory(source);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 520,
          height: MediaQuery.of(dialogContext).size.height * 0.72,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title.replaceFirst('Recent ', '') + ' • All',
                    style: Theme.of(dialogContext).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('${entries.length} entries'),
                const Divider(),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(child: Text('Abhi koi entry nahi hai.'))
                      : ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final entry = entries[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(entry.title),
                              subtitle: Text(entry.date),
                              trailing: Text('₹${entry.amount.toStringAsFixed(0)}'),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driveBackupDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildFleetTab('Machine'),
      _buildPeopleTab('Worker'),
      _buildPeopleTab('Client'),
      _buildCashTab(),
      _buildTransactionsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(tooltip: 'Default Message Settings', icon: const Icon(Icons.message, color: Colors.white), onPressed: _editMessageTemplates),
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
          NavigationDestination(icon: Icon(Icons.agriculture), label: 'Machine'),
          NavigationDestination(icon: Icon(Icons.engineering), label: 'Worker'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Parties'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Khata'),
          NavigationDestination(icon: Icon(Icons.swap_vert_circle), label: 'Transactions'),
        ],
      ),
    );
  }

  void _openWorkRecordsPage() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (pageContext) => StatefulBuilder(
          builder: (pageContext, refreshPage) => Scaffold(
            appBar: AppBar(
              title: const Text('Work Records'),
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildWorkLogsSection(refreshPage: () => refreshPage(() {})),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFleetTab(String type) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Expanded(child: Text('Machine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openWorkRecordsPage,
            icon: const Icon(Icons.history),
            label: Text('Work Records (${logs.length})'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
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

  DateTime? _parseWorkLogDate(String value) {
    try {
      return DateFormat('dd MMM yyyy').parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  void _changeLogsMonth(int offset, {VoidCallback? refreshPage}) {
    setState(() {
      selectedLogsMonth = DateTime(selectedLogsMonth.year, selectedLogsMonth.month + offset);
      selectedFilterDate = null;
    });
    refreshPage?.call();
  }

  Future<void> _pickLogsDate({VoidCallback? refreshPage}) async {
    final today = DateTime.now();
    final monthStart = DateTime(selectedLogsMonth.year, selectedLogsMonth.month);
    final safeInitialDate = selectedFilterDate ??
        (monthStart.isAfter(DateTime(today.year, today.month, today.day)) ? today : monthStart);
    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedFilterDate = DateTime(picked.year, picked.month, picked.day);
      selectedLogsMonth = DateTime(picked.year, picked.month);
    });
    refreshPage?.call();
  }

  Widget _buildWorkLogsSection({VoidCallback? refreshPage}) {
    final monthLogs = logs.where((log) {
      final date = _parseWorkLogDate(log.date);
      return date != null &&
          date.year == selectedLogsMonth.year &&
          date.month == selectedLogsMonth.month;
    }).toList();
    final visibleLogs = selectedFilterDate == null
        ? monthLogs
        : monthLogs.where((log) {
            final date = _parseWorkLogDate(log.date);
            return date != null &&
                date.year == selectedFilterDate!.year &&
                date.month == selectedFilterDate!.month &&
                date.day == selectedFilterDate!.day;
          }).toList();
    final monthlyBilled = monthLogs.fold<double>(0, (sum, log) => sum + log.totalAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Work Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => _changeLogsMonth(-1, refreshPage: refreshPage),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat('MMMM yyyy').format(selectedLogsMonth),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: selectedLogsMonth.year == DateTime.now().year &&
                      selectedLogsMonth.month == DateTime.now().month
                  ? null
                  : () => _changeLogsMonth(1, refreshPage: refreshPage),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'Filter by date',
              onPressed: () => _pickLogsDate(refreshPage: refreshPage),
              icon: const Icon(Icons.calendar_month),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Text('Work Billed This Month')),
                Text(
                  '₹${monthlyBilled.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 17),
                ),
                const SizedBox(width: 10),
                Text('${monthLogs.length} entries'),
              ],
            ),
          ),
        ),
        if (selectedFilterDate != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() => selectedFilterDate = null);
                refreshPage?.call();
              },
              icon: const Icon(Icons.filter_alt_off),
              label: Text('Clear date filter • ${DateFormat('dd MMM yyyy').format(selectedFilterDate!)}'),
            ),
          ),
        if (visibleLogs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: Text('Is date/month mein koi work entry nahi hai.')),
          ),
        ...visibleLogs.map((log) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text('${log.clientName} • ${log.vehicleName}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${log.date} • Driver: ${log.driverName} • ${log.hours.toStringAsFixed(1)} hrs'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹${log.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  tooltip: 'Delete work record',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteLog(log, refreshPage: refreshPage),
                ),
              ],
            ),
          ),
        )),
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
        Text(driver ? 'Workers' : 'Clients / Parties', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
         Text('₹${due.abs().toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: due > 0 ? Colors.orange : Colors.green)),
         IconButton(
           tooltip: driver ? 'Delete Worker' : 'Delete Client',
           visualDensity: VisualDensity.compact,
           icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
           onPressed: () => _deletePerson(p, driver ? 'Worker' : 'Client'),
         ),
         const Icon(Icons.chevron_right),
       ]),
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
          const Divider(),
          _recentLedgerHistorySection(
            'Recent Earning / Payment History',
            ledgerEntries.where((e)=>e.personName==p.name&&e.kind.startsWith('driver')).toList(),
          ),
          const Divider(),
          _recentWorkHistorySection(p, true),
          OutlinedButton(onPressed:()async{await _addPersonEntry('driverEarning',p);refresh((){});},child:const Text('Add Earning')),
          OutlinedButton(onPressed:()async{await _addPersonEntry('driverAdvance',p);refresh((){});},child:const Text('Add Advance')),
          OutlinedButton(onPressed:()async{await _addPersonEntry('driverPayment',p);refresh((){});},child:const Text('Add Payment Given')),
        ]else...[
          _ledgerLine('Total Bill',_bill(p)),_ledgerLine('Payment Received',_received(p)),_ledgerLine('Remaining Due',_clientDue(p)),
          const Divider(),
          _recentWorkHistorySection(p, false),
          const Divider(),
          _recentLedgerHistorySection(
            'Recent Payment History',
            ledgerEntries.where((e)=>e.kind=='clientPayment'&&e.personName==p.name).toList(),
          ),
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
          _recordCashMovement(
            title: 'Payment Received',
            amount: value,
            cashIn: true,
            partyName: p.name,
          );
        } else if (kind == 'driverAdvance' || kind == 'driverPayment') {
          _recordCashMovement(
            title: kind == 'driverPayment' ? 'Salary / Payment Given' : 'Advance Given',
            amount: value,
            cashIn: false,
            partyName: p.name,
          );
        }
      });
      _saveData();Navigator.pop(ctx);
    },child:const Text('Save'))]));
  }

  Future<void> _sendLedgerSMS(Person p, bool driver) async {
    final message = await _ledgerMessage(p, driver);
    final phone = p.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number available nahi hai.')));
      return;
    }
    final uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SMS app open nahi hua: $e')));
    }
  }

  Future<void> _sendLedgerWhatsApp(Person p, bool driver) async {
    final message = await _ledgerMessage(p, driver);
    final phone = p.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number available nahi hai.')));
      return;
    }
    final normalizedPhone = phone.startsWith('91') ? phone : '91$phone';
    final uri = Uri.https('wa.me', '/$normalizedPhone', {'text': message});
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp could not be opened.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WhatsApp open nahi hua: $e')));
    }
  }

  Future<void> _editMessageTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final workSlip = TextEditingController(text: prefs.getString('message_template_work_slip') ?? _workSlipDefaultTemplate());
    final party = TextEditingController(text: prefs.getString('message_template_party_ledger') ?? 'Namaste {name},\nTotal Bill: ₹{total}\nPayment Received: ₹{received}\nRemaining Due: ₹{due}\n- LxH ONE');
    final driver = TextEditingController(text: prefs.getString('message_template_driver_ledger') ?? 'Namaste {name},\nTotal Earning: ₹{total}\nAdvance: ₹{advance}\nPayment Given: ₹{paid}\nRemaining Payable: ₹{due}\n- LxH ONE');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Default Message Settings'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Work Slip (WhatsApp / SMS)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: workSlip, minLines: 5, maxLines: 9, decoration: const InputDecoration(border: OutlineInputBorder())),
              const SizedBox(height: 12),
              const Text('Party Khata Message', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: party, minLines: 4, maxLines: 7, decoration: const InputDecoration(border: OutlineInputBorder())),
              const SizedBox(height: 12),
              const Text('Driver Khata Message', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: driver, minLines: 4, maxLines: 7, decoration: const InputDecoration(border: OutlineInputBorder())),
              const SizedBox(height: 8),
              const Text('Fields: {name}, {date}, {machine}, {type}, {driver}, {hours}, {rate}, {total}, {received}, {due}, {advance}, {paid}', style: TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () {
            workSlip.text = _workSlipDefaultTemplate();
            party.text = 'Namaste {name},\nTotal Bill: ₹{total}\nPayment Received: ₹{received}\nRemaining Due: ₹{due}\n- LxH ONE';
            driver.text = 'Namaste {name},\nTotal Earning: ₹{total}\nAdvance: ₹{advance}\nPayment Given: ₹{paid}\nRemaining Payable: ₹{due}\n- LxH ONE';
          }, child: const Text('Reset Defaults')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            await prefs.setString('message_template_work_slip', workSlip.text.trim().isEmpty ? _workSlipDefaultTemplate() : workSlip.text);
            await prefs.setString('message_template_party_ledger', party.text.trim());
            await prefs.setString('message_template_driver_ledger', driver.text.trim());
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Default messages saved.')));
          }, child: const Text('Save Messages')),
        ],
      ),
    );
    workSlip.dispose();
    party.dispose();
    driver.dispose();
  }

  Future<String> _ledgerMessage(Person p, bool driver) async {
    final prefs = await SharedPreferences.getInstance();
    final total = driver ? _earned(p) : _bill(p);
    final received = driver ? 0.0 : _received(p);
    final advance = driver ? _advance(p) : 0.0;
    final paid = driver ? _driverPaid(p) : 0.0;
    final due = driver ? _driverDue(p) : _clientDue(p);
    final key = driver ? 'message_template_driver_ledger' : 'message_template_party_ledger';
    final fallback = driver
        ? 'Namaste {name},\nTotal Earning: ₹{total}\nAdvance: ₹{advance}\nPayment Given: ₹{paid}\nRemaining Payable: ₹{due}\n- LxH ONE'
        : 'Namaste {name},\nTotal Bill: ₹{total}\nPayment Received: ₹{received}\nRemaining Due: ₹{due}\n- LxH ONE';
    return _applyMessageFields(prefs.getString(key) ?? fallback, {
      'name': p.name,
      'total': total.toStringAsFixed(0),
      'received': received.toStringAsFixed(0),
      'advance': advance.toStringAsFixed(0),
      'paid': paid.toStringAsFixed(0),
      'due': due.toStringAsFixed(0),
    });
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
      ],
    );
  }

  Future<void> _addGeneralEntry(String kind) async {
    final person = TextEditingController();
    final paidTo = TextEditingController();
    final amount = TextEditingController();
    final interest = TextEditingController();
    final note = TextEditingController();
    final loan = kind == 'loan';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loan ? 'Give Loan' : 'Add Expense'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (loan)
              TextField(controller: person, decoration: const InputDecoration(labelText: 'Borrower Name'))
            else ...[
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Expense Detail (Diesel / Repair etc.)')),
              TextField(controller: paidTo, decoration: const InputDecoration(labelText: 'Paid To (Person / Shop, optional)')),
            ],
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: loan ? 'Principal Amount (₹)' : 'Amount Paid (₹)'),
            ),
            if (loan)
              TextField(
                controller: interest,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Expected Interest (₹)'),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(amount.text) ?? 0;
              final interestValue = double.tryParse(interest.text) ?? 0;
              final who = person.text.trim();
              final vendor = paidTo.text.trim();
              if (value <= 0 || (loan && who.isEmpty)) return;
              final entryTitle = loan ? who : (note.text.trim().isEmpty ? 'Expense' : note.text.trim());
              setState(() {
                final entryDate = DateFormat('dd MMM yyyy').format(DateTime.now());
                ledgerEntries.insert(0, LedgerEntry(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  kind: kind,
                  personName: loan ? who : '',
                  title: entryTitle,
                  amount: value,
                  interest: interestValue,
                  date: entryDate,
                ));
                _recordCashMovement(
                  title: loan ? 'Loan Given' : entryTitle,
                  amount: value,
                  cashIn: false,
                  partyName: loan ? who : vendor,
                );
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualTransaction() async {
    final detail = TextEditingController();
    final person = TextEditingController();
    final amount = TextEditingController();
    String direction = 'Cash Out';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refreshDialog) => AlertDialog(
          title: const Text('Add Transaction'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: direction,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'Cash In', child: Text('Credit • Money Received')),
                  DropdownMenuItem(value: 'Cash Out', child: Text('Debit • Money Paid')),
                ],
                onChanged: (value) => refreshDialog(() => direction = value ?? 'Cash Out'),
              ),
              TextField(controller: person, decoration: const InputDecoration(labelText: 'Name (Client / Driver / Shop)')),
              TextField(controller: detail, decoration: const InputDecoration(labelText: 'Detail (e.g. Diesel)')),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(amount.text) ?? 0;
                final title = detail.text.trim();
                if (value <= 0 || title.isEmpty) return;
                final transactionDate = DateFormat('dd MMM yyyy').format(DateTime.now());
                final transactionId = DateTime.now().microsecondsSinceEpoch.toString();
                setState(() {
                  cashBook.insert(0, CashEntry(
                    title: title,
                    amount: value,
                    type: direction,
                    date: transactionDate,
                    partyName: person.text.trim(),
                  ));
                  if (direction == 'Cash Out') {
                    ledgerEntries.insert(0, LedgerEntry(
                      id: transactionId,
                      kind: 'expense',
                      personName: '',
                      title: title,
                      amount: value,
                      date: transactionDate,
                    ));
                  }
                });
                _saveData();
                Navigator.pop(ctx);
              },
              child: const Text('Save Transaction'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    // cashBook contains only money actually received or paid.
    // Bills / outstanding balances remain in the relevant Party or Driver ledger.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            ElevatedButton.icon(
              onPressed: _addManualTransaction,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Credit = Green • Debit = Red', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        if (cashBook.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: Text('Abhi koi transaction nahi hai.')),
          ),
        ...cashBook.map((entry) {
          final credit = entry.type.toLowerCase() == 'cash in';
          final color = credit ? Colors.green : Colors.red;
          // For debit expenses, show the expense itself as the main label.
          // partyName is only the person who collected/paid for it, not a debtor.
          final displayName = credit && entry.partyName.trim().isNotEmpty
              ? entry.partyName.trim()
              : entry.title;
          final detail = !credit && entry.partyName.trim().isNotEmpty
              ? '${entry.date} • Debit • Driver: ${entry.partyName.trim()}'
              : '${entry.date} • ${credit ? "Credit" : "Debit"}';
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(credit ? Icons.call_received : Icons.call_made, color: color),
              ),
              title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(detail),
              trailing: Text(
                '${credit ? "+" : "-"}₹${entry.amount.toStringAsFixed(0)}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        const Text(
          'Client Payment and Driver Salary/Advance automatically appear here. Diesel and other direct expenses can be added manually.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
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
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month, color: Color(0xFFE65100)),
              title: const Text('Work Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day));
                }
              },
            ),
            const SizedBox(height: 6),
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
              decoration: const InputDecoration(
                labelText: 'Select Worker',
                helperText: 'Selected worker will be assigned as Driver for this work',
              ),
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
                final hours = double.tryParse(hoursCtrl.text) ?? 0;
                if (selectedVehicle == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pehle machine select karein.')));
                  return;
                }
                if (selectedWorker == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pehle driver select karein.')));
                  return;
                }
                if (selectedClient == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pehle party select karein.')));
                  return;
                }
                if (hours <= 0 || calculatedTotal <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hours aur amount sahi enter karein.')));
                  return;
                }
                final log = WorkLog(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  date: DateFormat('dd MMM yyyy').format(selectedDate),
                  vehicleName: selectedVehicle!.name,
                  vehicleType: selectedVehicle!.type,
                  driverName: selectedWorker!.name,
                  clientName: selectedClient!.name,
                  clientPhone: selectedClient!.phone,
                  hours: hours,
                  rate: selectedVehicle!.defaultRate,
                  totalAmount: calculatedTotal,
                );
                widget.onSave(log);
                Navigator.pop(context);
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
