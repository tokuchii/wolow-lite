import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wolow_lite/main.dart';

void main() {
  test('detects duplicate MAC addresses regardless of format or case', () {
    final devices = [
      Device(
        id: 'desktop',
        name: 'Desktop',
        mac: 'AA:BB:CC:DD:EE:FF',
        ipAddress: '192.168.1.10',
      ),
    ];

    expect(Validators.hasDuplicateMac(devices, 'aa-bb-cc-dd-ee-ff'), isTrue);
    expect(
      Validators.hasDuplicateMac(
        devices,
        'AA:BB:CC:DD:EE:FF',
        excludingId: 'desktop',
      ),
      isFalse,
    );
    expect(Validators.hasDuplicateMac(devices, '00:11:22:33:44:55'), isFalse);
  });

  testWidgets('App theme uses dark brightness', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(body: Text('WOLOW')),
      ),
    );
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.brightness, Brightness.dark);
    expect(find.text('WOLOW'), findsOneWidget);
  });

  testWidgets('Add device screen does not start scanning automatically', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const AddDeviceScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Scanning network...'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
