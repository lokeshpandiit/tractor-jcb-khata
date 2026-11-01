import 'package:flutter_test/flutter_test.dart';
import 'package:tractor_jcb_khata/services/google_sheets_sync.dart';

void main() {
  final snapshot = <String, dynamic>{
    'clients_data': '[{"id":"cust-1","name":"Satish","phone":"9999999999"},{"id":"cust-2","name":"Amit","phone":"8888888888"}]',
    'workers_data': '[{"id":"driver-1","name":"Ramesh","phone":"7777777777","salaryAmount":15000,"salaryType":"Monthly"},{"id":"driver-2","name":"Suresh","phone":"6666666666","salaryAmount":12000,"salaryType":"Monthly"}]',
    'logs_data': '[{"id":"work-1","date":"01 Nov 2026","vehicleName":"Mahindra 575","vehicleType":"Tractor","driverName":"Ramesh","driverId":"driver-1","clientName":"Satish","clientId":"cust-1","vehicleNumber":"HR24A1001","hours":5,"rate":800,"totalAmount":4000},{"id":"work-2","date":"02 Nov 2026","vehicleName":"JCB 3DX","vehicleType":"JCB","driverName":"Ramesh","clientName":"Satish","clientId":"cust-1","vehicleNumber":"HR24B2002","hours":4,"rate":1500,"totalAmount":6000},{"id":"work-3","date":"02 Nov 2026","vehicleName":"Tractor","vehicleType":"Tractor","driverName":"Suresh","driverId":"driver-2","clientName":"Amit","clientId":"cust-2","vehicleNumber":"HR24C3003","hours":2,"rate":900,"totalAmount":1800}]',
    'cash_data': '[{"id":"pay-1","date":"02 Nov 2026","title":"Part payment","amount":3000,"type":"Jama","partyId":"cust-1","partyName":"Satish"},{"id":"expense-1","date":"02 Nov 2026","title":"Diesel","amount":2000,"type":"Kharcha"}]',
    'driver_ledger_data': '[{"id":"due-1","driverId":"driver-1","type":"Salary Due","amount":15000,"reason":"November salary","date":"01 Nov 2026"},{"id":"paid-1","driverId":"driver-1","type":"Salary Paid","amount":5000,"reason":"Salary installment","date":"02 Nov 2026"},{"id":"advance-1","driverId":"driver-1","type":"Advance","amount":12000,"reason":"Home expense","date":"03 Nov 2026"}]',
    'advance_requests_data': '[]',
  };

  test('creates a separate tab for every customer and every driver', () {
    final workbook = GoogleSheetsSyncService.buildWorkbookData(
      snapshot, accountEmail: 'test@example.com', generatedAt: DateTime(2026, 11, 3),
    );
    expect(workbook.keys.any((title) => title.startsWith('Customer - Satish')), isTrue);
    expect(workbook.keys.any((title) => title.startsWith('Customer - Amit')), isTrue);
    expect(workbook.keys.any((title) => title.startsWith('Driver - Ramesh')), isTrue);
    expect(workbook.keys.any((title) => title.startsWith('Driver - Suresh')), isTrue);
  });

  test('customer tab includes work hours, bills, payment and correct running balance', () {
    final workbook = GoogleSheetsSyncService.buildWorkbookData(
      snapshot, accountEmail: 'test@example.com', generatedAt: DateTime(2026, 11, 3),
    );
    final title = workbook.keys.firstWhere((value) => value.startsWith('Customer - Satish'));
    final rows = workbook[title]!;
    expect(rows[6], contains('Running Balance'));
    expect(rows.any((row) => row.contains('Mahindra 575')), isTrue);
    expect(rows.any((row) => row.contains('Payment Received')), isTrue);
    expect(rows[4][1], 7000);
    expect(rows.last[11], 7000);
  });

  test('driver tab tracks machine work and negative extra-taken salary balance', () {
    final workbook = GoogleSheetsSyncService.buildWorkbookData(
      snapshot, accountEmail: 'test@example.com', generatedAt: DateTime(2026, 11, 3),
    );
    final title = workbook.keys.firstWhere((value) => value.startsWith('Driver - Ramesh'));
    final rows = workbook[title]!;
    expect(rows.any((row) => row.contains('Mahindra 575')), isTrue);
    expect(rows.any((row) => row.contains('Salary Due')), isTrue);
    expect(rows.last[12], -2000);
  });

  test('Cash Book and Expenses are separate tabs', () {
    final workbook = GoogleSheetsSyncService.buildWorkbookData(snapshot, accountEmail: 'test@example.com');
    expect(workbook['Cash Book']!.any((row) => row.contains('Part payment')), isTrue);
    expect(workbook['Expenses']!.any((row) => row.contains('Diesel')), isTrue);
    expect(workbook['Master Summary']!.any((row) => row.contains('Customer Outstanding')), isTrue);
  });


  test('same driver names remain isolated by Driver ID', () {
    final duplicateNameSnapshot = <String, dynamic>{
      'workers_data': '[{"id":"driver-a","name":"Ramesh"},{"id":"driver-b","name":"Ramesh"}]',
      'logs_data': '[{"id":"job-a","date":"01 Nov 2026","driverName":"Ramesh","driverId":"driver-a","clientName":"Satish","hours":2,"totalAmount":1000},{"id":"job-b","date":"01 Nov 2026","driverName":"Ramesh","driverId":"driver-b","clientName":"Amit","hours":3,"totalAmount":1500}]',
    };
    final workbook = GoogleSheetsSyncService.buildWorkbookData(
      duplicateNameSnapshot,
      accountEmail: 'test@example.com',
      generatedAt: DateTime(2026, 11, 3),
    );
    final driverATab = workbook.keys.firstWhere((title) => title.startsWith('Driver - Ramesh'));
    final otherTabs = workbook.keys.where((title) => title.startsWith('Driver - Ramesh')).toList();
    expect(otherTabs.length, 2);
    expect(workbook[driverATab]!.any((row) => row.contains('job-a')), isTrue);
  });

  test('rebuilding from the same snapshot is deterministic and idempotent in row structure', () {
    final first = GoogleSheetsSyncService.buildWorkbookData(
      snapshot, accountEmail: 'test@example.com', generatedAt: DateTime(2026, 11, 3),
    );
    final second = GoogleSheetsSyncService.buildWorkbookData(
      snapshot, accountEmail: 'test@example.com', generatedAt: DateTime(2026, 11, 3),
    );
    expect(first.keys.toList(), second.keys.toList());
    expect(first, second);
  });
}
