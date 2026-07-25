import 'package:flutter_test/flutter_test.dart';
import 'package:wolow_lite/main.dart';

void main() {
  testWidgets('App renders with title', (WidgetTester tester) async {
    await tester.pumpWidget(const WolowLiteApp());
    // Just pump once - don't wait for async SharedPreferences
    expect(find.text('WOLOW'), findsOneWidget);
  });
}
