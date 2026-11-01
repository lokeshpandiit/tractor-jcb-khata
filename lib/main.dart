import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
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
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    role: json['role'] ?? '',
    salaryAmount: (json['salaryAmount'] ?? 0).toDouble(),
    salaryType: json['salaryType'] ?? 'Monthly',
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

  CashEntry({required this.title, required this.amount, required this.type, required this.date});

  Map<String, dynamic> toJson() => {'title': title, 'amount': amount, 'type': type, 'date': date};
  factory CashEntry.fromJson(Map<String, dynamic> json) => CashEntry(
    title: json['title'] ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
    type: json['type'] ?? '',
    date: json['date'] ?? '',
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
        id: json['id'] ?? '',
        driverId: json['driverId'] ?? '',
        type: json['type'] ?? 'Advance',
        amount: (json['amount'] ?? 0).toDouble(),
        reason: json['reason'] ?? '',
        date: json['date'] ?? '',
      );
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
  List<DriverLedgerEntry> driverLedger = [];

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
      logs = decoded.map((e) => WorkLog.fromJson(e)).toList();
    }

    final cashString = prefs.getString('cash_data');
    if (cashString != null) {
      final List decoded = jsonDecode(cashString);
      cashBook = decoded.map((e) => CashEntry.fromJson(e)).toList();
    }

    final driverLedgerString = prefs.getString('driver_ledger_data');
    if (driverLedgerString != null) {
      final List decoded = jsonDecode(driverLedgerString);
      driverLedger = decoded.map((e) => DriverLedgerEntry.fromJson(e)).toList();
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vehicles_data', jsonEncode(vehicles.map((e) => e.toJson()).toList()));
    await prefs.setString('workers_data', jsonEncode(workers.map((e) => e.toJson()).toList()));
    await prefs.setString('clients_data', jsonEncode(clients.map((e) => e.toJson()).toList()));
    await prefs.setString('logs_data', jsonEncode(logs.map((e) => e.toJson()).toList()));
    await prefs.setString('cash_data', jsonEncode(cashBook.map((e) => e.toJson()).toList()));
    await prefs.setString(
      'driver_ledger_data',
      jsonEncode(driverLedger.map((e) => e.toJson()).toList()),
    );
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
            logs.insert(0, log);
            cashBook.insert(0, CashEntry(
              title: '${log.clientName} (${log.vehicleName})',
              amount: log.totalAmount,
              type: 'Jama',
              date: log.date,
            ));
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

  // Safe Contact Picker with Permission check to prevent minimizing crash
  void _addMultiplePersonsDialog(String role) async {
    try {
      var status = await Permission.contacts.status;
      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }

      if (status.isGranted) {
        final Contact? contact = await FlutterContacts.openExternalPick();
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

  // WhatsApp launcher
  void _sendWhatsApp(WorkLog log) async {
    final cleanPhone = log.clientPhone.replaceAll(RegExp(r'\D'), '');
    final msg = '*Tractor/JCB Work Slip*\n\n'
        'Party: *${log.clientName}*\n'
        'Date: ${log.date}\n'
        'Machine: ${log.vehicleName}\n'
        'Driver: ${log.driverName}\n'
        'Total Time: *${log.hours} Hours*\n'
        'Rate: ₹${log.rate}/hr\n'
        '-------------------------\n'
        '💰 *Total Bill: ₹${log.totalAmount.toStringAsFixed(0)}*';

    final uri = Uri.parse('https://wa.me/91$cleanPhone?text=${Uri.encodeComponent(msg)}');
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp could not be opened!')),
        );
      }
    } catch (e) {
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
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
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
          NavigationDestination(icon: Icon(Icons.engineering), label: 'Drivers'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Parties'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Khata/Cash'),
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
                          Text('${log.vehicleName} | Driver: ${log.driverName}'),
                          Text('Duration: ${log.hours} hrs @ ₹${log.rate}/hr', style: TextStyle(color: Colors.grey.shade700)),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE65100),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('Send'),
                              onPressed: () => _showSendOptions(log),
                            ),
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

  void _openDriverKhata(Person driver) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverKhataScreen(
          driver: driver,
          entries: driverLedger,
          onChanged: () {
            _saveData();
            if (mounted) setState(() {});
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
    double totalJama = cashBook.where((c) => c.type == 'Jama').fold(0.0, (sum, c) => sum + c.amount);
    double totalKharcha = cashBook.where((c) => c.type == 'Kharcha').fold(0.0, (sum, c) => sum + c.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  const Text('Total Jama (Kamai)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  Text('₹${totalJama.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                ]),
                Column(children: [
                  const Text('Total Kharcha', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  Text('₹${totalKharcha.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Kharcha / Cash Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            OutlinedButton.icon(
              onPressed: _addExpenseDialog,
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              label: const Text('Add Kharcha'),
            )
          ],
        ),
        const SizedBox(height: 12),
        ...cashBook.map((c) => ListTile(
          leading: Icon(c.type == 'Jama' ? Icons.arrow_downward : Icons.arrow_upward, color: c.type == 'Jama' ? Colors.green : Colors.red),
          title: Text(c.title),
          subtitle: Text(c.date),
          trailing: Text(
            '${c.type == 'Jama' ? '+' : '-'} ₹${c.amount.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: c.type == 'Jama' ? Colors.green : Colors.red),
          ),
        )),
      ],
    );
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
                    type: 'Kharcha',
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


class DriverKhataScreen extends StatefulWidget {
  final Person driver;
  final List<DriverLedgerEntry> entries;
  final VoidCallback onChanged;

  const DriverKhataScreen({
    super.key,
    required this.driver,
    required this.entries,
    required this.onChanged,
  });

  @override
  State<DriverKhataScreen> createState() => _DriverKhataScreenState();
}

class _DriverKhataScreenState extends State<DriverKhataScreen> {
  DateTime? selectedDate;

  List<DriverLedgerEntry> get _driverEntries => widget.entries.where(
    (entry) => entry.driverId == widget.driver.id,
  ).toList();

  double _totalFor(String type) => _driverEntries
      .where((entry) => entry.type == type)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  String _money(double amount) => '₹\${amount.toStringAsFixed(0)}';

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

    final amount = double.tryParse(amountController.text.trim());
    final reason = reasonController.text.trim();
    amountController.dispose();
    reasonController.dispose();

    if (saved == true && amount != null && amount > 0 && reason.isNotEmpty) {
      setState(() {
        widget.entries.insert(
          0,
          DriverLedgerEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            driverId: widget.driver.id,
            type: type,
            amount: amount,
            reason: reason,
            date: DateFormat('dd MMM yyyy').format(entryDate),
          ),
        );
      });
      widget.onChanged();
    }
  }

  Future<void> _pickHistoryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDate = picked);
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
    final balance = salaryDue - salaryPaid - advances - otherPayments;

    return Scaffold(
      appBar: AppBar(
        title: Text('\${widget.driver.name} Khata'),
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
                    'Salary: \${_money(widget.driver.salaryAmount)} / \${widget.driver.salaryType}',
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
              _summaryCard('Balance Due', balance, balance >= 0 ? Colors.red : Colors.deepPurple),
            ],
          ),
          const SizedBox(height: 12),
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
                      : 'Transactions: \${DateFormat('dd MMM yyyy').format(selectedDate!)}',
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
              final sign = isDue ? '+' : '-';
              final color = isDue ? Colors.green : Colors.red;
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
                  subtitle: Text('\${entry.reason}\\n\${entry.date}'),
                  isThreeLine: true,
                  trailing: Text(
                    '\$sign \${_money(entry.amount)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          if (otherPayments > 0)
            Text(
              'Other payments recorded: \${_money(otherPayments)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
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
