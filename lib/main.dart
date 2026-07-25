// ============================================================
// WOLOW LITE
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const WolowLiteApp());
}

// ============================================================
// iOS-STYLE COLORS
// ============================================================

class AppColors {
  static const bg = Color(0xFF000000);
  static const card = Color(0xFF1C1C1E);
  static const cardLight = Color(0xFF2C2C2E);
  static const separator = Color(0xFF38383A);
  static const label = Color(0xFFE5E5E5);
  static const secondaryLabel = Color(0xFF8E8E93);
  static const tertiaryLabel = Color(0xFF636366);
  static const blue = Color(0xFF0A84FF);
  static const green = Color(0xFF30D158);
  static const red = Color(0xFFFF453A);
  static const orange = Color(0xFFFF9F0A);
}

// ============================================================
// TOP NOTIFICATION (iOS-style banner)
// ============================================================

void showTopNotification(
  BuildContext context, {
  required String message,
  IconData? icon,
  Color? iconColor,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopNotificationBanner(
      message: message,
      icon: icon,
      iconColor: iconColor,
      duration: duration,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _TopNotificationBanner extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color? iconColor;
  final Duration duration;
  final VoidCallback onDismissed;

  const _TopNotificationBanner({
    required this.message,
    this.icon,
    this.iconColor,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_TopNotificationBanner> createState() => _TopNotificationBannerState();
}

class _TopNotificationBannerState extends State<_TopNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismissed());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 8;
    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              _controller.reverse().then((_) => widget.onDismissed());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: widget.iconColor ?? AppColors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: AppColors.label,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOADING OVERLAY (blur + opacity)
// ============================================================

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          message!,
                          style: const TextStyle(
                            color: AppColors.label,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// APP
// ============================================================

class WolowLiteApp extends StatelessWidget {
  const WolowLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WOLOW',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.dark(
          surface: AppColors.card,
          primary: AppColors.blue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.label,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
          iconTheme: IconThemeData(color: AppColors.blue),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: CircleBorder(),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.blue, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          hintStyle: const TextStyle(
            color: AppColors.tertiaryLabel,
            fontSize: 16,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.separator,
          thickness: 0.5,
          space: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.cardLight,
          contentTextStyle: const TextStyle(
            color: AppColors.label,
            fontSize: 14,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.card,
          elevation: 24,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titleTextStyle: const TextStyle(
            color: AppColors.label,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          contentTextStyle: const TextStyle(
            color: AppColors.secondaryLabel,
            fontSize: 14,
          ),
        ),
      ),
      home: const DeviceListScreen(),
    );
  }
}

// ============================================================
// MODEL
// ============================================================

class Device {
  String id;
  String name;
  String mac;
  String ipAddress;
  String subnetMask;
  int port;
  int agentPort;
  String agentToken;

  Device({
    required this.id,
    required this.name,
    required this.mac,
    required this.ipAddress,
    this.subnetMask = '255.255.255.0',
    this.port = 9,
    this.agentPort = 8220,
    this.agentToken = '',
  });

  bool get hasAgent => agentToken.isNotEmpty;

  /// Derive broadcast address from IP + subnet mask.
  /// e.g. 192.168.1.15 + 255.255.255.0 = 192.168.1.255
  String get broadcastAddress {
    final ip = _ipToUint32(ipAddress);
    final mask = _ipToUint32(subnetMask);
    final broadcast = (ip & mask) | (~mask & 0xFFFFFFFF);
    return _uint32ToIp(broadcast);
  }

  /// Check if this device is on the same subnet as the given IP.
  bool isOnSameSubnet(String otherIp) {
    final ip = _ipToUint32(ipAddress);
    final mask = _ipToUint32(subnetMask);
    final other = _ipToUint32(otherIp);
    return (ip & mask) == (other & mask);
  }

  static int _ipToUint32(String ip) {
    final parts = ip.split('.').map(int.parse).toList();
    if (parts.length != 4) return 0;
    return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
  }

  static String _uint32ToIp(int n) {
    return '${(n >> 24) & 0xFF}.${(n >> 16) & 0xFF}.${(n >> 8) & 0xFF}.${n & 0xFF}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mac': mac,
        'ipAddress': ipAddress,
        'subnetMask': subnetMask,
        'port': port,
        'agentPort': agentPort,
        'agentToken': agentToken,
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        mac: json['mac'] ?? '',
        ipAddress: json['ipAddress'] ?? '',
        subnetMask: json['subnetMask'] ?? '255.255.255.0',
        port: json['port'] ?? 9,
        agentPort: json['agentPort'] ?? 8220,
        agentToken: json['agentToken'] ?? '',
      );
}

// ============================================================
// AGENT STATUS MODEL
// ============================================================

class AgentStatus {
  final String hostname;
  final String platform;
  final String pythonVersion;
  final DateTime fetchedAt;

  AgentStatus({
    required this.hostname,
    required this.platform,
    required this.pythonVersion,
    required this.fetchedAt,
  });
}

// ============================================================
// VALIDATION
// ============================================================

class Validators {
  static final _macRegex = RegExp(
      r'^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$');

  static final _ipv4Regex = RegExp(
      r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

  static bool isValidMac(String mac) => _macRegex.hasMatch(mac);

  static bool isValidIpv4(String ip) {
    final match = _ipv4Regex.firstMatch(ip);
    if (match == null) return false;
    for (var i = 1; i <= 4; i++) {
      final octet = int.tryParse(match.group(i)!) ?? -1;
      if (octet < 0 || octet > 255) return false;
    }
    return true;
  }

  static bool isValidSubnetMask(String mask) {
    if (!isValidIpv4(mask)) return false;
    final n = Device._ipToUint32(mask);
    // Valid subnet masks: not all zeros, not all ones,
    // and all 1-bits must be contiguous on the left side.
    if (n == 0 || n == 0xFFFFFFFF) return false;
    // Check contiguous 1s: invert, add 1, should give a power of 2
    // and that power of 2 should not overlap with the original mask
    final inverted = ~n & 0xFFFFFFFF;
    return (inverted & (inverted + 1)) == 0;
  }

  /// Derive subnet mask from CIDR prefix length (e.g. 24 -> 255.255.255.0)
  static String cidrToMask(int cidr) {
    if (cidr < 0 || cidr > 32) return '255.255.255.0';
    final mask = cidr == 0 ? 0 : (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF;
    return Device._uint32ToIp(mask);
  }

  static bool isValidPort(int port) => const {0, 7, 9}.contains(port);

  /// MAC addresses identify a physical device, regardless of their separator
  /// format or capitalization.
  static bool hasDuplicateMac(Iterable<Device> devices, String mac,
      {String? excludingId}) {
    final normalizedMac = mac.replaceAll(RegExp('[:-]'), '').toLowerCase();
    return devices.any((device) =>
        device.id != excludingId &&
        device.mac.replaceAll(RegExp('[:-]'), '').toLowerCase() == normalizedMac);
  }
}

// ============================================================
// STORAGE
// ============================================================

class StorageService {
  static const _key = 'devices';

  Future<List<Device>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => Device.fromJson(e)).toList();
  }

  Future<void> saveDevices(List<Device> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(devices.map((d) => d.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}

// ============================================================
// WAKE-ON-LAN SERVICE
// ============================================================

class WolService {
  /// Send a Wake-on-LAN magic packet to the device's broadcast address.
  Future<void> wake(Device device) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'Wake-on-LAN is not supported on web — use the native app instead');
    }
    final macBytes = _parseMac(device.mac);
    final packet = _buildMagicPacket(macBytes);
    final broadcast = InternetAddress(device.broadcastAddress);

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      socket.send(packet, broadcast, device.port);
    } finally {
      socket.close();
    }
  }

  List<int> _parseMac(String mac) {
    final cleaned = mac.replaceAll('-', ':').split(':');
    if (cleaned.length != 6) throw FormatException('Invalid MAC: $mac');
    return cleaned.map((hex) => int.parse(hex, radix: 16)).toList();
  }

  List<int> _buildMagicPacket(List<int> macBytes) {
    final header = List<int>.filled(6, 0xFF);
    final body = List<int>.generate(16 * 6, (i) => macBytes[i % 6]);
    return [...header, ...body];
  }
}

// ============================================================
// AGENT SERVICE (TCP/HTTP)
// ============================================================

class AgentService {
  final http.Client _client;

  AgentService({http.Client? client}) : _client = client ?? http.Client();

  /// Send an action command to the WOLOW agent running on the target PC.
  /// Returns (success, message).
  Future<(bool, String)> sendAction(Device device, String action) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/action');

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': action,
              'token': device.agentToken,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          return (true, '$action sent successfully');
        }
        return (false, (body['error'] as String?) ?? 'unknown error');
      } else if (response.statusCode == 401) {
        return (false, 'Authentication failed — check agent token');
      } else {
        return (false, 'Agent returned ${response.statusCode}');
      }
    } on SocketException {
      return (false, 'Cannot connect — is the agent running on port ${device.agentPort}?');
    } on TimeoutException {
      return (false, 'Connection timed out');
    } catch (e) {
      return (false, 'Error: $e');
    }
  }

  /// Test connectivity to the agent (sends a status check).
  Future<(bool, String)> testConnection(Device device) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/status');

    try {
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          final hostname = body['hostname'] as String? ?? 'unknown';
          final platform = body['platform'] as String? ?? 'unknown';
          return (true, 'Connected to $hostname ($platform)');
        }
        return (false, 'Agent returned error');
      }
      return (false, 'Agent returned ${response.statusCode}');
    } on SocketException {
      return (false, 'Cannot connect — is the agent running?');
    } on TimeoutException {
      return (false, 'Connection timed out');
    } catch (e) {
      return (false, 'Error: $e');
    }
  }
}

// ============================================================
// PING SERVICE
// ============================================================

class PingService {
  /// Check if a device is reachable by probing common TCP ports.
  Future<bool> isReachable(String host, {int timeoutMs = 1500}) async {
    if (kIsWeb) return false;
    for (final port in [8220, 22, 80, 443, 5900]) {
      try {
        final socket = await Socket.connect(host, port,
            timeout: Duration(milliseconds: timeoutMs));
        socket.destroy();
        return true;
      } catch (_) {}
    }
    return false;
  }
}

// ============================================================
// DISCOVERY SERVICE (UDP Broadcast)
// ============================================================

class DiscoveredAgent {
  final String ip;
  final String hostname;
  final String platform;
  final String mac;
  final int port;
  final String? token;

  DiscoveredAgent({
    required this.ip,
    required this.hostname,
    required this.platform,
    this.mac = '',
    required this.port,
    this.token,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredAgent && ip == other.ip && port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}

class NetworkHelper {
  /// Check if the device is on a local network (WiFi or Ethernet).
  /// Mobile data IPs are not in private ranges.
  static Future<bool> isOnLocalNetwork() async {
    if (kIsWeb) return true; // Assume local on web (can't check interfaces)
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (_isPrivateIp(addr.address)) return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static bool _isPrivateIp(String ip) {
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length == 4) {
        final second = int.tryParse(parts[1]) ?? 0;
        if (second >= 16 && second <= 31) return true;
      }
    }
    return false;
  }
}

class DiscoveryService {
  static const _discoverPort = 8221;
  static const _magicMessage = 'WOLOW_DISCOVER';

  final http.Client _client;

  DiscoveryService({http.Client? client}) : _client = client ?? http.Client();

  /// Discover agents using multiple methods:
  /// 1. HTTP probe to localhost (same machine)
  /// 2. UDP broadcast (works on some networks)
  /// 3. Direct HTTP probe to the device's IP (if known)
  /// 4. Subnet HTTP scan (fallback for mobile networks where broadcast fails)
  Future<List<DiscoveredAgent>> discover({
    String? deviceIp,
    int timeoutMs = 3000,
  }) async {
    final agents = <DiscoveredAgent>{};

    // Method 0: Probe localhost (same machine testing)
    try {
      final localResult = await _httpProbe('127.0.0.1', timeoutMs: 1500);
      if (localResult != null) {
        _addAgent(agents, localResult);
      }
    } catch (_) {}

    // Method 1: Try UDP broadcast
    try {
      final udpResults = await _udpDiscover(timeoutMs: timeoutMs);
      for (final agent in udpResults) {
        _addAgent(agents, agent);
      }
    } catch (_) {}

    // Method 2: Try direct HTTP probe to the device's IP
    if (deviceIp != null && deviceIp.isNotEmpty) {
      try {
        final httpResult = await _httpProbe(deviceIp, timeoutMs: 2000);
        if (httpResult != null) {
          _addAgent(agents, httpResult);
        }
      } catch (_) {}
    }

    // Method 3: If nothing found, scan the local subnet via HTTP
    if (agents.isEmpty) {
      try {
        final subnetResults = await _subnetScan(timeoutMs: 1500);
        for (final agent in subnetResults) {
          _addAgent(agents, agent);
        }
      } catch (_) {}
    }

    // UDP discovery often finds the PC without a token (older agents). Always
    // follow up with HTTP /status so the token and MAC are populated.
    final enriched = await Future.wait(
      agents.map((agent) => enrichFromStatus(agent)),
    );
    return enriched;
  }

  void _addAgent(Set<DiscoveredAgent> agents, DiscoveredAgent incoming) {
    final existing = agents.where(
      (a) => a.ip == incoming.ip && a.port == incoming.port,
    );
    if (existing.isEmpty) {
      agents.add(incoming);
      return;
    }
    final current = existing.first;
    final currentHasToken =
        current.token != null && current.token!.isNotEmpty;
    final incomingHasToken =
        incoming.token != null && incoming.token!.isNotEmpty;
    if (!currentHasToken && incomingHasToken) {
      agents.remove(current);
      agents.add(incoming);
    }
  }

  /// Fetch token and other details from the agent's HTTP /status endpoint.
  Future<DiscoveredAgent> enrichFromStatus(DiscoveredAgent agent) async {
    if (agent.token != null && agent.token!.isNotEmpty) return agent;
    try {
      final uri = Uri.parse('http://${agent.ip}:${agent.port}/status');
      final response = await _client.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return agent;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['ok'] != true) return agent;

      final token = body['token'] as String?;
      final mac = body['mac'] as String?;
      return DiscoveredAgent(
        ip: agent.ip,
        hostname: body['hostname'] as String? ?? agent.hostname,
        platform: body['platform'] as String? ?? agent.platform,
        mac: mac != null && mac.isNotEmpty ? mac : agent.mac,
        port: agent.port,
        token: token != null && token.isNotEmpty ? token : agent.token,
      );
    } catch (_) {
      return agent;
    }
  }

  /// Repeatedly send WOLOW_DISCOVER and collect responses over a longer period.
  /// Used for first-time setup when the user runs setup.bat while the phone listens.
  Future<List<DiscoveredAgent>> discoverWithRetry({
    int totalTimeoutMs = 30000,
    int intervalMs = 2000,
  }) async {
    final allAgents = <DiscoveredAgent>{};
    final deadline = DateTime.now().add(Duration(milliseconds: totalTimeoutMs));

    while (DateTime.now().isBefore(deadline) && allAgents.isEmpty) {
      try {
        final results = await discover(timeoutMs: intervalMs);
        allAgents.addAll(results);
      } catch (_) {}
      if (allAgents.isEmpty) {
        await Future.delayed(Duration(milliseconds: intervalMs));
      }
    }

    return allAgents.toList();
  }

  /// UDP broadcast discovery
  Future<List<DiscoveredAgent>> _udpDiscover({int timeoutMs = 3000}) async {
    if (kIsWeb) return [];
    final agents = <DiscoveredAgent>[];
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );

    try {
      socket.broadcastEnabled = true;
      final message = utf8.encode(_magicMessage);
      socket.send(message, InternetAddress('255.255.255.255'), _discoverPort);

      // Poll for responses using receive() — avoids race with listen callback
      final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
      while (DateTime.now().isBefore(deadline)) {
        final packet = socket.receive();
        if (packet != null) {
          try {
            final data = utf8.decode(packet.data);
            final json = jsonDecode(data) as Map<String, dynamic>;
            if (json['ok'] == true) {
              agents.add(DiscoveredAgent(
                ip: packet.address.address,
                hostname: json['hostname'] as String? ?? 'unknown',
                platform: json['platform'] as String? ?? 'unknown',
                mac: json['mac'] as String? ?? '',
                port: json['port'] as int? ?? 8220,
                token: json['token'] as String?,
              ));
            }
          } catch (_) {}
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } finally {
      socket.close();
    }

    return agents;
  }

  /// Probe a specific IP for a running agent via HTTP
  Future<DiscoveredAgent?> _httpProbe(String ip, {int timeoutMs = 2000}) async {
    for (final port in [8220]) {
      try {
        final uri = Uri.parse('http://$ip:$port/status');
        final response = await _client.get(uri).timeout(
              Duration(milliseconds: timeoutMs),
            );
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['ok'] == true) {
            return DiscoveredAgent(
              ip: ip,
              hostname: body['hostname'] as String? ?? 'unknown',
              platform: body['platform'] as String? ?? 'unknown',
              mac: body['mac'] as String? ?? '',
              port: port,
              token: body['token'] as String?,
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Scan the local subnet via HTTP probes (fallback when UDP broadcast fails).
  /// Probes all IPs in the /24 subnet in parallel batches.
  Future<List<DiscoveredAgent>> _subnetScan({int timeoutMs = 1500}) async {
    if (kIsWeb) return [];
    final agents = <DiscoveredAgent>[];
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );

    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (!_isPrivateIp(ip)) continue;

        final parts = ip.split('.');
        if (parts.length != 4) continue;
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

        // Probe all IPs in the subnet in parallel batches of 30
        for (var batch = 1; batch <= 254; batch += 30) {
          final futures = <Future<DiscoveredAgent?>>[];
          for (var i = batch; i < batch + 30 && i <= 254; i++) {
            final targetIp = '$subnet.$i';
            futures.add(_httpProbe(targetIp, timeoutMs: timeoutMs));
          }
          final results = await Future.wait(futures);
          for (final result in results) {
            if (result != null) agents.add(result);
          }
          // If we already found agents, no need to scan more subnets
          if (agents.isNotEmpty) return agents;
        }
      }
    }

    return agents;
  }

  static bool _isPrivateIp(String ip) {
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length == 4) {
        final second = int.tryParse(parts[1]) ?? 0;
        if (second >= 16 && second <= 31) return true;
      }
    }
    return false;
  }
}

// ============================================================
// iOS-STYLE SECTION WIDGET
// ============================================================

class IOSSection extends StatelessWidget {
  final String? header;
  final List<Widget> children;

  const IOSSection({super.key, this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                header!,
                style: const TextStyle(
                  color: AppColors.secondaryLabel,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// iOS-STYLE LIST TILE
// ============================================================

class IOSListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showSeparator;

  const IOSListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showSeparator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.label,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: const TextStyle(
                              color: AppColors.secondaryLabel,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        if (showSeparator)
          const Padding(
            padding: EdgeInsets.only(left: 56),
            child: Divider(color: AppColors.separator, height: 0.5),
          ),
      ],
    );
  }
}

// ============================================================
// iOS-STYLE ACTION BUTTON
// ============================================================

class IOSActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const IOSActionButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: onTap != null ? AppColors.label : AppColors.tertiaryLabel,
                    fontSize: 16,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: AppColors.tertiaryLabel,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DEVICE LIST SCREEN
// ============================================================

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _storage = StorageService();
  final _wol = WolService();
  final _ping = PingService();
  final _agent = AgentService();
  List<Device> _devices = [];
  final Map<String, bool> _online = {};
  final Map<String, AgentStatus?> _agentStatus = {};
  final Set<String> _checking = {};
  bool _loading = true;
  String? _wakeTarget;
  Timer? _refreshTimer;

  /// Devices that are booting up after WoL was sent (60 second window)
  final Map<String, DateTime> _starting = {};

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkAll(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final devices = await _storage.loadDevices();
    setState(() {
      _devices = devices;
      _loading = false;
    });
    _checkAll();
  }

  Future<void> _checkAll() async {
    for (final d in _devices) {
      _checkDevice(d);
    }
  }

  Future<void> _checkDevice(Device d) async {
    if (_checking.contains(d.id)) return;
    _checking.add(d.id);
    try {
      final reachable = await _ping.isReachable(d.ipAddress);

      // Check if device is still in "starting" window (60 seconds after WoL)
      final startingAt = _starting[d.id];
      final bool isStarting = startingAt != null &&
          DateTime.now().difference(startingAt).inSeconds < 60;

      if (mounted) {
        setState(() {
          if (reachable) {
            // Device is reachable — clear starting state
            _starting.remove(d.id);
            _online[d.id] = true;
          } else if (isStarting) {
            // Still in starting window — keep as "starting" (not offline)
            _online[d.id] = false;
          } else {
            // Not reachable and not starting — truly offline
            _starting.remove(d.id);
            _online[d.id] = false;
          }
        });
      }

      if (d.hasAgent) {
        final (ok, msg) = await _agent.testConnection(d);
        if (mounted && ok) {
          final match = RegExp(r'Connected to (.+?) \((.+?)\)').firstMatch(msg);
          if (match != null) {
            setState(() {
              _agentStatus[d.id] = AgentStatus(
                hostname: match.group(1)!,
                platform: match.group(2)!,
                pythonVersion: '',
                fetchedAt: DateTime.now(),
              );
              // Agent is online — clear starting state
              _starting.remove(d.id);
              _online[d.id] = true;
            });
          }
        } else if (mounted) {
          setState(() => _agentStatus[d.id] = null);
        }
      }
    } finally {
      _checking.remove(d.id);
    }
  }

  Future<void> _addDevice() async {
    final newDevice = await Navigator.push<Device>(
      context,
      MaterialPageRoute(builder: (_) => AddDeviceScreen(existingDevices: _devices)),
    );
    if (newDevice != null) {
      // Keep a guard here as well as in AddDeviceScreen in case the saved list
      // changes while the add screen is open.
      if (Validators.hasDuplicateMac(_devices, newDevice.mac)) {
        if (mounted) {
          showTopNotification(
            context,
            message: 'This device has already been added',
            icon: Icons.error_outline_rounded,
            iconColor: AppColors.red,
          );
        }
        return;
      }
      setState(() => _devices.add(newDevice));
      await _storage.saveDevices(_devices);
      _checkDevice(newDevice);
    }
  }

  Future<void> _wakeDevice(Device d) async {
    setState(() => _wakeTarget = d.id);
    try {
      await _wol.wake(d);
      // Mark device as "starting" for 60 seconds
      setState(() {
        _starting[d.id] = DateTime.now();
        _online[d.id] = false;
      });
      if (mounted) {
        showTopNotification(
          context,
          message: 'Wake packet sent — PC is starting...',
          icon: Icons.power_settings_new_rounded,
          iconColor: AppColors.orange,
        );
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(
          context,
          message: 'Wake failed: $e',
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.red,
        );
      }
    } finally {
      setState(() => _wakeTarget = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: 60),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Devices',
                    style: TextStyle(
                      color: AppColors.label,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.secondaryLabel,
                      size: 24,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TutorialScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.secondaryLabel,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_devices.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.desktop_mac_rounded,
                      size: 48,
                      color: AppColors.tertiaryLabel,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Devices',
                      style: TextStyle(
                        color: AppColors.secondaryLabel,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap + to add a device',
                      style: TextStyle(
                        color: AppColors.tertiaryLabel,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: IOSSection(
                header: 'YOUR DEVICES',
                children: _devices.asMap().entries.map((entry) {
                  final d = entry.value;
                  final isWaking = _wakeTarget == d.id;
                  final isOnline = _online[d.id];
                  final isStarting = _starting.containsKey(d.id);
                  final isLast = entry.key == _devices.length - 1;

                  return IOSListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isOnline == true
                            ? AppColors.green.withValues(alpha: 0.15)
                            : isStarting
                                ? AppColors.orange.withValues(alpha: 0.15)
                                : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.desktop_mac_rounded,
                        color: isOnline == true
                            ? AppColors.green
                            : isStarting
                                ? AppColors.orange
                                : AppColors.secondaryLabel,
                        size: 20,
                      ),
                    ),
                    title: _agentStatus[d.id] != null
                        ? _agentStatus[d.id]!.hostname
                        : d.name,
                    subtitle: _agentStatus[d.id] != null
                        ? '(${_agentStatus[d.id]!.platform})'
                        : isStarting
                            ? 'Starting...'
                            : d.mac,
                    trailing: isWaking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.blue,
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              Icons.power_settings_new_rounded,
                              color: isOnline == true ? AppColors.blue : AppColors.tertiaryLabel,
                              size: 22,
                            ),
                            onPressed: () => _wakeDevice(d),
                            splashRadius: 22,
                          ),
                    onLongPress: () async {
                      final confirm = await showModalBottomSheet<bool>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _IOSActionSheet(
                          title: 'Delete ${d.name}?',
                          actions: [
                            _IOSAction(
                              label: 'Delete',
                              color: AppColors.red,
                              onTap: () => Navigator.pop(context, true),
                            ),
                            _IOSAction(
                              label: 'Cancel',
                              onTap: () => Navigator.pop(context, false),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        setState(() => _devices.removeWhere((x) => x.id == d.id));
                        await _storage.saveDevices(_devices);
                      }
                    },
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceDetailScreen(device: d),
                        ),
                      );
                      if (mounted) {
                        final devices = await _storage.loadDevices();
                        setState(() => _devices = devices);
                        _checkAll();
                      }
                    },
                    showSeparator: !isLast,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDevice,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

// ============================================================
// iOS ACTION SHEET
// ============================================================

class _IOSActionSheet extends StatelessWidget {
  final String title;
  final List<_IOSAction> actions;

  const _IOSActionSheet({required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.secondaryLabel,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              height: 0.5,
              color: AppColors.separator,
            ),
            ...actions.asMap().entries.map((entry) {
              final a = entry.value;
              final isLast = entry.key == actions.length - 1;
              return Column(
                children: [
                  InkWell(
                    onTap: a.onTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        a.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: a.color ?? AppColors.blue,
                          fontSize: 17,
                          fontWeight: a.color == AppColors.red
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      height: 0.5,
                      color: AppColors.separator,
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _IOSAction {
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _IOSAction({required this.label, this.color, this.onTap});
}

// ============================================================
// ADD DEVICE SCREEN
// ============================================================

class AddDeviceScreen extends StatefulWidget {
  final Device? device;
  final List<Device> existingDevices;

  const AddDeviceScreen({
    super.key,
    this.device,
    this.existingDevices = const [],
  });

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _nameCtrl = TextEditingController();
  final _macCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _subnetCtrl = TextEditingController();
  int _port = 9;
  final _agentPortCtrl = TextEditingController();
  final _agentTokenCtrl = TextEditingController();
  bool _obscureToken = true;
  bool _scanning = false;
  String _scanMessage = 'Scanning network...';

  bool get _isEditing => widget.device != null;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      final d = widget.device!;
      _nameCtrl.text = d.name;
      _macCtrl.text = d.mac;
      _ipCtrl.text = d.ipAddress;
      _subnetCtrl.text = d.subnetMask;
      _port = d.port;
      _agentPortCtrl.text = d.agentPort.toString();
      _agentTokenCtrl.text = d.agentToken;
    } else {
      _subnetCtrl.text = '255.255.255.0';
      _agentPortCtrl.text = '8220';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _macCtrl.dispose();
    _ipCtrl.dispose();
    _subnetCtrl.dispose();
    _agentPortCtrl.dispose();
    _agentTokenCtrl.dispose();
    super.dispose();
  }

  void _save() {
    // Validate required fields
    if (_nameCtrl.text.isEmpty) {
      _showError('Name is required');
      return;
    }
    if (_macCtrl.text.isEmpty) {
      _showError('MAC address is required');
      return;
    }
    if (_ipCtrl.text.isEmpty) {
      _showError('IP address is required');
      return;
    }

    final name = _nameCtrl.text.trim();
    final mac = _macCtrl.text.trim();
    final ip = _ipCtrl.text.trim();
    final subnet = _subnetCtrl.text.trim().isEmpty
        ? '255.255.255.0'
        : _subnetCtrl.text.trim();

    if (!Validators.isValidMac(mac)) {
      _showError('Invalid MAC format — use XX:XX:XX:XX:XX:XX');
      return;
    }

    if (!Validators.isValidIpv4(ip)) {
      _showError('Invalid IP address');
      return;
    }

    if (!Validators.isValidSubnetMask(subnet)) {
      _showError('Invalid subnet mask');
      return;
    }

    if (!Validators.isValidPort(_port)) {
      _showError('WoL port must be 0, 7, or 9');
      return;
    }

    if (Validators.hasDuplicateMac(
      widget.existingDevices,
      mac,
      excludingId: widget.device?.id,
    )) {
      _showError('This device has already been added');
      return;
    }

    final agentPort = int.tryParse(_agentPortCtrl.text) ?? 8220;
    final agentToken = _agentTokenCtrl.text.trim();

    final device = Device(
      id: _isEditing
          ? widget.device!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      mac: mac,
      ipAddress: ip,
      subnetMask: subnet,
      port: _port,
      agentPort: agentPort,
      agentToken: agentToken,
    );
    Navigator.pop(context, device);
  }

  Future<void> _deleteDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Delete ${widget.device!.name}?',
          style: const TextStyle(color: AppColors.label),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: AppColors.secondaryLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryLabel)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final storage = StorageService();
      final devices = await storage.loadDevices();
      devices.removeWhere((d) => d.id == widget.device!.id);
      await storage.saveDevices(devices);
      // Return null to signal deletion — DeviceDetailScreen will detect it
      if (mounted) Navigator.pop(context, null);
    }
  }

  void _showError(String msg) {
    showTopNotification(
      context,
      message: msg,
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.red,
    );
  }

  void _applyDiscoveredAgent(DiscoveredAgent agent) {
    setState(() {
      _nameCtrl.text = agent.hostname;
      _ipCtrl.text = agent.ip;
      _subnetCtrl.text = '255.255.255.0';
      _port = 9;
      _agentPortCtrl.text = agent.port.toString();
      if (agent.token != null && agent.token!.isNotEmpty) {
        _agentTokenCtrl.text = agent.token!;
      }
      if (agent.mac.isNotEmpty) {
        _macCtrl.text = agent.mac;
      }
    });
  }

  Future<DiscoveredAgent?> _pickAgent(List<DiscoveredAgent> agents) async {
    if (agents.length == 1) return agents.first;
    return showModalBottomSheet<DiscoveredAgent>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AgentPickerSheet(agents: agents),
    );
  }

  Future<void> _scanForAgent() async {
    setState(() {
      _scanning = true;
      _scanMessage = 'Scanning network...';
    });
    try {
      // Check if on local network first — scan won't work on mobile data
      final onLocal = await NetworkHelper.isOnLocalNetwork();
      if (!onLocal && mounted) {
        showTopNotification(
          context,
          message: 'Not on a local network — connect to the same WiFi as your PC',
          icon: Icons.wifi_off_rounded,
          iconColor: AppColors.orange,
        );
        setState(() => _scanning = false);
        return;
      }

      final discovery = DiscoveryService();

      // Phase 1: Quick active scan (4 seconds)
      var agents = await discovery.discover(timeoutMs: 4000);

      // Phase 2: If nothing found, enter listening mode
      // Keep sending WOLOW_DISCOVER every 2 seconds for up to 30 seconds
      // This lets the user run setup.bat while the phone listens
      if (agents.isEmpty && mounted) {
        setState(() => _scanMessage = 'Listening for agent...\nRun setup.bat on your PC now');
        agents = await discovery.discoverWithRetry(
          totalTimeoutMs: 30000,
          intervalMs: 2000,
        );
      }

      if (agents.isEmpty) {
        if (mounted) {
          showTopNotification(
            context,
            message: 'No agent found. Make sure setup.bat was run and the PC is on the same WiFi.',
            icon: Icons.search_off_rounded,
            iconColor: AppColors.orange,
          );
        }
        return;
      }

      if (!mounted) return;

      final selected = await _pickAgent(agents);

      if (selected != null && mounted) {
        final agent = await discovery.enrichFromStatus(selected);
        _applyDiscoveredAgent(agent);

        if (!mounted) return;

        if (agent.token == null || agent.token!.isEmpty) {
          showTopNotification(
            context,
            message:
                'PC found but token missing — rerun setup.bat on your PC, then scan again',
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.orange,
          );
        } else if (agent.mac.isEmpty) {
          showTopNotification(
            context,
            message: 'PC found — tap Add to save',
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppColors.green,
          );
        } else {
          showTopNotification(
            context,
            message: 'All fields filled — tap Add to save',
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppColors.green,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(
          context,
          message: 'Scan failed: $e',
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final broadcast = Validators.isValidIpv4(_ipCtrl.text) &&
            Validators.isValidSubnetMask(
                _subnetCtrl.text.isEmpty ? '255.255.255.0' : _subnetCtrl.text)
        ? Device(
            id: '',
            name: '',
            mac: '00:00:00:00:00:00',
            ipAddress: _ipCtrl.text.trim(),
            subnetMask:
                _subnetCtrl.text.trim().isEmpty ? '255.255.255.0' : _subnetCtrl.text.trim(),
          ).broadcastAddress
        : null;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.blue, fontSize: 16),
          ),
        ),
        title: Text(_isEditing ? 'Edit Device' : 'Add Device'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              _isEditing ? 'Save' : 'Add',
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
            // Let existing devices refresh their connection details too.
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _scanning ? null : _scanForAgent,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.radar_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Scan Network',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            IOSSection(
              header: 'DEVICE INFO',
              children: [
                _buildField(
                  hint: 'Name',
                  description: 'Auto-filled when you scan for the agent.',
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                ),
                _buildField(
                  hint: 'MAC Address',
                  description: 'Auto-filled when you scan for the agent.',
                  controller: _macCtrl,
                  textCapitalization: TextCapitalization.characters,
                  showSeparator: false,
                ),
              ],
            ),
            IOSSection(
              header: 'NETWORK',
              children: [
                _buildField(
                  hint: 'IP Address',
                  description: 'Auto-filled when you scan for the agent.',
                  controller: _ipCtrl,
                  keyboardType: TextInputType.number,
                ),
                _buildField(
                  hint: 'Subnet Mask',
                  description: 'Usually 255.255.255.0. Auto-filled on scan.',
                  controller: _subnetCtrl,
                  keyboardType: TextInputType.number,
                ),
                // Broadcast address preview
                if (broadcast != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 60,
                          child: Text(
                            'WoL',
                            style: TextStyle(
                              color: AppColors.secondaryLabel,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          broadcast,
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '(auto-derived)',
                          style: TextStyle(
                            color: AppColors.tertiaryLabel,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (broadcast != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Divider(color: AppColors.separator, height: 0.5),
                  ),
                // Port selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WoL Port',
                        style: TextStyle(
                          color: AppColors.tertiaryLabel,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [0, 7, 9].map((p) {
                          final isSelected = _port == p;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$p'),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _port = p),
                              selectedColor: AppColors.blue,
                              backgroundColor: AppColors.cardLight,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.label,
                                fontSize: 14,
                              ),
                              side: BorderSide.none,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Divider(color: AppColors.separator, height: 0.5),
                ),
                _buildField(
                  hint: 'Agent Port',
                  description: 'Auto-filled when you scan for the agent.',
                  controller: _agentPortCtrl,
                  keyboardType: TextInputType.number,
                ),
                _buildField(
                  hint: 'Agent Token',
                  description: 'Auto-filled when you scan for the agent.',
                  controller: _agentTokenCtrl,
                  obscureText: _obscureToken,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscureToken = !_obscureToken),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        _obscureToken
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.secondaryLabel,
                        size: 20,
                      ),
                    ),
                  ),
                  showSeparator: false,
                ),
              ],
            ),
            // Delete button (edit mode only)
            if (_isEditing)
              IOSSection(
                header: null,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _deleteDevice,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Delete Device',
                          style: TextStyle(
                            color: AppColors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        ),
        if (_scanning)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _scanMessage,
                        style: const TextStyle(
                          color: AppColors.label,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    );
  }

  Widget _buildField({
    required String hint,
    required String description,
    required TextEditingController controller,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool showSeparator = true,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  obscureText: obscureText,
                  style: const TextStyle(
                    color: AppColors.label,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (suffix != null) suffix,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              description,
              style: const TextStyle(
                color: AppColors.tertiaryLabel,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ),
        if (showSeparator)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(color: AppColors.separator, height: 0.5),
          ),
      ],
    );
  }
}

// ============================================================
// DEVICE DETAIL SCREEN
// ============================================================

class DeviceDetailScreen extends StatefulWidget {
  final Device device;
  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final _agent = AgentService();
  final _ping = PingService();
  final _storage = StorageService();
  bool _busy = false;
  bool _scanning = false;
  static const _scanMessage = 'Scanning network...';
  bool? _online;
  AgentStatus? _agentStatus;
  Timer? _refreshTimer;
  late Device _device;
  bool _checking = false;

  /// When WoL was sent (for "starting" state)
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _checkOnline();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkOnline(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkOnline() async {
    if (_checking) return;
    _checking = true;
    try {
      final reachable = await _ping.isReachable(_device.ipAddress);

      // Check if still in "starting" window (60 seconds after WoL)
      final bool isStarting = _startedAt != null &&
          DateTime.now().difference(_startedAt!).inSeconds < 60;

      if (mounted) {
        setState(() {
          if (reachable) {
            // Device is reachable — clear starting state
            _startedAt = null;
            _online = true;
          } else if (isStarting) {
            // Still in starting window
            _online = false;
          } else {
            // Not reachable and not starting — truly offline
            _startedAt = null;
            _online = false;
          }
        });
      }

      if (_device.hasAgent) {
        final (ok, msg) = await _agent.testConnection(_device);
        if (mounted) {
          if (ok) {
            final match = RegExp(r'Connected to (.+?) \((.+?)\)').firstMatch(msg);
            if (match != null) {
              setState(() {
                _agentStatus = AgentStatus(
                  hostname: match.group(1)!,
                  platform: match.group(2)!,
                  pythonVersion: '',
                  fetchedAt: DateTime.now(),
                );
                // Agent is online — clear starting state
                _startedAt = null;
                _online = true;
              });
            }
          } else {
            setState(() => _agentStatus = null);
          }
        }
      }
    } finally {
      _checking = false;
    }
  }

  /// Mask the middle of a value with ****, keeping first and last 3 chars.
  static String _maskValue(String input) {
    if (input.length <= 6) return '****';
    return '${input.substring(0, 3)}****${input.substring(input.length - 3)}';
  }

  Future<void> _handleAgent(String action) async {
    setState(() => _busy = true);
    final (ok, msg) = await _agent.sendAction(_device, action);
    setState(() {
      _busy = false;
      // Mark as starting for reboot/shutdown actions
      if (ok && (action == 'reboot' || action == 'shutdown')) {
        _startedAt = DateTime.now();
        _online = false;
      }
    });
    if (mounted) {
      showTopNotification(
        context,
        message: ok ? msg : 'Failed: $msg',
        icon: ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
        iconColor: ok ? AppColors.green : AppColors.red,
      );
    }
    _checkOnline();
  }

  Future<void> _scanForAgent() async {
    setState(() {
      _busy = true;
      _scanning = true;
    });

    try {
      // Check if on local network first
      final onLocal = await NetworkHelper.isOnLocalNetwork();
      if (!onLocal && mounted) {
        setState(() {
          _busy = false;
          _scanning = false;
        });
        showTopNotification(
          context,
          message: 'Not on a local network — connect to the same WiFi as your PC',
          icon: Icons.wifi_off_rounded,
          iconColor: AppColors.orange,
        );
        return;
      }

      final discovery = DiscoveryService();
      final agents = await discovery.discover(
        deviceIp: _device.ipAddress,
        timeoutMs: 4000,
      );

      if (agents.isEmpty) {
        setState(() {
          _busy = false;
          _scanning = false;
        });
        if (mounted) {
          showTopNotification(
            context,
            message: 'Agent not found — is it running?',
            icon: Icons.search_off_rounded,
            iconColor: AppColors.orange,
          );
        }
        return;
      }

      // Filter to agents on the same subnet
      final sameSubnet = agents.where((a) => _device.isOnSameSubnet(a.ip)).toList();
      final list = sameSubnet.isNotEmpty ? sameSubnet : agents;

      if (!mounted) return;

      // Show picker dialog
      final selected = await showModalBottomSheet<DiscoveredAgent>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _AgentPickerSheet(agents: list),
      );

      if (selected != null && mounted) {
        final agent = await discovery.enrichFromStatus(selected);
        // Update device with discovered agent info
        final updated = Device(
          id: _device.id,
          name: agent.hostname,
          mac: agent.mac.isNotEmpty ? agent.mac : _device.mac,
          ipAddress: agent.ip,
          subnetMask: _device.subnetMask,
          port: _device.port,
          agentPort: agent.port,
          agentToken: agent.token ?? _device.agentToken,
        );
        setState(() {
          _device = updated;
          _busy = false;
          _scanning = false;
        });

        // Save
        final devices = await _storage.loadDevices();
        final idx = devices.indexWhere((d) => d.id == updated.id);
        if (idx != -1) {
          devices[idx] = updated;
          await _storage.saveDevices(devices);
        }

        if (mounted) {
          if (updated.agentToken.isEmpty) {
            showTopNotification(
              context,
              message:
                  'PC found but token missing — rerun setup.bat on your PC, then scan again',
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.orange,
            );
          } else {
            showTopNotification(
              context,
              message: 'Connected to ${agent.hostname} (${agent.platform})',
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppColors.green,
            );
          }
        }
      } else {
        setState(() {
          _busy = false;
          _scanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _scanning = false;
      });
      if (mounted) {
        showTopNotification(
          context,
          message: 'Scan failed: $e',
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.red,
        );
      }
    }
  }

  Future<void> _editDevice() async {
    final existingDevices = await _storage.loadDevices();
    final updated = await Navigator.push<Device>(
      context,
      MaterialPageRoute(
        builder: (_) => AddDeviceScreen(
          device: _device,
          existingDevices: existingDevices,
        ),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _device = updated);
      final devices = await _storage.loadDevices();
      final idx = devices.indexWhere((d) => d.id == updated.id);
      if (idx != -1) {
        devices[idx] = updated;
        await _storage.saveDevices(devices);
      }
      _checkOnline();
    } else {
      // Device might have been deleted — check storage
      final devices = await _storage.loadDevices();
      final exists = devices.any((d) => d.id == _device.id);
      if (!exists && mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _device;
    return Scaffold(
      appBar: AppBar(
        title: Text(d.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            onPressed: _editDevice,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
            // Status badge
            IOSSection(
              children: [
                IOSListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _online == true
                          ? AppColors.green.withValues(alpha: 0.15)
                          : _startedAt != null &&
                                  DateTime.now().difference(_startedAt!).inSeconds < 60
                              ? AppColors.orange.withValues(alpha: 0.15)
                              : _online == false
                                  ? AppColors.red.withValues(alpha: 0.15)
                                  : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _online == true
                          ? Icons.check_circle_rounded
                          : _startedAt != null &&
                                  DateTime.now().difference(_startedAt!).inSeconds < 60
                              ? Icons.hourglass_top_rounded
                              : _online == false
                                  ? Icons.cancel_rounded
                                  : Icons.help_outline_rounded,
                      color: _online == true
                          ? AppColors.green
                          : _startedAt != null &&
                                  DateTime.now().difference(_startedAt!).inSeconds < 60
                              ? AppColors.orange
                              : _online == false
                                  ? AppColors.red
                                  : AppColors.secondaryLabel,
                      size: 20,
                    ),
                  ),
                  title: _online == true
                      ? 'Online'
                      : _startedAt != null &&
                              DateTime.now().difference(_startedAt!).inSeconds < 60
                          ? 'Starting...'
                          : _online == false
                              ? 'Offline'
                              : 'Checking...',
                  subtitle: _agentStatus != null
                      ? '${_agentStatus!.hostname} (${_agentStatus!.platform}) - ${d.ipAddress}'
                      : d.ipAddress,
                  showSeparator: false,
                ),
              ],
            ),

            // Actions
            if (d.hasAgent)
              IOSSection(
                header: 'ACTIONS',
                children: [
                  IOSActionButton(
                    icon: Icons.restart_alt_rounded,
                    iconColor: AppColors.orange,
                    label: 'Reboot',
                    onTap: _busy ? null : () => _handleAgent('reboot'),
                  ),
                  IOSActionButton(
                    icon: Icons.power_settings_new_rounded,
                    iconColor: AppColors.red,
                    label: 'Shutdown',
                    onTap: _busy ? null : () => _handleAgent('shutdown'),
                  ),
                  IOSActionButton(
                    icon: Icons.bedtime_rounded,
                    iconColor: AppColors.blue,
                    label: 'Sleep',
                    onTap: _busy ? null : () => _handleAgent('sleep'),
                  ),
                  IOSActionButton(
                    icon: Icons.lock_rounded,
                    iconColor: AppColors.secondaryLabel,
                    label: 'Lock',
                    onTap: _busy ? null : () => _handleAgent('lock'),
                  ),
                ],
              ),

            // Device info
            IOSSection(
              header: 'DEVICE INFO',
              children: [
                _InfoTile(label: 'MAC', value: _maskValue(d.mac)),
                _InfoTile(label: 'IP', value: _maskValue(d.ipAddress)),
                _InfoTile(label: 'Subnet', value: _maskValue(d.subnetMask)),
                _InfoTile(
                  label: 'WoL',
                  value: _maskValue('${d.broadcastAddress}:${d.port}'),
                ),
                if (d.hasAgent) ...[
                  _InfoTile(
                    label: 'Agent',
                    value: _maskValue('${d.ipAddress}:${d.agentPort}'),
                  ),
                  _InfoTile(
                    label: 'Token',
                    value: _maskValue(d.agentToken),
                    showSeparator: _agentStatus == null,
                  ),
                ],
                if (d.hasAgent && _agentStatus != null) ...[
                  _InfoTile(
                    label: 'Host',
                    value: _agentStatus!.hostname,
                  ),
                  _InfoTile(
                    label: 'OS',
                    value: _agentStatus!.platform,
                    showSeparator: false,
                  ),
                ],
                if (!d.hasAgent)
                  const _InfoTile(
                    label: 'Agent',
                    value: '(not configured)',
                    showSeparator: false,
                  ),
              ],
            ),

            // Agent setup hint (when no token configured)
            if (!d.hasAgent)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.orange, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Agent not configured. Tap Edit to add the token for remote control.',
                          style: TextStyle(
                            color: AppColors.orange,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        ),
        if (_scanning)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _scanMessage,
                        style: const TextStyle(
                          color: AppColors.label,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    );
  }
}

// ============================================================
// iOS INFO TILE
// ============================================================

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool showSeparator;

  const _InfoTile({
    required this.label,
    required this.value,
    this.showSeparator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.secondaryLabel,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.label,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showSeparator)
          const Padding(
            padding: EdgeInsets.only(left: 76),
            child: Divider(color: AppColors.separator, height: 0.5),
          ),
      ],
    );
  }
}

// ============================================================
// AGENT PICKER SHEET
// ============================================================

class _AgentPickerSheet extends StatelessWidget {
  final List<DiscoveredAgent> agents;

  const _AgentPickerSheet({required this.agents});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Agent',
                style: TextStyle(
                  color: AppColors.secondaryLabel,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Divider(color: AppColors.separator, height: 0.5),
            ...agents.asMap().entries.map((entry) {
              final a = entry.value;
              final isLast = entry.key == agents.length - 1;
              return Column(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context, a),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.computer_rounded,
                              color: AppColors.green,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.hostname,
                                  style: const TextStyle(
                                    color: AppColors.label,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${a.ip}:${a.port} (${a.platform})',
                                  style: const TextStyle(
                                    color: AppColors.secondaryLabel,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.tertiaryLabel,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                        color: AppColors.separator,
                        height: 0.5,
                        indent: 60),
                ],
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TUTORIAL SCREEN
// ============================================================

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Guide'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              header: 'GETTING STARTED',
              steps: [
                _Step(
                  number: '1',
                  title: 'Run setup on your PC',
                  detail:
                      'Right-click setup.bat and "Run as administrator". That\'s it — it enables everything.',
                ),
                _Step(
                  number: '2',
                  title: 'Add your PC in the app',
                  detail:
                      'Tap +, then "Scan Network". Your PC will appear — select it and tap Add.',
                ),
              ],
            ),

            const SizedBox(height: 8),

            _buildSection(
              header: 'TIPS',
              steps: [
                _Step(
                  number: '\u2022',
                  title: 'Same network',
                  detail:
                      'Phone and PC must be on the same WiFi/LAN.',
                ),
                _Step(
                  number: '\u2022',
                  title: 'Windows setup',
                  detail:
                      'setup.bat handles WinRM, firewall, and the agent. Run it once as admin.',
                ),
                _Step(
                  number: '\u2022',
                  title: 'Mac / Linux',
                  detail:
                      'Run: sudo bash setup.sh — same thing, different button.',
                ),
                _Step(
                  number: '\u2022',
                  title: 'Token',
                  detail:
                      'The setup prints a token. The app fills it automatically on scan.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String header,
    required List<_Step> steps,
  }) {
    return IOSSection(
      header: header,
      children: steps.asMap().entries.map((entry) {
        final step = entry.value;
        final isLast = entry.key == steps.length - 1;
        return _StepTile(step: step, showSeparator: !isLast);
      }).toList(),
    );
  }
}

class _Step {
  final String number;
  final String title;
  final String detail;

  const _Step({
    required this.number,
    required this.title,
    required this.detail,
  });
}

class _StepTile extends StatelessWidget {
  final _Step step;
  final bool showSeparator;

  const _StepTile({required this.step, this.showSeparator = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    step.number,
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        color: AppColors.label,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.detail,
                      style: const TextStyle(
                        color: AppColors.secondaryLabel,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showSeparator)
          const Padding(
            padding: EdgeInsets.only(left: 54),
            child: Divider(color: AppColors.separator, height: 0.5),
          ),
      ],
    );
  }
}
