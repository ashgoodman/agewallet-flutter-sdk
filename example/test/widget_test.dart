import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agewallet_flutter_demo/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // In-memory secure storage with nothing saved, so the demo's verification check finishes as "not verified"
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify the app loads with verification required text
    expect(find.text('Age Verification Required'), findsOneWidget);
    expect(find.text('Verify with AgeWallet'), findsOneWidget);
  });
}
