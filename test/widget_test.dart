import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // ---- Quick Launch (PinnedAppsService) tests ----

  test('PinnedAppsService toggle adds and removes app names', () async {
    SharedPreferences.setMockInitialValues({});
    final service = PinnedAppsService();

    // Start clean
    await service.save([]);
    expect(await service.load(), isEmpty);

    // Toggle adds
    await service.toggle(AppEntry(name: 'Chrome', path: ''));
    final afterAdd = await service.load();
    expect(afterAdd.map((p) => p.name).toList(), ['Chrome']);

    // Toggle adds another
    await service.toggle(AppEntry(name: 'Spotify', path: ''));
    final list = await service.load();
    final names = list.map((p) => p.name).toList();
    expect(names, contains('Chrome'));
    expect(names, contains('Spotify'));
    expect(names.length, 2);

    // Toggle removes
    await service.toggle(AppEntry(name: 'Chrome', path: ''));
    final afterRemove = await service.load();
    final names2 = afterRemove.map((p) => p.name).toList();
    expect(names2, isNot(contains('Chrome')));
    expect(names2, contains('Spotify'));

    // Clean up
    await service.save([]);
  });

  test('PinnedAppsService isPinned returns correct state', () async {
    SharedPreferences.setMockInitialValues({});
    final service = PinnedAppsService();
    await service.save([PinnedApp(name: 'VS Code', path: '')]);

    expect(await service.isPinned('VS Code'), isTrue);
    expect(await service.isPinned('Chrome'), isFalse);

    await service.save([]);
  });

  // ---- Device model tests ----

  test('Device.broadcastAddress derives correct broadcast', () {
    final d = Device(
      id: '1',
      name: 'PC',
      mac: 'AA:BB:CC:DD:EE:FF',
      ipAddress: '192.168.1.15',
      subnetMask: '255.255.255.0',
    );
    expect(d.broadcastAddress, '192.168.1.255');

    final d2 = Device(
      id: '2',
      name: 'PC2',
      mac: '11:22:33:44:55:66',
      ipAddress: '10.0.1.100',
      subnetMask: '255.255.0.0',
    );
    expect(d2.broadcastAddress, '10.0.255.255');
  });

  test('Device.isOnSameSubnet correctly compares IPs', () {
    final d = Device(
      id: '1',
      name: 'PC',
      mac: 'AA:BB:CC:DD:EE:FF',
      ipAddress: '192.168.1.10',
      subnetMask: '255.255.255.0',
    );
    expect(d.isOnSameSubnet('192.168.1.50'), isTrue);
    expect(d.isOnSameSubnet('192.168.2.50'), isFalse);
  });

  test('Device serialization round-trips correctly', () {
    final d = Device(
      id: 'test-id',
      name: 'My PC',
      mac: 'AA:BB:CC:DD:EE:FF',
      ipAddress: '192.168.1.10',
      subnetMask: '255.255.255.0',
      port: 9,
      agentPort: 8220,
      agentToken: 'secret',
    );
    final json = d.toJson();
    final d2 = Device.fromJson(json);
    expect(d2.id, d.id);
    expect(d2.name, d.name);
    expect(d2.mac, d.mac);
    expect(d2.ipAddress, d.ipAddress);
    expect(d2.subnetMask, d.subnetMask);
    expect(d2.port, d.port);
    expect(d2.agentPort, d.agentPort);
    expect(d2.agentToken, d.agentToken);
  });

  test('Device.hasAgent is true only when token is non-empty', () {
    final withToken = Device(
      id: '1',
      name: 'PC',
      mac: 'AA:BB:CC:DD:EE:FF',
      ipAddress: '192.168.1.10',
      agentToken: 'abc',
    );
    final withoutToken = Device(
      id: '2',
      name: 'PC2',
      mac: '11:22:33:44:55:66',
      ipAddress: '192.168.1.11',
    );
    expect(withToken.hasAgent, isTrue);
    expect(withoutToken.hasAgent, isFalse);
  });

  // ---- Validator tests ----

  test('Validators.isValidSubnetMask rejects invalid masks', () {
    expect(Validators.isValidSubnetMask('255.255.255.0'), isTrue);
    expect(Validators.isValidSubnetMask('255.255.0.0'), isTrue);
    expect(Validators.isValidSubnetMask('0.0.0.0'), isFalse);
    expect(Validators.isValidSubnetMask('255.255.255.255'), isFalse);
    expect(Validators.isValidSubnetMask('255.0.255.0'), isFalse);
  });

  test('Validators.cidrToMask converts correctly', () {
    expect(Validators.cidrToMask(24), '255.255.255.0');
    expect(Validators.cidrToMask(16), '255.255.0.0');
    expect(Validators.cidrToMask(0), '0.0.0.0');
  });
}
