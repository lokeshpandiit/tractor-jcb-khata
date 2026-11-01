import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tractor_jcb_khata/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LxH ONE opens the five main sections', (tester) async {
    await tester.pumpWidget(const FleetKhataApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue Without Google for Now'));
    await tester.pumpAndSettle();

    expect(find.text('LxH ONE'), findsOneWidget);
    expect(find.text('Tractor'), findsOneWidget);
    expect(find.text('JCB'), findsOneWidget);
    expect(find.text('Worker'), findsOneWidget);
    expect(find.text('Parties'), findsOneWidget);
    expect(find.text('Khata'), findsOneWidget);
    await tester.tap(find.text('Worker').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Driver Khata').first);
    await tester.pumpAndSettle();
    expect(find.text('Ramesh Driver Khata'), findsOneWidget);
    expect(find.text('Recent Transactions (Last 3 Days)'), findsOneWidget);
  });
}
