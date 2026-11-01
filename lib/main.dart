import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  final String id;
  String name;
  String phone;
  final String role;

  Person({required this.id, required this.name, required this.phone, required this.role});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'role': role};
  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'],
    name: json['name'],
    phone: json['phone'],
    role: json['role'],
  );
}

class WorkLog {
  final String id;
  final String date;
  final String vehicleName;
  final String vehicleType;
  final String driverName;
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
    'driverName': driverName, 'clientName': clientName, 'clientPhone': clientPhone,
    'clientId': clientId, 'vehicleNumber': vehicleNumber,
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

String _normalizePhone(String value) {
  var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('91') && digits.length == 12) digits = digits.substring(2);
  if (digits.startsWith('0') && digits.length == 11) digits = digits.substring(1);
  return digits;
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  DateTime? selectedFilterDate;

  List<Vehicle> vehicles = [];
  List<Person> workers = [];
  List<Person> clients = [];
  List<WorkLog> logs = [];
  List<CashEntry> cashBook = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
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
          clientName: log.clientName, clientPhone: log.clientPhone,
          clientId: match?.id ?? '', vehicleNumber: log.vehicleNumber,
          hours: log.hours, rate: log.rate, totalAmount: log.totalAmount,
        );
      }).toList();
    }

    final cashString = prefs.getString('cash_data');
    final migrationDone = prefs.getBool('khata_migration_v2_done') ?? false;
    if (cashString != null) {
      final List decoded = jsonDecode(cashString);
      final loadedEntries = decoded.map((e) => CashEntry.fromJson(e)).toList();
      if (!migrationDone) {
        // Earlier versions auto-created Jama for bills. Archive rather than count as received cash.
        final legacyAutoJama = loadedEntries.where((e) => e.type == 'Jama').toList();
        await prefs.setString('legacy_auto_jama_data',
            jsonEncode(legacyAutoJama.map((e) => e.toJson()).toList()));
        cashBook = loadedEntries.where((e) => e.type != 'Jama').toList();
        await prefs.setString('cash_data',
            jsonEncode(cashBook.map((e) => e.toJson()).toList()));
      } else {
        cashBook = loadedEntries;
      }
    }
    await prefs.setBool('khata_migration_v2_done', true);
    await prefs.setString('logs_data', jsonEncode(logs.map((e) => e.toJson()).toList()));
    if (mounted) setState(() {});
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vehicles_data', jsonEncode(vehicles.map((e) => e.toJson()).toList()));
    await prefs.setString('workers_data', jsonEncode(workers.map((e) => e.toJson()).toList()));
    await prefs.setString('clients_data', jsonEncode(clients.map((e) => e.toJson()).toList()));
    await prefs.setString('logs_data', jsonEncode(logs.map((e) => e.toJson()).toList()));
    await prefs.setString('cash_data', jsonEncode(cashBook.map((e) => e.toJson()).toList()));
    await prefs.setBool('khata_migration_v2_done', true);
  }

  void _openWorkEntryModal(String vehicleType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => WorkEntrySheet(
        vehicleType: vehicleType,
        vehicles: vehicles.where((v) => v.type == vehicleType).toList(),
        workers: workers,
        clients: clients,
        onSave: (log) {
          setState(() {
            // A saved work record creates a bill/receivable, never a cash receipt.
            logs.insert(0, log);
          });
          _saveData();
        },
      ),
    );
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
              if (role != 'Worker' &&
                  (logs.any((log) => log.clientId == p.id) ||
                   cashBook.any((entry) => entry.partyId == p.id))) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Is party ke work/payment records hain. History bachane ke liye party delete nahi ki ja sakti.')),
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

  // Fixed Direct WhatsApp Launcher
  void _sendWhatsApp(WorkLog log) async {
    var cleanPhone = _normalizePhone(log.clientPhone);
    if (cleanPhone.length == 10) cleanPhone = '91$cleanPhone';
    final msg = '*Tractor/JCB Work Slip*\n\n'
        'Party: *${log.clientName}*\n'
        'Date: ${log.date}\n'
        'Machine: ${log.vehicleName}\n'
        'Driver: ${log.driverName}\n'
        'Total Time: *${log.hours} Hours*\n'
        'Rate: ₹${log.rate}/hr\n'
        '-------------------------\n'
        '💰 *Total Bill: ₹${log.totalAmount.toStringAsFixed(0)}*';

    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}');
    
    try {
      final canOpen = await canLaunchUrl(uri);
      if (!mounted) return;
      if (canOpen) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp could not be opened!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _sendSMS(WorkLog log) async {
    final cleanPhone = log.clientPhone.replaceAll(RegExp(r'\D'), '');
    final message = 'Namaste ${log.clientName}, aapke yahan ${log.date} ko ${log.vehicleName} ne ${log.hours} ghante kaam kiya @ ₹${log.rate}/hr. Total Bill: ₹${log.totalAmount.toStringAsFixed(0)}. - LxH ONE';
    
    final uri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: {'body': message},
    );

    try {
      final canOpen = await canLaunchUrl(uri);
      if (!mounted) return;
      if (canOpen) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open SMS: $e')),
      );
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
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
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
    final now = DateTime.now();
    final filteredLogs = logs.where((l) {
      if (l.vehicleType != type) return false;
      try {
        DateTime logDate = DateFormat('dd MMM yyyy').parse(l.date);
        if (selectedFilterDate != null) {
          return logDate.year == selectedFilterDate!.year &&
                 logDate.month == selectedFilterDate!.month &&
                 logDate.day == selectedFilterDate!.day;
        } else {
          final difference = now.difference(logDate).inDays;
          return difference >= 0 && difference <= 3;
        }
      } catch (e) {
        return true;
      }
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$type Fleet List', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
              onPressed: () => _openWorkEntryModal(type),
              icon: const Icon(Icons.add),
              label: Text('New $type Entry'),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  onPressed: () => _editRateDialog(v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _deleteVehicle(v),
                ),
              ],
            ),
          ),
        )),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedFilterDate == null 
                  ? 'Recent $type Logs (Last 3 Days)' 
                  : 'Logs: ${DateFormat('dd MMM yyyy').format(selectedFilterDate!)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                if (selectedFilterDate != null)
                  TextButton(
                    onPressed: () => setState(() => selectedFilterDate = null),
                    child: const Text('Reset', style: TextStyle(color: Colors.red)),
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_month, color: Color(0xFFE65100)),
                  tooltip: 'Past Records',
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedFilterDate ?? DateTime.now(),
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => selectedFilterDate = picked);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        filteredLogs.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No entries found.')))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredLogs.length,
                itemBuilder: (context, i) {
                  final log = filteredLogs[i];
                  final originalIndex = logs.indexWhere((l) => l.id == log.id);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${log.clientName} (${log.date})', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  Text('₹${log.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _deleteLog(originalIndex, log),
                                    child: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${log.vehicleName} | No: ${log.vehicleNumber.isEmpty ? '—' : log.vehicleNumber} | Driver: ${log.driverName}'),
                          Text('Duration: ${log.hours} hrs @ ₹${log.rate}/hr', style: TextStyle(color: Colors.grey.shade700)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.message, size: 16),
                                label: const Text('SMS'),
                                onPressed: () => _sendSMS(log),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                icon: const Icon(Icons.send, size: 16),
                                label: const Text('WhatsApp'),
                                onPressed: () => _sendWhatsApp(log),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
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
          Material(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFFE65100),
              tabs: const [Tab(text: 'Len-Den'), Tab(text: 'ग्राहक बकाया'), Tab(text: 'Cash Book')],
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
        const SizedBox(height: 14),
        const Text('Recent Transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (cashBook.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Abhi koi len-den nahi hai.')))
        else
          ...cashBook.map((entry) => Card(child: ListTile(
            leading: CircleAvatar(
              backgroundColor: entry.type == 'Jama' ? Colors.green.shade50 : Colors.red.shade50,
              child: Icon(entry.type == 'Jama' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: entry.type == 'Jama' ? Colors.green : Colors.red),
            ),
            title: Text(entry.title),
            subtitle: Text(entry.partyName.isNotEmpty ? '${entry.partyName} • ${entry.date}' : entry.date),
            trailing: Text(
              '${entry.type == 'Jama' ? '+' : '-'} ₹${entry.amount.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: entry.type == 'Jama' ? Colors.green : Colors.red),
            ),
          ))),
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
    final unlinkedLogs = logs.where((log) => log.clientId.isEmpty).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(color: Colors.orange.shade50, child: ListTile(
          title: const Text('Total ग्राहक बकाया', style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: Text('₹${totalOutstanding.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 20, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
        )),
        const SizedBox(height: 8),
        if (partiesWithActivity.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('Parties ke saved Work Records yahan dikhai denge.'))
        else
          ...partiesWithActivity.map((party) {
            final bill = _partyBillTotal(party.id);
            final paid = _partyReceivedTotal(party.id);
            final due = bill - paid;
            return Card(child: ListTile(
              title: Text(party.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Bill ₹${bill.toStringAsFixed(0)}  •  Jama ₹${paid.toStringAsFixed(0)}'),
              trailing: Text('₹${(due > 0 ? due : 0).toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: due > 0 ? Colors.red : Colors.green)),
              onTap: () => _showPartyLedger(party),
            ));
          }),
        if (unlinkedLogs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(color: Colors.amber.shade50, child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('${unlinkedLogs.length} purane Work Records kisi current Party se uniquely match nahi hue. Unka data surakshit hai, lekin Party-wise bकाया mein shamil nahi kiya gaya.'),
          )),
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
            ElevatedButton(onPressed: () {
              final amount = double.tryParse(amountController.text.trim()) ?? 0;
              if (amount <= 0 || (type == 'Jama' &&
                  (selectedPartyId == null || !clients.any((p) => p.id == selectedPartyId)))) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valid amount aur Party select karein.')));
                return;
              }
              final selected = clients.where((p) => p.id == selectedPartyId).toList();
              final partyName = selected.isEmpty ? '' : selected.first.name;
              final detail = detailController.text.trim();
              setState(() {
                cashBook.insert(0, CashEntry(
                  title: detail.isNotEmpty ? detail :
                    (type == 'Jama' ? 'Payment received from $partyName' : 'Kharcha'),
                  amount: amount, type: type,
                  date: DateFormat('dd MMM yyyy').format(DateTime.now()),
                  partyId: type == 'Jama' ? selectedPartyId ?? '' : '',
                  partyName: type == 'Jama' ? partyName : '',
                ));
              });
              _saveData();
              Navigator.pop(dialogContext);
              detailController.dispose();
              amountController.dispose();
            }, child: const Text('Save')),
          ],
        ),
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
    if (mounted) setState(() { calculatedTotal = hrs * r; });
  }

  @override
  void dispose() {
    machineNameCtrl.dispose();
    machineNoCtrl.dispose();
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
            Text('New ${widget.vehicleType} Entry', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: machineNameCtrl,
              decoration: InputDecoration(labelText: '${widget.vehicleType} Name (eg. Mahindra 575)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: machineNoCtrl,
              decoration: const InputDecoration(labelText: 'Machine Number (eg. HR-24-A-1020)'),
            ),
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
                Expanded(
                  child: TextField(
                    controller: rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Rate / Hour (₹)', hintText: 'eg. 800'),
                  ),
                ),
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
                    vehicleName: machineNameCtrl.text,
                    vehicleType: widget.vehicleType,
                    driverName: selectedWorker!.name,
                    clientName: selectedClient!.name,
                    clientPhone: selectedClient!.phone,
                    clientId: selectedClient!.id,
                    vehicleNumber: machineNoCtrl.text.trim(),
                    hours: double.tryParse(hoursCtrl.text) ?? 0,
                    rate: double.tryParse(rateCtrl.text) ?? 0,
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
