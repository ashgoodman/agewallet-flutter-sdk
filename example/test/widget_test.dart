import 'package:flutter_test/flutter_test.dart';
import 'package:agewallet_flutter_demo/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify the app loads with verification required text
    expect(find.text('Age Verification Required'), findsOneWidget);
    expect(find.text('Verify with AgeWallet'), findsOneWidget);
  });
}
