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

    // Fleet folders contain only vehicle master information.
    expect(find.text('Tractor Fleet List'), findsOneWidget);
    expect(find.text('Add Tractor'), findsOneWidget);
    expect(find.textContaining('Recent Tractor Logs'), findsNothing);

    // Work history and the new work-entry action live under Customer Outstanding.
    await tester.tap(find.text('Khata').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ग्राहक बकाया'));
    await tester.pumpAndSettle();
    expect(find.text('Recent Work Records (Today + Previous 2 Days)'), findsOneWidget);
    expect(find.text('New Work Entry'), findsOneWidget);

    await tester.tap(find.text('Worker').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Driver Khata').first);
    await tester.pumpAndSettle();
    expect(find.text('Ramesh Driver Khata'), findsOneWidget);
  });
}
