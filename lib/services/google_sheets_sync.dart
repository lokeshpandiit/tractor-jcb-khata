import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class GoogleSheetsSyncResult {
  final String spreadsheetId;
  final int sheetCount;

  const GoogleSheetsSyncResult({
    required this.spreadsheetId,
    required this.sheetCount,
  });
}

class _LedgerEvent {
  final DateTime date;
  final int priority;
  final Map<String, dynamic> data;
  final String kind;

  const _LedgerEvent({
    required this.date,
    required this.priority,
    required this.data,
    required this.kind,
  });
}

/// One Google spreadsheet per Google account. Each customer and driver gets
/// a dedicated tab. Managed tabs are rebuilt from a complete local snapshot,
/// which makes retries idempotent and avoids duplicate transaction rows.
class GoogleSheetsSyncService {
  GoogleSheetsSyncService._();

  static const String spreadsheetIdPreferenceKey = 'google_sheets_spreadsheet_id';
  static const List<String> _baseSheetTitles = <String>[
    'Master Summary', 'Work Records', 'Cash Book', 'Expenses', 'Advance Requests',
  ];
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  static Future<GoogleSheetsSyncResult> sync({
    required String accessToken,
    required String accountEmail,
    required Map<String, dynamic> snapshot,
    String? spreadsheetId,
    Future<void> Function(String spreadsheetId)? onSpreadsheetIdCreated,
    http.Client? httpClient,
  }) async {
    if (accessToken.trim().isEmpty) {
      throw ArgumentError.value(accessToken, 'accessToken', 'Cannot be empty');
    }
    final client = httpClient ?? http.Client();
    try {
      final workbook = buildWorkbookData(snapshot, accountEmail: accountEmail);
      var id = spreadsheetId;
      if (id == null || id.trim().isEmpty) {
        id = await _createSpreadsheet(client, accessToken, accountEmail);
        if (onSpreadsheetIdCreated != null) {
          await onSpreadsheetIdCreated(id);
        }
      }

      var metadata = await _getMetadata(client, accessToken, id);
      final existingTitles = metadata
          .map((sheet) => (sheet['title'] ?? '').toString())
          .where((title) => title.isNotEmpty)
          .toSet();
      final missingTitles = workbook.keys
          .where((title) => !existingTitles.contains(title))
          .toList();

      if (missingTitles.isNotEmpty) {
        await _batchUpdate(client, accessToken, id, <String, dynamic>{
          'requests': missingTitles.map((title) => <String, dynamic>{
            'addSheet': <String, dynamic>{
              'properties': <String, dynamic>{'title': title},
            },
          }).toList(),
        });
        metadata = await _getMetadata(client, accessToken, id);
      }

      final availableTitles = metadata
          .map((sheet) => (sheet['title'] ?? '').toString())
          .toSet();
      final missingAfterCreate = workbook.keys
          .where((title) => !availableTitles.contains(title))
          .toList();
      if (missingAfterCreate.isNotEmpty) {
        throw StateError('Google Sheets did not create tabs: ${missingAfterCreate.join(', ')}');
      }

      final ranges = workbook.keys
          .map((title) => '${_quoteSheetTitle(title)}!A:Z')
          .toList();
      await _post(
        client,
        accessToken,
        Uri.https('sheets.googleapis.com', '/v4/spreadsheets/$id/values:batchClear'),
        <String, dynamic>{'ranges': ranges},
        'Could not clear old LxH ONE sheet values',
      );

      final valueData = workbook.entries.map((entry) => <String, dynamic>{
        'range': '${_quoteSheetTitle(entry.key)}!A1',
        'majorDimension': 'ROWS',
        'values': entry.value,
      }).toList();

      await _post(
        client,
        accessToken,
        Uri.https('sheets.googleapis.com', '/v4/spreadsheets/$id/values:batchUpdate'),
        <String, dynamic>{'valueInputOption': 'RAW', 'data': valueData},
        'Could not write LxH ONE accounting tabs',
      );

      return GoogleSheetsSyncResult(spreadsheetId: id, sheetCount: workbook.length);
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Pure workbook builder for repeatable unit testing without a live account.
  static Map<String, List<List<Object?>>> buildWorkbookData(
    Map<String, dynamic> snapshot, {
    required String accountEmail,
    DateTime? generatedAt,
  }) {
    final workers = _decodeList(snapshot, 'workers_data');
    final clients = _decodeList(snapshot, 'clients_data');
    final workLogs = _decodeList(snapshot, 'logs_data');
    final cashEntries = _decodeList(snapshot, 'cash_data');
    final advanceRequests = _decodeList(snapshot, 'advance_requests_data');
    final driverLedger = _decodeList(snapshot, 'driver_ledger_data');

    final customerTabs = <String, String>{};
    for (final customer in clients) {
      final id = _string(customer['id']);
      customerTabs[id] = _entityTabTitle(
        'Customer', _string(customer['name'], fallback: 'Unnamed Customer'), id,
      );
    }
    final driverTabs = <String, String>{};
    for (final driver in workers) {
      final id = _string(driver['id']);
      driverTabs[id] = _entityTabTitle(
        'Driver', _string(driver['name'], fallback: 'Unnamed Driver'), id,
      );
    }

    final totalBills = workLogs.fold<double>(0, (sum, log) => sum + _number(log['totalAmount']));
    final totalJama = cashEntries
        .where((entry) => _string(entry['type']) == 'Jama')
        .fold<double>(0, (sum, entry) => sum + _number(entry['amount']));
    final totalKharcha = cashEntries
        .where((entry) => _string(entry['type']) == 'Kharcha')
        .fold<double>(0, (sum, entry) => sum + _number(entry['amount']));
    final totalSalaryDue = driverLedger
        .where((entry) => _string(entry['type']) == 'Salary Due')
        .fold<double>(0, (sum, entry) => sum + _number(entry['amount']));
    final totalDriverPaid = driverLedger
        .where((entry) => const <String>{'Salary Paid', 'Advance', 'Other Payment'}
            .contains(_string(entry['type'])))
        .fold<double>(0, (sum, entry) => sum + _number(entry['amount']));
    final outstanding = clients.fold<double>(0, (sum, customer) {
      final id = _string(customer['id']);
      final name = _string(customer['name']);
      final bill = workLogs.where((log) => _belongsToCustomer(log, id, name))
          .fold<double>(0, (value, log) => value + _number(log['totalAmount']));
      final paid = cashEntries.where((entry) =>
        _string(entry['type']) == 'Jama' && _belongsToCustomer(entry, id, name))
          .fold<double>(0, (value, entry) => value + _number(entry['amount']));
      return sum + bill - paid;
    });

    final now = generatedAt ?? DateTime.now();
    final sheets = <String, List<List<Object?>>>{};

    sheets['Master Summary'] = <List<Object?>>[
      <Object?>['LxH ONE — Hisab Kitab'],
      <Object?>['Google Account', accountEmail],
      <Object?>['Last Generated', now.toIso8601String()],
      <Object?>[],
      <Object?>['Overall Summary', 'Amount (INR)'],
      <Object?>['Total Work Bills', totalBills],
      <Object?>['Customer Payments Received', totalJama],
      <Object?>['Customer Outstanding', outstanding],
      <Object?>['Driver Salary Due', totalSalaryDue],
      <Object?>['Salary + Advance + Other Paid', totalDriverPaid],
      <Object?>['Total Cash Jama', totalJama],
      <Object?>['Total Cash Kharcha', totalKharcha],
      <Object?>['Cash Net (Jama - Kharcha)', totalJama - totalKharcha],
      <Object?>[],
      <Object?>['Customer', 'Total Bills', 'Received', 'Balance', 'Sheet Tab'],
      ...clients.map((customer) {
        final id = _string(customer['id']);
        final name = _string(customer['name']);
        final bill = workLogs.where((log) => _belongsToCustomer(log, id, name))
            .fold<double>(0, (sum, log) => sum + _number(log['totalAmount']));
        final paid = cashEntries.where((entry) =>
          _string(entry['type']) == 'Jama' && _belongsToCustomer(entry, id, name))
            .fold<double>(0, (sum, entry) => sum + _number(entry['amount']));
        return <Object?>[name, bill, paid, bill - paid, customerTabs[id] ?? ''];
      }),
      <Object?>[],
      <Object?>['Driver', 'Salary Due', 'Salary Paid', 'Advance', 'Other Payment', 'Balance', 'Sheet Tab'],
      ...workers.map((driver) {
        final id = _string(driver['id']);
        final entries = driverLedger.where((entry) => _string(entry['driverId']) == id);
        final due = _sumType(entries, 'Salary Due');
        final salary = _sumType(entries, 'Salary Paid');
        final advance = _sumType(entries, 'Advance');
        final other = _sumType(entries, 'Other Payment');
        return <Object?>[
          _string(driver['name']), due, salary, advance, other,
          due - salary - advance - other, driverTabs[id] ?? '',
        ];
      }),
    ];

    final sortedWork = List<Map<String, dynamic>>.from(workLogs)..sort(_compareByDate);
    sheets['Work Records'] = <List<Object?>>[
      <Object?>['Date', 'Customer', 'Machine Type', 'Machine', 'Vehicle Number',
        'Driver', 'Hours', 'Rate / Hour', 'Work Bill', 'Work ID'],
      ...sortedWork.map((log) => <Object?>[
        _string(log['date']), _string(log['clientName']), _string(log['vehicleType']),
        _string(log['vehicleName']), _string(log['vehicleNumber']), _string(log['driverName']),
        _number(log['hours']), _number(log['rate']), _number(log['totalAmount']), _string(log['id']),
      ]),
    ];

    final sortedCash = List<Map<String, dynamic>>.from(cashEntries)..sort(_compareByDate);
    sheets['Cash Book'] = <List<Object?>>[
      <Object?>['Date', 'Type', 'Party / Person', 'Details', 'Jama', 'Kharcha', 'Amount', 'Transaction ID'],
      ...sortedCash.map((entry) {
        final isJama = _string(entry['type']) == 'Jama';
        final amount = _number(entry['amount']);
        return <Object?>[
          _string(entry['date']), _string(entry['type']), _string(entry['partyName']),
          _string(entry['title']), isJama ? amount : 0, isJama ? 0 : amount,
          amount, _string(entry['id']),
        ];
      }),
    ];

    sheets['Expenses'] = <List<Object?>>[
      <Object?>['Date', 'Category', 'Details', 'Amount', 'Expense ID'],
      ...sortedCash.where((entry) => _string(entry['type']) == 'Kharcha').map((entry) {
        final title = _string(entry['title']);
        final category = title.toLowerCase().startsWith('driver payment:')
            ? 'Driver Payment' : 'General / Other';
        return <Object?>[
          _string(entry['date']), category, title, _number(entry['amount']), _string(entry['id']),
        ];
      }),
    ];

    sheets['Advance Requests'] = <List<Object?>>[
      <Object?>['Date', 'Person', 'Amount Requested', 'Reason / Note', 'Request ID'],
      ...advanceRequests.map((entry) => <Object?>[
        _string(entry['date']), _string(entry['name']), _number(entry['amount']),
        _string(entry['note']), _string(entry['id']),
      ]),
    ];

    for (final customer in clients) {
      final id = _string(customer['id']);
      final name = _string(customer['name'], fallback: 'Unnamed Customer');
      final events = <_LedgerEvent>[];
      for (final log in workLogs.where((log) => _belongsToCustomer(log, id, name))) {
        events.add(_LedgerEvent(
          date: _parseDate(_string(log['date'])), priority: 0, data: log, kind: 'Work Bill',
        ));
      }
      for (final payment in cashEntries.where((entry) =>
        _string(entry['type']) == 'Jama' && _belongsToCustomer(entry, id, name))) {
        events.add(_LedgerEvent(
          date: _parseDate(_string(payment['date'])), priority: 1,
          data: payment, kind: 'Payment Received',
        ));
      }
      events.sort(_compareEvents);

      var balance = 0.0;
      final rows = <List<Object?>>[
        <Object?>['Customer Ledger — $name'],
        <Object?>['Phone', _string(customer['phone'])],
        <Object?>['Total Work Bill', events.where((e) => e.kind == 'Work Bill')
          .fold<double>(0, (sum, e) => sum + _number(e.data['totalAmount']))],
        <Object?>['Total Received', events.where((e) => e.kind == 'Payment Received')
          .fold<double>(0, (sum, e) => sum + _number(e.data['amount']))],
        <Object?>['Current Balance', events.fold<double>(0, (sum, e) =>
          sum + (e.kind == 'Work Bill' ? _number(e.data['totalAmount']) : -_number(e.data['amount'])))],
        <Object?>[],
        <Object?>['Date', 'Entry Type', 'Details', 'Machine Type', 'Machine',
          'Vehicle Number', 'Driver', 'Hours', 'Rate / Hour', 'Bill Amount',
          'Payment Received', 'Running Balance', 'Record ID'],
      ];
      for (final event in events) {
        final data = event.data;
        final isBill = event.kind == 'Work Bill';
        final amount = isBill ? _number(data['totalAmount']) : _number(data['amount']);
        balance += isBill ? amount : -amount;
        rows.add(<Object?>[
          _dateFormat.format(event.date), event.kind,
          isBill ? 'Machine work bill' : _string(data['title']),
          isBill ? _string(data['vehicleType']) : '',
          isBill ? _string(data['vehicleName']) : '',
          isBill ? _string(data['vehicleNumber']) : '',
          isBill ? _string(data['driverName']) : '',
          isBill ? _number(data['hours']) : 0,
          isBill ? _number(data['rate']) : 0,
          isBill ? amount : 0, isBill ? 0 : amount, balance, _string(data['id']),
        ]);
      }
      sheets[customerTabs[id]!] = rows;
    }

    for (final driver in workers) {
      final id = _string(driver['id']);
      final name = _string(driver['name'], fallback: 'Unnamed Driver');
      final events = <_LedgerEvent>[];
      for (final log in workLogs.where((log) =>
        _string(log['driverName']).trim().toLowerCase() == name.trim().toLowerCase())) {
        events.add(_LedgerEvent(
          date: _parseDate(_string(log['date'])), priority: 0,
          data: log, kind: 'Work Assignment',
        ));
      }
      for (final entry in driverLedger.where((entry) => _string(entry['driverId']) == id)) {
        final type = _string(entry['type'], fallback: 'Driver Entry');
        events.add(_LedgerEvent(
          date: _parseDate(_string(entry['date'])),
          priority: type == 'Salary Due' ? 1 : 2,
          data: entry, kind: type,
        ));
      }
      events.sort(_compareEvents);

      var balance = 0.0;
      final rows = <List<Object?>>[
        <Object?>['Driver Ledger — $name'],
        <Object?>['Phone', _string(driver['phone'])],
        <Object?>['Salary Setting', _number(driver['salaryAmount']), _string(driver['salaryType'])],
        <Object?>[],
        <Object?>['Date', 'Entry Type', 'Customer / Details', 'Machine Type', 'Machine',
          'Vehicle Number', 'Hours', 'Work Bill (Info Only)', 'Salary Due',
          'Salary Paid', 'Advance', 'Other Payment', 'Running Salary Balance',
          'Reason / Notes', 'Entry ID'],
      ];
      for (final event in events) {
        final data = event.data;
        final isWork = event.kind == 'Work Assignment';
        final type = event.kind;
        final amount = _number(data['amount']);
        final due = type == 'Salary Due' ? amount : 0.0;
        final salaryPaid = type == 'Salary Paid' ? amount : 0.0;
        final advance = type == 'Advance' ? amount : 0.0;
        final other = type == 'Other Payment' ? amount : 0.0;
        if (!isWork) balance += due - salaryPaid - advance - other;
        rows.add(<Object?>[
          _dateFormat.format(event.date), type,
          isWork ? _string(data['clientName']) : name,
          isWork ? _string(data['vehicleType']) : '',
          isWork ? _string(data['vehicleName']) : '',
          isWork ? _string(data['vehicleNumber']) : '',
          isWork ? _number(data['hours']) : 0,
          isWork ? _number(data['totalAmount']) : 0,
          due, salaryPaid, advance, other, balance,
          isWork ? 'Work bill shown for reference only' : _string(data['reason']),
          _string(data['id']),
        ]);
      }
      sheets[driverTabs[id]!] = rows;
    }

    return sheets;
  }

  static Future<String> _createSpreadsheet(http.Client client, String token, String email) async {
    final response = await _post(
      client, token, Uri.https('sheets.googleapis.com', '/v4/spreadsheets'),
      <String, dynamic>{
        'properties': <String, dynamic>{'title': 'LxH ONE - Hisab Kitab - $email'},
        'sheets': _baseSheetTitles.map((title) => <String, dynamic>{
          'properties': <String, dynamic>{'title': title},
        }).toList(),
      },
      'Could not create LxH ONE Google Spreadsheet',
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final id = (decoded['spreadsheetId'] ?? '').toString();
    if (id.isEmpty) throw StateError('Google Sheets returned an empty spreadsheet ID.');
    return id;
  }

  static Future<List<Map<String, dynamic>>> _getMetadata(
    http.Client client, String token, String id,
  ) async {
    final response = await client.get(
      Uri.https('sheets.googleapis.com', '/v4/spreadsheets/$id', {
        'fields': 'spreadsheetId,sheets.properties(sheetId,title)',
      }),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );
    _check(response, 'Could not read Google Spreadsheet tabs');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final sheets = decoded['sheets'] as List<dynamic>? ?? <dynamic>[];
    return sheets.whereType<Map<String, dynamic>>().map((sheet) =>
      Map<String, dynamic>.from(
        sheet['properties'] as Map<String, dynamic>? ?? <String, dynamic>{},
      )).toList();
  }

  static Future<http.Response> _batchUpdate(
    http.Client client, String token, String id, Map<String, dynamic> body,
  ) => _post(
    client, token,
    Uri.https('sheets.googleapis.com', '/v4/spreadsheets/$id:batchUpdate'),
    body, 'Could not create customer or driver tabs',
  );

  static Future<http.Response> _post(
    http.Client client, String token, Uri uri, Map<String, dynamic> body, String action,
  ) async {
    final response = await client.post(uri, headers: <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=UTF-8',
    }, body: jsonEncode(body));
    _check(response, action);
    return response;
  }

  static void _check(http.Response response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.length > 600 ? response.body.substring(0, 600) : response.body;
      throw StateError('$action. HTTP ${response.statusCode}: $body');
    }
  }

  static List<Map<String, dynamic>> _decodeList(Map<String, dynamic> snapshot, String key) {
    final raw = snapshot[key];
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static String _entityTabTitle(String prefix, String name, String id) {
    final safeName = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ').trim();
    final encoded = base64Url.encode(utf8.encode(id.isEmpty ? name : id)).replaceAll('=', '');
    final suffix = encoded.isEmpty ? 'NO-ID' : encoded.substring(0, min(7, encoded.length));
    final maxNameLength = 96 - prefix.length - suffix.length - 5;
    final namePart = safeName.isEmpty ? 'Unnamed' : safeName.substring(0, min(safeName.length, maxNameLength));
    return '$prefix - $namePart - $suffix';
  }

  static String _quoteSheetTitle(String title) => "'${title.replaceAll("'", "''")}'";

  static bool _belongsToCustomer(Map<String, dynamic> record, String customerId, String customerName) {
    final recordId = _string(record['clientId'] ?? record['partyId']);
    if (recordId.isNotEmpty && customerId.isNotEmpty) return recordId == customerId;
    final recordName = _string(record['clientName']).trim().toLowerCase();
    final partyName = _string(record['partyName']).trim().toLowerCase();
    final name = customerName.trim().toLowerCase();
    return (recordName.isNotEmpty && recordName == name) ||
        (partyName.isNotEmpty && partyName == name);
  }

  static double _sumType(Iterable<Map<String, dynamic>> entries, String type) =>
      entries.where((entry) => _string(entry['type']) == type)
          .fold<double>(0, (sum, entry) => sum + _number(entry['amount']));

  static int _compareByDate(Map<String, dynamic> a, Map<String, dynamic> b) =>
      _parseDate(_string(a['date'])).compareTo(_parseDate(_string(b['date'])));

  static int _compareEvents(_LedgerEvent a, _LedgerEvent b) {
    final result = a.date.compareTo(b.date);
    return result != 0 ? result : a.priority.compareTo(b.priority);
  }

  static DateTime _parseDate(String value) {
    try {
      return _dateFormat.parseStrict(value);
    } catch (_) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime(1970);
      }
    }
  }

  static String _string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
