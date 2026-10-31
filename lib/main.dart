import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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

// Data Models
class Vehicle {
  final String id;
  final String name;
  final String number;
  final String type; // 'Tractor' or 'JCB'
  double defaultRate;

  Vehicle({required this.id, required this.name, required this.number, required this.type, required this.defaultRate});
}

class Person {
  final String id;
  String name;
  String phone;
  final String role; // 'Worker' or 'Client'

  Person({required this.id, required this.name, required this.phone, required this.role});
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
}

class CashEntry {
  final String title;
  final double amount;
  final String type; // 'Kharcha' or 'Jama'
  final String date;

  CashEntry({required this.title, required this.amount, required this.type, required this.date});
}

// Main Navigation Screen
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Global State
  List<Vehicle> vehicles = [
    Vehicle(id: '1', name: 'Mahindra 575 DI', number: 'HR-24-A-1020', type: 'Tractor', defaultRate: 800),
    Vehicle(id: '2', name: 'Swaraj 855 FE', number: 'HR-24-B-4500', type: 'Tractor', defaultRate: 850),
    Vehicle(id: '3', name: 'JCB 3DX Super', number: 'HR-24-E-9901', type: 'JCB', defaultRate: 1400),
  ];

  List<Person> workers = [
    Person(id: 'w1', name: 'Ramesh Driver', phone: '9876543210', role: 'Worker'),
    Person(id: 'w2', name: 'Suresh Operator', phone: '9123456780', role: 'Worker'),
  ];

  List<Person> clients = [
    Person(id: 'c1', name: 'Satish Zamindar', phone: '9988776655', role: 'Client'),
    Person(id: 'c2', name: 'Amit Builder', phone: '9416012345', role: 'Client'),
  ];

  List<WorkLog> logs = [];
  List<CashEntry> cashBook = [];

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
        },
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
                // Also remove matching entry from cashbook if exists
                cashBook.removeWhere((c) => c.title == '${log.clientName} (${log.vehicleName})' && c.amount == log.totalAmount && c.date == log.date);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBackupRestoreDialog() {
    final restoreController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backup & Restore'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('1. Apne poore data ka backup copy karein ya WhatsApp par bhejein:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Backup JSON'),
                onPressed: () {
                  final data = {
                    'logs': logs.map((l) => {'id': l.id, 'date': l.date, 'vehicleName': l.vehicleName, 'vehicleType': l.vehicleType, 'driverName': l.driverName, 'clientName': l.clientName, 'clientPhone': l.clientPhone, 'hours': l.hours, 'rate': l.rate, 'totalAmount': l.totalAmount}).toList(),
                  };
                  Clipboard.setData(ClipboardData(text: jsonEncode(data)));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup Copied to Clipboard!')));
                },
              ),
              const Divider(height: 24),
              const Text('2. Purana backup yahan paste karke Restore karein:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: restoreController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Paste Backup JSON here', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: () {
                  try {
                    final decoded = jsonDecode(restoreController.text);
                    final List fetchedLogs = decoded['logs'] ?? [];
                    setState(() {
                      logs = fetchedLogs.map((l) => WorkLog(
                        id: l['id'] ?? '',
                        date: l['date'] ?? '',
                        vehicleName: l['vehicleName'] ?? '',
                        vehicleType: l['vehicleType'] ?? '',
                        driverName: l['driverName'] ?? '',
                        clientName: l['clientName'] ?? '',
                        clientPhone: l['clientPhone'] ?? '',
                        hours: (l['hours'] ?? 0).toDouble(),
                        rate: (l['rate'] ?? 0).toDouble(),
                        totalAmount: (l['totalAmount'] ?? 0).toDouble(),
                      )).toList();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data Restored Successfully!')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Backup Data!')));
                  }
                },
                child: const Text('Restore Data'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.settings_backup_restore, color: Colors.white),
            tooltip: 'Backup & Restore',
            onPressed: _showBackupRestoreDialog,
          ),
        ],
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
    final filteredLogs = logs.where((l) => l.vehicleType == type).toList();

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
            subtitle: Text('No: ${v.number} | Default: ₹${v.defaultRate.toStringAsFixed(0)}/hr'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _editRateDialog(v);
              },
            ),
          ),
        )),
        const Divider(height: 32),
        Text('Recent $type Logs', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        filteredLogs.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No entries added yet.')))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredLogs.length,
                itemBuilder: (context, i) {
                  final log = filteredLogs[i];
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
                                    onTap: () => _deleteLog(i, log),
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
    final controller = TextEditingController(text: v.defaultRate.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Rate: ${v.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Default Rate Per Hour (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                v.defaultRate = double.tryParse(controller.text) ?? v.defaultRate;
              });
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
              onPressed: () => _addPersonDialog(role),
              icon: const Icon(Icons.person_add),
              label: const Text('Add New'),
            )
          ],
        ),
        const SizedBox(height: 12),
        ...list.map((p) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(p.name[0])),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(p.phone),
            trailing: IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () => launchUrl(Uri.parse('tel:${p.phone}')),
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
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Detail (eg. Diesel / Driver Kharcha)')),
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
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _addPersonDialog(String role) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add $role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number')),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.contacts),
              label: const Text('Choose from Contacts'),
              onPressed: () async {
                if (await Permission.contacts.request().isGranted) {
                  final contact = await FlutterContacts.openExternalPick();
                  if (contact != null && contact.phones.isNotEmpty) {
                    nameCtrl.text = contact.displayName;
                    phoneCtrl.text = contact.phones.first.number.replaceAll(RegExp(r'\D'), '');
                  }
                }
              },
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                setState(() {
                  final newP = Person(id: DateTime.now().toString(), name: nameCtrl.text, phone: phoneCtrl.text, role: role);
                  if (role == 'Worker') {
                    workers.add(newP);
                  } else {
                    clients.add(newP);
                  }
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _sendSMS(WorkLog log) async {
    final msg = Uri.encodeComponent(
      'Namaste ${log.clientName}, aapke yahan ${log.date} ko ${log.vehicleName} ne ${log.hours} ghante kaam kiya @ ₹${log.rate}/hr. Total Bill: ₹${log.totalAmount.toStringAsFixed(0)}.'
    );
    final uri = Uri.parse('sms:${log.clientPhone}?body=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _sendWhatsApp(WorkLog log) async {
    final cleanPhone = log.clientPhone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent(
      '🚜 *Tractor/JCB Work Slip*\n\n'
      'Party: *${log.clientName}*\n'
      'Date: ${log.date}\n'
      'Machine: ${log.vehicleName}\n'
      'Driver: ${log.driverName}\n'
      'Total Time: *${log.hours} Hours*\n'
      'Rate: ₹${log.rate}/hr\n'
      '-------------------------\n'
      '💰 *Total Bill: ₹${log.totalAmount.toStringAsFixed(0)}*'
    );
    final uri = Uri.parse('https://wa.me/91$cleanPhone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// Work Entry Form Sheet with Live Hourly Calculation
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
              items: widget.vehicles.map((v) => DropdownMenuItem(value: v, child: Text('${v.name} (${v.number})'))).toList(),
              onChanged: (v) {
                setState(() {
                  selectedVehicle = v;
                  rateCtrl.text = v!.defaultRate.toStringAsFixed(0);
                  _recalculate();
                });
              },
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
              decoration: const InputDecoration(labelText: 'Select Client (Jinke Kaam Gaya)'),
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
                if (selectedVehicle != null && selectedWorker != null && selectedClient != null && calculatedTotal > 0) {
                  final log = WorkLog(
                    id: DateTime.now().toString(),
                    date: DateFormat('dd MMM yyyy').format(selectedDate),
                    vehicleName: selectedVehicle!.name,
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
              child: const Text('Save Record & Show Share Option', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
