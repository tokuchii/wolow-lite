// ============================================================
// WOLOW LITE
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  static const elevatedBg = Color(0xFF1C1C1E);
  static const card = Color(0xFF1C1C1E);
  static const cardLight = Color(0xFF2C2C2E);
  static const separator = Color(0xFF38383A);
  static const label = Color(0xFFFFFFFF);
  static const secondaryLabel = Color(0xFF98989D);
  static const tertiaryLabel = Color(0xFF636366);
  static const quaternaryLabel = Color(0xFF48484A);
  static const blue = Color(0xFF0A84FF);
  static const green = Color(0xFF30D158);
  static const red = Color(0xFFFF453A);
  static const orange = Color(0xFFFF9F0A);
  static const teal = Color(0xFF64D2FF);
  static const indigo = Color(0xFF5E5CE6);
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
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: AppColors.label,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
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
          centerTitle: true,
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
          backgroundColor: AppColors.elevatedBg,
          elevation: 24,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          titleTextStyle: const TextStyle(
            color: AppColors.label,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          contentTextStyle: const TextStyle(
            color: AppColors.secondaryLabel,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
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
  static const _deviceIdKey = 'app_device_id';

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

  /// Returns a persistent unique ID for this app instance.
  /// On Android, uses the hardware ANDROID_ID which survives app reinstalls.
  /// Falls back to a random ID on other platforms.
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    // Try to get a hardware-based ID on Android
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final androidId = androidInfo.id; // ANDROID_ID - persists across installs
        if (androidId.isNotEmpty) {
          final hwId = 'android_$androidId';
          await prefs.setString(_deviceIdKey, hwId);
          return hwId;
        }
      } catch (_) {}
    }

    // Fallback: random ID (also used on iOS, web, desktop)
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      final rng = Random.secure();
      id = List.generate(24, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[rng.nextInt(36)]).join();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }
}

// ============================================================
// AUDIO OUTPUT SERVICE (HTTP to PC Agent)
// ============================================================

class AudioOutputService {
  final http.Client _client;

  AudioOutputService({http.Client? client}) : _client = client ?? http.Client();

  /// Get list of available audio output devices on the PC.
  Future<List<AudioDevice>> getDevices(Device device) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/audio-devices');
    try {
      final response = await _client
          .get(uri, headers: {'X-Token': device.agentToken})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final currentId = body['current'] as String? ?? '';
        final devices = (body['devices'] as List?)
                ?.map((e) => AudioDevice.fromMap(Map<String, dynamic>.from(e as Map), currentId: currentId))
                .toList() ??
            [];
        return devices;
      }
    } catch (_) {}
    return [];
  }

  /// Switch the PC's default audio output device.
  /// Returns (success, error message).
  Future<(bool, String)> setActiveDevice(Device device, String deviceId) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/audio-device');
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Token': device.agentToken,
            },
            body: jsonEncode({'device_id': deviceId, 'token': device.agentToken}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) return (true, '');
        return (false, body['error'] as String? ?? 'switch failed');
      }
    } catch (_) {}
    return (false, 'cannot reach PC agent');
  }

  /// Get current master volume (0-100) from the PC.
  Future<int> getVolume(Device device) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/volume');
    try {
      final response = await _client
          .get(uri, headers: {'X-Token': device.agentToken})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['volume'] as int? ?? 50;
      }
    } catch (_) {}
    return 50;
  }

  /// Set master volume (0-100) on the PC.
  Future<bool> setVolume(Device device, int level) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/volume');
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Token': device.agentToken,
            },
            body: jsonEncode({'level': level, 'token': device.agentToken}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['ok'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// Set mute state on the PC. Returns true on success.
  Future<bool> setMute(Device device, bool muted) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/volume');
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Token': device.agentToken,
            },
            body: jsonEncode({'muted': muted, 'token': device.agentToken}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['ok'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// Check if audio is muted on the PC.
  Future<bool> isMuted(Device device) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/volume');
    try {
      final response = await _client
          .get(uri, headers: {'X-Token': device.agentToken})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['muted'] == true || body['muted'] == 1;
      }
    } catch (_) {}
    return false;
  }
}

class AudioDevice {
  final String id;
  final String name;
  final String type; // speaker, headphones, bluetooth, hdmi, usb
  final bool isCurrentlySelected;

  const AudioDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isCurrentlySelected = false,
  });

  factory AudioDevice.fromMap(Map<String, dynamic> map, {String? currentId}) {
    final id = map['id'] as String? ?? '';
    final name = map['name'] as String? ?? 'Unknown';
    return AudioDevice(
      id: id,
      name: name,
      type: _inferDeviceType(name),
      isCurrentlySelected: map['is_default'] == true || id == currentId,
    );
  }

  static String _inferDeviceType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('headphone') || lower.contains('headset') ||
        lower.contains('earphone') || lower.contains('earbud')) {
      return 'headphones';
    }
    if (lower.contains('bluetooth') || lower.contains('bt ')) return 'bluetooth';
    if (lower.contains('hdmi') || lower.contains('displayport')) return 'hdmi';
    if (lower.contains('usb')) return 'usb';
    return 'speaker';
  }
}

// ============================================================
// SYSTEM STATS SERVICE
// ============================================================

class SystemStats {
  final double cpuPercent;
  final double ramTotalGb;
  final double ramUsedGb;
  final double ramPercent;
  final double diskTotalGb;
  final double diskUsedGb;
  final double diskPercent;

  const SystemStats({
    required this.cpuPercent,
    required this.ramTotalGb,
    required this.ramUsedGb,
    required this.ramPercent,
    required this.diskTotalGb,
    required this.diskUsedGb,
    required this.diskPercent,
  });

  factory SystemStats.fromJson(Map<String, dynamic> json) {
    final ram = json['ram'] as Map<String, dynamic>? ?? {};
    final disk = json['disk'] as Map<String, dynamic>? ?? {};
    return SystemStats(
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0,
      ramTotalGb: (ram['total_gb'] as num?)?.toDouble() ?? 0,
      ramUsedGb: (ram['used_gb'] as num?)?.toDouble() ?? 0,
      ramPercent: (ram['percent'] as num?)?.toDouble() ?? 0,
      diskTotalGb: (disk['total_gb'] as num?)?.toDouble() ?? 0,
      diskUsedGb: (disk['used_gb'] as num?)?.toDouble() ?? 0,
      diskPercent: (disk['percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SystemStatsService {
  final http.Client _client;
  SystemStatsService({http.Client? client}) : _client = client ?? http.Client();

  Future<SystemStats?> getStats(Device device) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/stats');
    try {
      final response = await _client
          .get(uri, headers: {'X-Token': device.agentToken})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) return SystemStats.fromJson(body);
      }
    } catch (_) {}
    return null;
  }
}

// ============================================================
// PROCESS SERVICE
// ============================================================

class PcProcess {
  final int pid;
  final String name;
  final double cpu;
  final double mem;

  const PcProcess({required this.pid, required this.name, required this.cpu, required this.mem});

  factory PcProcess.fromJson(Map<String, dynamic> json) => PcProcess(
        pid: json['pid'] as int? ?? 0,
        name: json['name'] as String? ?? 'unknown',
        cpu: (json['cpu'] as num?)?.toDouble() ?? 0,
        mem: (json['mem'] as num?)?.toDouble() ?? 0,
      );
}

class ProcessService {
  final http.Client _client;
  ProcessService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PcProcess>> getProcesses(Device device, {int limit = 15}) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/processes?limit=$limit');
    try {
      final response = await _client
          .get(uri, headers: {'X-Token': device.agentToken})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          return (body['processes'] as List?)
                  ?.map((e) => PcProcess.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];
        }
      }
    } catch (_) {}
    return [];
  }
}

// ============================================================
// MEDIA SERVICE
// ============================================================

class MediaService {
  final http.Client _client;
  MediaService({http.Client? client}) : _client = client ?? http.Client();

  Future<bool> sendKey(Device device, String key) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/media');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'X-Token': device.agentToken},
            body: jsonEncode({'key': key}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['ok'] == true;
      }
    } catch (_) {}
    return false;
  }
}

// ============================================================
// CUSTOM COMMAND SERVICE
// ============================================================

class CustomCommand {
  final String id;
  final String name;
  final String command;

  const CustomCommand({required this.id, required this.name, required this.command});

  factory CustomCommand.fromJson(Map<String, dynamic> json) => CustomCommand(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        command: json['command'] as String? ?? '',
      );
}

class CommandService {
  final http.Client _client;
  CommandService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<CustomCommand>> list(Device device) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/commands');
    try {
      final response = await _client
          .get(uri, headers: {'X-Token': device.agentToken})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          return (body['commands'] as List?)
                  ?.map((e) => CustomCommand.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];
        }
      }
    } catch (_) {}
    return [];
  }

  Future<(bool, String)> add(Device device, String name, String command) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/commands');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'X-Token': device.agentToken},
            body: jsonEncode({'name': name, 'command': command}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) return (true, '');
        return (false, body['error'] as String? ?? 'failed');
      }
    } catch (_) {}
    return (false, 'cannot reach agent');
  }

  Future<(bool, String)> delete(Device device, String id) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/commands/$id');
    try {
      final response = await _client
          .delete(uri, headers: {'X-Token': device.agentToken})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) return (true, '');
        return (false, body['error'] as String? ?? 'failed');
      }
    } catch (_) {}
    return (false, 'cannot reach agent');
  }

  Future<(bool, String)> run(Device device, String id) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/commands/run');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'X-Token': device.agentToken},
            body: jsonEncode({'id': id}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) return (true, body['name'] as String? ?? 'command');
        return (false, body['error'] as String? ?? 'failed');
      }
    } catch (_) {}
    return (false, 'cannot reach agent');
  }
}

// ============================================================
// APP SERVICE (installed apps)
// ============================================================

class AppEntry {
  final String name;
  final String path;
  final String source;
  final String? iconUrl;

  const AppEntry({required this.name, required this.path, this.source = '', this.iconUrl});

  factory AppEntry.fromJson(Map<String, dynamic> json) => AppEntry(
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        source: json['source'] as String? ?? '',
        iconUrl: json['icon_url'] as String?,
      );
}

class PinnedApp {
  final String name;
  final String path;

  const PinnedApp({required this.name, required this.path});

  factory PinnedApp.fromJson(Map<String, dynamic> json) => PinnedApp(
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'path': path};
}

class AppService {
  final http.Client _client;
  AppService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<AppEntry>> getApps(Device device) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/apps');
    try {
      final response = await _client
          .get(uri, headers: {'X-Token': device.agentToken})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          return (body['apps'] as List?)
                  ?.map((e) => AppEntry.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];
        }
      }
    } catch (_) {}
    return [];
  }

  Future<(bool, String)> launch(Device device, String path) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/apps/launch');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'X-Token': device.agentToken},
            body: jsonEncode({'path': path}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) return (true, '');
        return (false, body['error'] as String? ?? 'failed');
      }
    } catch (_) {}
    return (false, 'cannot reach agent');
  }

  Future<(bool, String)> openByName(Device device, String name) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/apps/open');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'X-Token': device.agentToken},
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          return (true, body['app_name'] as String? ?? name);
        }
        return (false, body['error'] as String? ?? 'failed');
      } else if (response.statusCode == 404) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return (false, body['error'] as String? ?? 'app not found');
      }
    } catch (_) {}
    return (false, 'cannot reach agent');
  }
}

// ============================================================
// PINNED APPS SERVICE (persist user-selected apps for voice)
// ============================================================

class PinnedAppsService {
  static const _key = 'pinned_apps';

  /// Persisted as a List<String> where each item is a JSON string
  /// { "name": "App Name", "path": "C:\\...\\app.exe" }
  Future<List<PinnedApp>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list
        .map((s) {
          try {
            return PinnedApp.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<PinnedApp>()
        .toList();
  }

  Future<void> save(List<PinnedApp> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final list = apps.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_key, list);
  }

  Future<void> update(PinnedApp entry) async {
    final current = await load();
    final idx = current.indexWhere((p) => p.name.toLowerCase() == entry.name.toLowerCase());
    if (idx >= 0) {
      current[idx] = entry;
    } else {
      current.add(entry);
    }
    await save(current);
  }

  /// Toggle a pinned app: if a pinned entry with the same name exists,
  /// remove it; otherwise add the provided entry (which includes the path).
  Future<void> toggle(AppEntry entry) async {
    final current = await load();
    final existingIndex = current.indexWhere((p) => p.name.toLowerCase() == entry.name.toLowerCase());
    if (existingIndex >= 0) {
      current.removeAt(existingIndex);
    } else {
      current.add(PinnedApp(name: entry.name, path: entry.path));
    }
    await save(current);
  }

  Future<bool> isPinned(String appName) async {
    final current = await load();
    return current.any((p) => p.name.toLowerCase() == appName.toLowerCase());
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
    } on FormatException {
      return (false, 'Agent returned invalid response — is the agent running?');
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
    } on FormatException {
      return (false, 'Agent returned invalid response — is the agent running?');
    } catch (e) {
      return (false, 'Error: $e');
    }
  }

  /// Register this app instance as the owner of the device.
  /// Returns (success, message). On 409, the device is already owned by another app.
  Future<(bool, String)> registerDevice(
    Device device, {
    required String deviceId,
    required String deviceName,
  }) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/register');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': device.agentToken,
              'device_id': deviceId,
              'device_name': deviceName,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 409) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final ownerName = body['owner_device_name'] as String? ?? 'another device';
          return (false, 'Already registered to $ownerName — ask them to delete it first, or re-run setup.bat on the PC');
        } catch (_) {
          return (false, 'Already registered to another device — ask them to delete it first, or re-run setup.bat on the PC');
        }
      }
      // 404/405 = old agent without /register endpoint
      if (response.statusCode == 404 || response.statusCode == 405) {
        return (false, 'Agent outdated — rerun setup.bat on your PC to update');
      }
      if (response.statusCode != 200) {
        return (false, 'Agent returned ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['ok'] == true) {
        return (true, 'registered');
      }
      return (false, (body['error'] as String?) ?? 'registration failed');
    } on SocketException {
      return (false, 'Cannot connect to agent');
    } on TimeoutException {
      return (false, 'Connection timed out');
    } on FormatException {
      return (false, 'Agent returned invalid response — is the agent running?');
    } catch (e) {
      return (false, 'Error: $e');
    }
  }

  /// Unregister this app instance from the device.
  Future<(bool, String)> unregisterDevice(
    Device device, {
    required String deviceId,
  }) async {
    final uri = Uri.parse('http://${device.ipAddress}:${device.agentPort}/unregister');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': device.agentToken,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 403) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final ownerName = body['owner_device_name'] as String? ?? 'another device';
          return (false, 'This PC is registered to $ownerName — re-run setup.bat on your PC to reset');
        } catch (_) {
          return (false, 'This PC is registered to another device — re-run setup.bat on your PC to reset');
        }
      }
      if (response.statusCode == 404 || response.statusCode == 405) {
        return (false, 'Agent outdated — rerun setup.bat on your PC to update');
      }
      if (response.statusCode != 200) {
        return (false, 'Agent returned ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['ok'] == true) {
        return (true, 'unregistered');
      }
      return (false, (body['error'] as String?) ?? 'unregister failed');
    } on SocketException {
      return (false, 'Cannot connect to agent');
    } on TimeoutException {
      return (false, 'Connection timed out');
    } on FormatException {
      return (false, 'Agent returned invalid response — is the agent running?');
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
        if (!NetworkHelper._isPrivateIp(ip)) continue;

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
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: Text(
                header!.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.secondaryLabel,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
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
          splashColor: Colors.transparent,
          highlightColor: AppColors.cardLight.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.label,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: const TextStyle(
                              color: AppColors.secondaryLabel,
                              fontSize: 12,
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
          Padding(
            padding: EdgeInsets.only(left: leading != null ? 62 : 16),
            child: const Divider(color: AppColors.separator, height: 0.5),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: onTap != null ? AppColors.label : AppColors.tertiaryLabel,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: AppColors.quaternaryLabel,
                  size: 16,
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
  final _statsService = SystemStatsService();
  final _pinnedAppsService = PinnedAppsService();
  final _appService = AppService();
  List<Device> _devices = [];
  final Map<String, bool> _online = {};
  final Map<String, AgentStatus?> _agentStatus = {};
  final Map<String, SystemStats?> _deviceStats = {};
  final Set<String> _checking = {};
  bool _loading = true;
  String? _wakeTarget;
  Timer? _refreshTimer;
  String _deviceId = '';
  List<PinnedApp> _pinnedApps = [];
  List<AppEntry> _availableApps = [];

  /// Devices that are booting up after WoL was sent (60 second window)
  final Map<String, DateTime> _starting = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadPinnedApps();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkAll(),
    );
  }

  Future<void> _loadPinnedApps() async {
    final pinned = await _pinnedAppsService.load();
    if (mounted) setState(() => _pinnedApps = pinned);
  }

  bool _loadingApps = false;

  Future<void> _loadAvailableApps() async {
    if (_loadingApps) return;
    _loadingApps = true;
    try {
      Device? target;
      for (final d in _devices) {
        if (_online[d.id] == true && d.hasAgent) {
          target = d;
          break;
        }
      }
      if (target == null) return;
      final apps = await _appService.getApps(target);
      if (mounted) setState(() => _availableApps = apps);
    } finally {
      _loadingApps = false;
    }
  }

  Future<void> _togglePinnedApp(AppEntry entry) async {
    await _pinnedAppsService.toggle(entry);
    final pinned = await _pinnedAppsService.load();
    if (mounted) setState(() => _pinnedApps = pinned);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final devices = await _storage.loadDevices();
    final deviceId = await _storage.getDeviceId();
    setState(() {
      _devices = devices;
      _deviceId = deviceId;
      _loading = false;
    });
    _checkAll();
    // Load apps after a short delay to let device status resolve
    Future.delayed(const Duration(seconds: 2), _loadAvailableApps);
  }

  Future<void> _checkAll() async {
    for (final d in _devices) {
      _checkDevice(d);
    }
  }

  /// Number of consecutive agent connection failures before clearing stats.
  /// Prevents stats from flickering on brief network hiccups.
  final Map<String, int> _consecutiveFailures = {};
  static const int _maxFailuresBeforeClear = 3;

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
            _starting.remove(d.id);
            _online[d.id] = true;
          } else if (isStarting) {
            _online[d.id] = false;
          } else {
            _starting.remove(d.id);
            _online[d.id] = false;
          }
        });
      }

      if (d.hasAgent) {
        final (ok, msg) = await _agent.testConnection(d);
        if (mounted && ok) {
          _consecutiveFailures[d.id] = 0;
          final match = RegExp(r'Connected to (.+?) \((.+?)\)').firstMatch(msg);
          if (match != null) {
            setState(() {
              _agentStatus[d.id] = AgentStatus(
                hostname: match.group(1)!,
                platform: match.group(2)!,
                pythonVersion: '',
                fetchedAt: DateTime.now(),
              );
              _starting.remove(d.id);
              _online[d.id] = true;
            });
            final stats = await _statsService.getStats(d);
            if (mounted) setState(() => _deviceStats[d.id] = stats);
          }
        } else if (mounted) {
          // Only clear stats after multiple consecutive failures
          final failures = (_consecutiveFailures[d.id] ?? 0) + 1;
          _consecutiveFailures[d.id] = failures;
          if (failures >= _maxFailuresBeforeClear) {
            setState(() {
              _agentStatus[d.id] = null;
              _deviceStats[d.id] = null;
            });
          }
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

      // Register with the agent to claim ownership (only if agent is configured)
      if (newDevice.hasAgent) {
        if (mounted) {
          showTopNotification(
            context,
            message: 'Registering with PC...',
            icon: Icons.sync_rounded,
            iconColor: AppColors.blue,
          );
        }
        var (ok, msg) = await _agent.registerDevice(
          newDevice,
          deviceId: _deviceId,
          deviceName: newDevice.name,
        );

        if (!ok) {
          if (mounted) {
            showTopNotification(
              context,
              message: msg,
              icon: Icons.error_outline_rounded,
              iconColor: AppColors.red,
            );
          }
          return;
        }
      }

      setState(() => _devices.add(newDevice));
      await _storage.saveDevices(_devices);
      _checkDevice(newDevice);
    }
  }

  Future<void> _wakeDevice(Device d) async {
    HapticFeedback.lightImpact();
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

  Color _getAppColor(String name) {
    final lower = name.toLowerCase();
    // Real brand colors
    if (lower.contains('chrome')) return const Color(0xFF4285F4);     // Google blue
    if (lower.contains('firefox')) return const Color(0xFFFF7139);    // Firefox orange
    if (lower.contains('edge')) return const Color(0xFF0078D4);       // Edge blue
    if (lower.contains('spotify')) return const Color(0xFF1DB954);    // Spotify green
    if (lower.contains('discord')) return const Color(0xFF5865F2);    // Discord blurple
    if (lower.contains('slack')) return const Color(0xFF4A154B);      // Slack purple
    if (lower.contains('code') || lower.contains('vscode')) return const Color(0xFF007ACC); // VS Code blue
    if (lower.contains('notepad')) return const Color(0xFF0078D4);    // Windows blue
    if (lower.contains('terminal') || lower.contains('cmd')) return const Color(0xFF0C0C0C); // Terminal black
    if (lower.contains('powershell')) return const Color(0xFF012456); // PowerShell blue
    if (lower.contains('steam')) return const Color(0xFF1B2838);      // Steam dark
    if (lower.contains('obs')) return const Color(0xFF302B2B);        // OBS dark
    if (lower.contains('vlc')) return const Color(0xFFFF8800);        // VLC orange
    if (lower.contains('word')) return const Color(0xFF2B579A);       // Word blue
    if (lower.contains('excel')) return const Color(0xFF217346);      // Excel green
    if (lower.contains('powerpoint')) return const Color(0xFFD24726); // PowerPoint red
    if (lower.contains('outlook')) return const Color(0xFF0078D4);    // Outlook blue
    if (lower.contains('teams')) return const Color(0xFF6264A7);      // Teams purple
    if (lower.contains('git')) return const Color(0xFFF05032);        // Git red
    if (lower.contains('node')) return const Color(0xFF339933);       // Node green
    if (lower.contains('python')) return const Color(0xFF3776AB);     // Python blue
    if (lower.contains('java')) return const Color(0xFFED8B00);       // Java orange
    if (lower.contains('brave')) return const Color(0xFFFB542B);      // Brave orange
    if (lower.contains('cursor')) return const Color(0xFF000000);     // Cursor black
    if (lower.contains('postgre') || lower.contains('pgadmin')) return const Color(0xFF336791); // PostgreSQL blue
    if (lower.contains('valorant')) return const Color(0xFFFF4655);   // Valorant red
    if (lower.contains('dota')) return const Color(0xFF111111);       // Dota dark
    if (lower.contains('photoshop')) return const Color(0xFF31A8FF);  // PS blue
    if (lower.contains('illustrator')) return const Color(0xFFFF9A00); // AI orange
    if (lower.contains('store')) return const Color(0xFF0078D4);      // MS Store blue
    if (lower.contains('explorer') || lower.contains('file')) return const Color(0xFFDCC72E); // Explorer yellow
    if (lower.contains('settings')) return const Color(0xFF767676);   // Settings gray
    if (lower.contains('calculator')) return const Color(0xFF0078D4);
    if (lower.contains('paint')) return const Color(0xFF0097A7);
    if (lower.contains('winrar') || lower.contains('7-zip')) return const Color(0xFF2D5DA1);
    if (lower.contains('zoom')) return const Color(0xFF2D8CFF);
    if (lower.contains('capcut')) return const Color(0xFF000000);
    if (lower.contains('medal')) return const Color(0xFF6C5CE7);
    if (lower.contains('viber')) return const Color(0xFF7360F2);
    if (lower.contains('xampp')) return const Color(0xFFFB7A24);
    // Fallback: generate a deterministic color from the name
    final hash = name.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.45).toColor();
  }

  Future<void> _showAppPicker() async {
    // Load apps if not already loaded — await so the modal has data
    if (_availableApps.isEmpty) await _loadAvailableApps();

    if (!mounted) return;
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = searchQuery.isEmpty
              ? _availableApps
              : _availableApps.where((a) => a.name.toLowerCase().contains(searchQuery)).toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: const BoxDecoration(
              color: AppColors.elevatedBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.separator,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'Add to Quick Launch',
                        style: TextStyle(
                          color: AppColors.label,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      autofocus: true,
                      style: const TextStyle(color: AppColors.label, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        hintStyle: TextStyle(color: AppColors.tertiaryLabel),
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.tertiaryLabel, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (v) => setModalState(() => searchQuery = v.toLowerCase()),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // App list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No apps found',
                            style: TextStyle(color: AppColors.tertiaryLabel, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final app = filtered[i];
                            final pinned = _pinnedApps.any((p) => p.name.toLowerCase() == app.name.toLowerCase());
                            final color = _getAppColor(app.name);
                            final initial = app.name.isNotEmpty ? app.name[0].toUpperCase() : '?';
                            return GestureDetector(
                              onTap: () async {
                                await _togglePinnedApp(app);
                                setModalState(() {}); // refresh modal
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    // App icon
                                    _AppIcon(
                                      initial: initial,
                                      color: color,
                                      size: 28,
                                      radius: 7,
                                      iconUrl: app.iconUrl,
                                      appName: app.name,
                                    ),
                                    const SizedBox(width: 12),
                                    // App name
                                    Expanded(
                                      child: Text(
                                        app.name,
                                        style: TextStyle(
                                          color: pinned ? AppColors.blue : AppColors.label,
                                          fontSize: 15,
                                          fontWeight: pinned ? FontWeight.w500 : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    // Check or add
                                    Icon(
                                      pinned ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                      color: pinned ? AppColors.blue : AppColors.tertiaryLabel,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _launchApp(AppEntry app) async {
    HapticFeedback.lightImpact();
    Device? target;
    for (final d in _devices) {
      if (_online[d.id] == true && d.hasAgent) {
        target = d;
        break;
      }
    }
    if (target == null) {
      if (mounted) showTopNotification(context, message: 'No online device', icon: Icons.error_outline_rounded, iconColor: AppColors.red);
      return;
    }
    // Prefer direct path-based launch when we have a concrete path (more reliable)
    if (app.path.isNotEmpty) {
      final (ok, msg) = await _appService.launch(target, app.path);
      if (mounted) {
        showTopNotification(
          context,
          message: ok ? 'Opening ${app.name}...' : 'Failed: $msg',
          icon: ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
          iconColor: ok ? AppColors.green : AppColors.red,
        );
      }
      if (ok) return;
      // If path-based launch failed, fall through to name-based fuzzy match
    }

    // If we don't have a concrete path, attempt to resolve candidates locally
    if (app.path.isEmpty) {
      final lc = app.name.toLowerCase();
      final candidates = _availableApps.where((a) {
        final an = a.name.toLowerCase();
        return an == lc || an.contains(lc) || lc.contains(an);
      }).toList();

      if (candidates.length > 1) {
        // Ask the user to pick which exact app they mean
        final selected = await showModalBottomSheet<AppEntry?>(
          context: context,
          builder: (_) => Container(
            color: AppColors.card,
            child: ListView.separated(
              itemCount: candidates.length,
              separatorBuilder: (_, __) => Divider(color: AppColors.separator, height: 0.5),
              itemBuilder: (_, i) {
                final c = candidates[i];
                return ListTile(
                  leading: _AppIcon(initial: c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', color: _getAppColor(c.name), size: 36, radius: 8, iconUrl: c.iconUrl, appName: c.name),
                  title: Text(c.name, style: const TextStyle(color: AppColors.label)),
                  subtitle: Text(c.path.isNotEmpty ? c.path : c.source, style: const TextStyle(color: AppColors.secondaryLabel, fontSize: 12)),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        );

        if (selected != null) {
          // Persist the selected concrete path for this pinned app (if it exists)
          await _pinnedAppsService.update(PinnedApp(name: selected.name, path: selected.path));
          final pinned = await _pinnedAppsService.load();
          if (mounted) setState(() => _pinnedApps = pinned);
          // Launch the selected path if available
          if (selected.path.isNotEmpty) {
            final (ok, msg) = await _appService.launch(target, selected.path);
            if (mounted) showTopNotification(context, message: ok ? 'Opening ${selected.name}...' : 'Failed: $msg', icon: ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, iconColor: ok ? AppColors.green : AppColors.red);
            return;
          }
        }
      }

      // If we have a single candidate, prefer it
      if (candidates.length == 1) {
        final c = candidates.first;
        if (c.path.isNotEmpty) {
          await _pinnedAppsService.update(PinnedApp(name: c.name, path: c.path));
          final pinned = await _pinnedAppsService.load();
          if (mounted) setState(() => _pinnedApps = pinned);
          final (ok, msg) = await _appService.launch(target, c.path);
          if (mounted) showTopNotification(context, message: ok ? 'Opening ${c.name}...' : 'Failed: $msg', icon: ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, iconColor: ok ? AppColors.green : AppColors.red);
          return;
        }
      }

      // No concrete candidates found — fall back to name-based fuzzy match
    }

    // Try name-based fuzzy match (handles UWP, empty paths, shell: apps)
    final (nameOk, nameMsg) = await _appService.openByName(target, app.name);
    if (nameOk) {
      if (mounted) showTopNotification(context, message: 'Opening $nameMsg...', icon: Icons.check_circle_outline_rounded, iconColor: AppColors.green);
      return;
    }
    // If name-based failed and we previously attempted path it already produced a failure notification above
    // Both failed
    if (mounted) {
      showTopNotification(
        context,
        message: 'Failed: $nameMsg',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.red,
      );
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Devices',
                    style: TextStyle(
                      color: AppColors.label,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.secondaryLabel,
                      size: 22,
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
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.desktop_mac_rounded,
                        size: 32,
                        color: AppColors.tertiaryLabel,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Devices',
                      style: TextStyle(
                        color: AppColors.label,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap + to add your first device',
                      style: TextStyle(
                        color: AppColors.tertiaryLabel,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: IOSSection(
                header: 'Your Devices',
                children: _devices.asMap().entries.map((entry) {
                  final d = entry.value;
                  final isWaking = _wakeTarget == d.id;
                  final isOnline = _online[d.id];
                  final isStarting = _starting.containsKey(d.id);
                  final stats = _deviceStats[d.id];
                  return _DashboardDeviceCard(
                    device: d,
                    isOnline: isOnline,
                    isStarting: isStarting,
                    isWaking: isWaking,
                    agentStatus: _agentStatus[d.id],
                    stats: stats,
                    onWake: () => _wakeDevice(d),
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
                      if (confirm == true) {
                        // Best-effort unregister — device is removed locally regardless
                        String? unregisterMsg;
                        if (d.hasAgent) {
                          final deviceId = _deviceId.isNotEmpty ? _deviceId : await _storage.getDeviceId();
                          final (ok, msg) = await _agent.unregisterDevice(d, deviceId: deviceId);
                          if (!ok) unregisterMsg = msg;
                        }
                        if (!mounted) return;
                        if (unregisterMsg != null && context.mounted) {
                          showTopNotification(
                            context,
                            message: unregisterMsg,
                            icon: Icons.info_outline_rounded,
                            iconColor: AppColors.orange,
                          );
                        }
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
                  );
                }).toList(),
              ),
            ),
          // Quick Launch app strip — only show when devices exist
          if (_devices.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Section header with add button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Quick Launch',
                            style: TextStyle(
                              color: AppColors.secondaryLabel,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showAppPicker,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_rounded, color: AppColors.blue, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Centered app icons (or empty state)
                    if (_pinnedApps.isNotEmpty)
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: _pinnedApps.map((pinned) {
                            // Find app by exact name first, then case-insensitive match
                            var app = _availableApps.where((a) => a.name == pinned.name).firstOrNull;
                            app ??= _availableApps.where((a) => a.name.toLowerCase() == pinned.name.toLowerCase()).firstOrNull;
                            final color = _getAppColor(pinned.name);
                            final initial = pinned.name.isNotEmpty ? pinned.name[0].toUpperCase() : '?';
                            return GestureDetector(
                              onTap: () => _launchApp(app ?? AppEntry(name: pinned.name, path: pinned.path)),
                              child: SizedBox(
                                width: 48,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _AppIcon(
                                      initial: initial,
                                      color: color,
                                      size: 38,
                                      radius: 10,
                                      iconUrl: app?.iconUrl,
                                      appName: pinned.name,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      pinned.name.length > 7 ? '${pinned.name.substring(0, 6)}…' : pinned.name,
                                      style: const TextStyle(
                                        color: AppColors.secondaryLabel,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Tap + to add quick launch apps',
                          style: TextStyle(
                            color: AppColors.tertiaryLabel,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDevice,
        child: const Icon(Icons.add_rounded, size: 26),
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
// DASHBOARD DEVICE CARD (with inline stats)
// ============================================================

class _AppIcon extends StatefulWidget {
  final String initial;
  final Color color;
  final double size;
  final double radius;
  final String? iconUrl;
  final String? appName;

  const _AppIcon({
    required this.initial,
    required this.color,
    this.size = 38,
    this.radius = 10,
    this.iconUrl,
    this.appName,
  });

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  Uint8List? _imageBytes;
  bool _loading = false;
  String? _loadedUrl;

  // Map app names to their domains for favicon lookup
  static const _domainMap = {
    'chrome': 'google.com',
    'google chrome': 'google.com',
    'firefox': 'mozilla.org',
    'mozilla firefox': 'mozilla.org',
    'edge': 'microsoft.com',
    'microsoft edge': 'microsoft.com',
    'discord': 'discord.com',
    'spotify': 'spotify.com',
    'steam': 'steampowered.com',
    'epic games': 'epicgames.com',
    'epic games launcher': 'epicgames.com',
    'vscode': 'code.visualstudio.com',
    'visual studio code': 'code.visualstudio.com',
    'vs code': 'code.visualstudio.com',
    'obs': 'obsproject.com',
    'obs studio': 'obsproject.com',
    'vlc': 'videolan.org',
    'vlc media player': 'videolan.org',
    'telegram': 'telegram.org',
    'whatsapp': 'whatsapp.com',
    'slack': 'slack.com',
    'teams': 'microsoft.com',
    'microsoft teams': 'microsoft.com',
    'zoom': 'zoom.us',
    'notepad++': 'notepad-plus-plus.org',
    'photoshop': 'adobe.com',
    'illustrator': 'adobe.com',
    'premiere': 'adobe.com',
    '7-zip': '7-zip.org',
    'winrar': 'win-rar.com',
    'git': 'git-scm.com',
    'github': 'github.com',
    'android studio': 'developer.android.com',
    'intellij': 'jetbrains.com',
    'pycharm': 'jetbrains.com',
    'webstorm': 'jetbrains.com',
    'brave': 'brave.com',
    'brave browser': 'brave.com',
    'opera': 'opera.com',
    'vivaldi': 'vivaldi.com',
    'outlook': 'outlook.com',
    'microsoft outlook': 'outlook.com',
    'word': 'microsoft.com',
    'excel': 'microsoft.com',
    'powerpoint': 'microsoft.com',
    'onenote': 'microsoft.com',
    'onenote for windows': 'microsoft.com',
    'paint': 'microsoft.com',
    'calculator': 'microsoft.com',
    'terminal': 'microsoft.com',
    'windows terminal': 'microsoft.com',
    'powershell': 'microsoft.com',
    'cmd': 'microsoft.com',
    'command prompt': 'microsoft.com',
    'file explorer': 'microsoft.com',
    'explorer': 'microsoft.com',
    'settings': 'microsoft.com',
    'microsoft store': 'microsoft.com',
    'store': 'microsoft.com',
    'xbox': 'xbox.com',
    'nvidia': 'nvidia.com',
    'nvidia control panel': 'nvidia.com',
    'amd': 'amd.com',
    'intel': 'intel.com',
    'docker': 'docker.com',
    'postman': 'postman.com',
    'figma': 'figma.com',
    'notion': 'notion.so',
    'obsidian': 'obsidian.md',
    '1password': '1password.com',
    'bitwarden': 'bitwarden.com',
    'malwarebytes': 'malwarebytes.com',
    'ccleaner': 'ccleaner.com',
    'ticktick': 'ticktick.com',
    'todoist': 'todoist.com',
    'trello': 'trello.com',
    'jira': 'atlassian.com',
    'confluence': 'atlassian.com',
    'youtube': 'youtube.com',
    'netflix': 'netflix.com',
    'twitch': 'twitch.tv',
    'reddit': 'reddit.com',
    'twitter': 'x.com',
    'x': 'x.com',
    'facebook': 'facebook.com',
    'instagram': 'instagram.com',
    'linkedin': 'linkedin.com',
    'pinterest': 'pinterest.com',
    'tiktok': 'tiktok.com',
    'snapchat': 'snapchat.com',
    'medium': 'medium.com',
    'substack': 'substack.com',
    'dropbox': 'dropbox.com',
    'google drive': 'drive.google.com',
    'onedrive': 'onedrive.com',
    'microsoft onedrive': 'onedrive.com',
    'google': 'google.com',
    'bing': 'bing.com',
    'duckduckgo': 'duckduckgo.com',
    'brave search': 'search.brave.com',
    'copilot': 'copilot.microsoft.com',
    'chatgpt': 'chat.openai.com',
    'openai': 'openai.com',
    'claude': 'claude.ai',
    'anthropic': 'anthropic.com',
    'midjourney': 'midjourney.com',
    'stable diffusion': 'stability.ai',
    'audacity': 'audacityteam.org',
    'fl studio': 'image-line.com',
    'ableton': 'ableton.com',
    'logic pro': 'apple.com',
    'garageband': 'apple.com',
    'da vinci resolve': 'blackmagicdesign.com',
    'premiere pro': 'adobe.com',
    'after effects': 'adobe.com',
    'lightroom': 'adobe.com',
    'xd': 'adobe.com',
    'indesign': 'adobe.com',
    'blender': 'blender.org',
    'unity': 'unity.com',
    'unreal engine': 'unrealengine.com',
    'godot': 'godotengine.org',
    'minecraft': 'minecraft.net',
    'roblox': 'roblox.com',
    'fortnite': 'fortnite.com',
    'valorant': 'playvalorant.com',
    'league of legends': 'leagueoflegends.com',
    'dota': 'dota2.com',
    'dota 2': 'dota2.com',
    'counter-strike': 'counter-strike.net',
    'cs2': 'counter-strike.net',
    'overwatch': 'overwatch.com',
    'apex legends': 'ea.com',
    'pubg': 'pubg.com',
    'genshin impact': 'hoyoverse.com',
    'world of warcraft': 'worldofwarcraft.blizzard.com',
    'diablo': 'diablo.com',
    'hearthstone': 'hearthstone.blizzard.com',
    'starcraft': 'starcraft2.blizzard.com',
  };

  String? _getOnlineIconUrl() {
    final name = widget.appName?.toLowerCase().trim();
    if (name == null || name.isEmpty) return null;

    // Look up domain from map
    String? domain = _domainMap[name];

    // If not in map, try to construct a domain from the app name
    if (domain == null) {
      // Clean the name: remove version numbers, architecture, etc.
      final cleanName = name
          .replaceAll(RegExp(r'\s*\d+[\.\d]*\s*'), ' ')
          .replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ')
          .replaceAll(RegExp(r'\s*x(64|86)\s*'), ' ')
          .replaceAll(RegExp(r'\s*(64-bit|32-bit)\s*'), ' ')
          .trim();

      // Try common domain patterns
      final candidates = [
        '${cleanName.replaceAll(' ', '').replaceAll('-', '')}.com',
        '${cleanName.replaceAll(' ', '-')}.com',
        '${cleanName.replaceAll(' ', '')}.io',
        '${cleanName.replaceAll(' ', '')}.app',
      ];

      if (candidates.isNotEmpty) {
        domain = candidates.first;
      }
    }

    if (domain == null) return null;

    // Use Google's favicon service for high-quality icons
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
  }

  @override
  void didUpdateWidget(covariant _AppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.iconUrl != oldWidget.iconUrl || widget.appName != oldWidget.appName) {
      _imageBytes = null;
      _loadedUrl = null;
      _loadImage();
    }
  }

  void _loadImage() async {
    if (_loading || _loadedUrl != null) return;

    // Try agent icon_url first
    final agentUrl = widget.iconUrl;
    if (agentUrl != null && agentUrl.isNotEmpty) {
      _loading = true;
      try {
        final response = await http.get(Uri.parse(agentUrl)).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200 && response.bodyBytes.length > 100 && mounted) {
          setState(() {
            _imageBytes = response.bodyBytes;
            _loadedUrl = agentUrl;
            _loading = false;
          });
          return;
        }
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    }

    // Fall back to online icon based on app name
    final onlineUrl = _getOnlineIconUrl();
    if (onlineUrl != null && mounted) {
      setState(() => _loading = true);
      try {
        final response = await http.get(Uri.parse(onlineUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 && response.bodyBytes.length > 100 && mounted) {
          setState(() {
            _imageBytes = response.bodyBytes;
            _loadedUrl = onlineUrl;
            _loading = false;
          });
          return;
        }
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBytes == null && !_loading) {
      _loadImage();
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _imageBytes != null
          ? Image.memory(_imageBytes!, fit: BoxFit.cover, width: widget.size, height: widget.size)
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.color, widget.color.withValues(alpha: 0.7)],
        ),
      ),
      child: Center(
        child: Text(
          widget.initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.size * 0.44,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DashboardDeviceCard extends StatelessWidget {
  final Device device;
  final bool? isOnline;
  final bool isStarting;
  final bool isWaking;
  final AgentStatus? agentStatus;
  final SystemStats? stats;
  final VoidCallback onWake;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const _DashboardDeviceCard({
    required this.device,
    required this.isOnline,
    required this.isStarting,
    required this.isWaking,
    this.agentStatus,
    this.stats,
    required this.onWake,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Top row: icon + name + power
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isOnline == true
                        ? AppColors.green.withValues(alpha: 0.12)
                        : isStarting
                            ? AppColors.orange.withValues(alpha: 0.12)
                            : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.desktop_mac_rounded,
                    color: isOnline == true
                        ? AppColors.green
                        : isStarting
                            ? AppColors.orange
                            : AppColors.tertiaryLabel,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agentStatus != null ? agentStatus!.hostname : device.name,
                        style: const TextStyle(
                          color: AppColors.label,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        agentStatus != null
                            ? '(${agentStatus!.platform})'
                            : isStarting
                                ? 'Starting...'
                                : device.mac,
                        style: const TextStyle(
                          color: AppColors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                isWaking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.blue,
                        ),
                      )
                    : GestureDetector(
                        onTap: onWake,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.power_settings_new_rounded,
                            color: isOnline == true ? AppColors.blue : AppColors.quaternaryLabel,
                            size: 20,
                          ),
                        ),
                      ),
              ],
            ),
            // Stats row (only when online with agent)
            if (isOnline == true && stats != null) ...[
              const SizedBox(height: 10),
              const Divider(color: AppColors.separator, height: 0.5),
              const SizedBox(height: 10),
              _MiniStatRow(stats: stats!),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStatRow extends StatelessWidget {
  final SystemStats stats;

  const _MiniStatRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MiniStat(label: 'CPU', value: stats.cpuPercent, color: AppColors.blue),
        const SizedBox(width: 12),
        _MiniStat(label: 'RAM', value: stats.ramPercent, color: AppColors.green),
        const SizedBox(width: 12),
        _MiniStat(label: 'Disk', value: stats.diskPercent, color: AppColors.orange),
        const SizedBox(width: 6),
        // Live indicator dot
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.tertiaryLabel, fontSize: 11),
              ),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: AppColors.separator,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
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
  final _agent = AgentService();
  final _storage = StorageService();
  String _deviceId = '';

  bool get _isEditing => widget.device != null;

  @override
  void initState() {
    super.initState();
    _storage.getDeviceId().then((id) => _deviceId = id);
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
      // Fields left empty — populated by "Scan Network" or user input
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
      // Best-effort unregister — device is removed locally regardless
      String? unregisterMsg;
      if (widget.device!.hasAgent) {
        // Ensure device ID is loaded (may not have completed from initState)
        final deviceId = _deviceId.isNotEmpty ? _deviceId : await _storage.getDeviceId();
        final (ok, msg) = await _agent.unregisterDevice(widget.device!, deviceId: deviceId);
        if (!ok) unregisterMsg = msg;
      }
      if (!mounted) return;
      if (unregisterMsg != null) {
        showTopNotification(
          context,
          message: unregisterMsg,
          icon: Icons.info_outline_rounded,
          iconColor: AppColors.orange,
        );
      }
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
    HapticFeedback.lightImpact();
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.radar_rounded, color: Colors.white, size: 17),
                            const SizedBox(width: 8),
                            Text(
                              'Scan Network',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
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
              header: 'Device Info',
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
              header: 'Network',
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
                              color: AppColors.tertiaryLabel,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            broadcast,
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'auto-derived',
                            style: TextStyle(
                              color: AppColors.quaternaryLabel,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WoL Port',
                        style: TextStyle(
                          color: AppColors.quaternaryLabel,
                          fontSize: 12,
                          height: 1.3,
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
                                color: isSelected ? Colors.white : AppColors.secondaryLabel,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _deleteDevice,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text(
                          'Delete Device',
                          style: TextStyle(
                            color: AppColors.red,
                            fontSize: 15,
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
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              description,
              style: const TextStyle(
                color: AppColors.quaternaryLabel,
                fontSize: 12,
                height: 1.3,
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
  final _audioOutput = AudioOutputService();
  bool _busy = false;
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
    _loadPcAudio();
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
        bool shouldReloadAudio = false;
        setState(() {
          if (reachable) {
            // Device is reachable — clear starting state
            shouldReloadAudio = _online != true;
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
        // Reload audio when device comes back online (e.g. after reboot)
        if (shouldReloadAudio) {
          _audioRetries = 0;
          _loadPcAudio();
        }
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

  Future<void> _handleAgent(String action) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          _actionTitle(action),
          style: const TextStyle(color: AppColors.label),
        ),
        content: Text(
          _actionMessage(action),
          style: const TextStyle(color: AppColors.secondaryLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryLabel)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_actionButtonLabel(action), style: TextStyle(color: _actionColor(action))),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    // For sleep, set "starting" state BEFORE the HTTP call because
    // SetSystemPowerState blocks until wake — the response will time out.
    if (action == 'sleep') {
      setState(() {
        _startedAt = DateTime.now();
        _online = false;
      });
    }

    final (ok, msg) = await _agent.sendAction(_device, action);
    setState(() {
      _busy = false;
      if (ok && (action == 'reboot' || action == 'shutdown')) {
        _startedAt = DateTime.now();
        _online = false;
      }
    });
    if (mounted) {
      showTopNotification(
        context,
        message: action == 'sleep'
            ? 'PC is sleeping...'
            : ok
                ? msg
                : 'Failed: $msg',
        icon: action == 'sleep'
            ? Icons.bedtime_rounded
            : ok
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
        iconColor: action == 'sleep'
            ? AppColors.indigo
            : ok
                ? AppColors.green
                : AppColors.red,
      );
    }
    _checkOnline();
  }

  String _actionTitle(String action) {
    switch (action) {
      case 'reboot': return 'Reboot PC?';
      case 'shutdown': return 'Shutdown PC?';
      case 'sleep': return 'Sleep PC?';
      case 'lock': return 'Lock PC?';
      default: return 'Confirm Action';
    }
  }

  String _actionMessage(String action) {
    switch (action) {
      case 'reboot': return 'This will restart ${_device.name}. All unsaved work will be lost.';
      case 'shutdown': return 'This will turn off ${_device.name}. All unsaved work will be lost.';
      case 'sleep': return 'This will put ${_device.name} to sleep.';
      case 'lock': return 'This will lock the screen on ${_device.name}.';
      default: return 'Are you sure?';
    }
  }

  String _actionButtonLabel(String action) {
    switch (action) {
      case 'reboot': return 'Reboot';
      case 'shutdown': return 'Shutdown';
      case 'sleep': return 'Sleep';
      case 'lock': return 'Lock';
      default: return 'Confirm';
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'reboot': return AppColors.orange;
      case 'shutdown': return AppColors.red;
      case 'sleep': return AppColors.blue;
      case 'lock': return AppColors.secondaryLabel;
      default: return AppColors.blue;
    }
  }

  IconData _getAudioDeviceIcon(String type) {
    switch (type) {
      case 'headphones': return Icons.headphones_rounded;
      case 'bluetooth': return Icons.bluetooth_rounded;
      case 'hdmi': return Icons.tv_rounded;
      case 'speaker': return Icons.speaker_rounded;
      default: return Icons.speaker_rounded;
    }
  }

  String _getAudioDeviceSubtitle(String type) {
    switch (type) {
      case 'headphones': return 'Wired';
      case 'bluetooth': return 'Bluetooth';
      case 'hdmi': return 'HDMI / DisplayPort';
      case 'speaker': return 'Speaker';
      default: return 'Audio device';
    }
  }

  Future<void> _editDevice() async {
    final existingDevices = await _storage.loadDevices();
    if (!mounted) return;
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

  // PC audio state via HTTP to agent
  bool _audioLoaded = false;
  List<AudioDevice> _pcAudioDevices = [];
  String _activePcAudioDeviceId = '';
  int _pcVolume = 50;
  bool _pcMuted = false;

  /// Debounce timer for volume slider
  Timer? _volumeDebounce;

  /// Number of retries for loading audio after reboot (audio services may not be ready yet)
  int _audioRetries = 0;
  static const int _maxAudioRetries = 5;

  Future<void> _loadPcAudio({bool isRetry = false}) async {
    if (!_device.hasAgent) {
      if (mounted) setState(() => _audioLoaded = true);
      return;
    }
    try {
      final devices = await _audioOutput.getDevices(_device);
      final volume = await _audioOutput.getVolume(_device);
      final muted = await _audioOutput.isMuted(_device);
      // If no devices returned after reboot, retry (audio services may not be ready)
      if (devices.isEmpty && _audioRetries < _maxAudioRetries) {
        _audioRetries++;
        debugPrint('No audio devices found, retrying ($_audioRetries/$_maxAudioRetries)...');
        await Future.delayed(const Duration(seconds: 3));
        return _loadPcAudio(isRetry: true);
      }
      // Find active device from the list
      final active = devices.firstWhere(
        (d) => d.isCurrentlySelected,
        orElse: () => devices.isNotEmpty ? devices.first : AudioDevice(id: '', name: '', type: 'speaker'),
      );
      if (mounted) {
        setState(() {
          _pcAudioDevices = devices;
          _activePcAudioDeviceId = active.id;
          _pcVolume = volume;
          _pcMuted = muted;
          _audioLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load PC audio: $e');
      // Retry on error (agent may be starting up after reboot)
      if (_audioRetries < _maxAudioRetries) {
        _audioRetries++;
        debugPrint('Audio load failed, retrying ($_audioRetries/$_maxAudioRetries)...');
        await Future.delayed(const Duration(seconds: 3));
        return _loadPcAudio(isRetry: true);
      }
      if (mounted) setState(() => _audioLoaded = true);
    }
  }

  Future<void> _setPcVolume(int value) async {
    setState(() => _pcVolume = value);
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 200), () async {
      final ok = await _audioOutput.setVolume(_device, value);
      if (!ok && mounted) {
        // Volume set failed — reload actual state from PC
        final actual = await _audioOutput.getVolume(_device);
        setState(() => _pcVolume = actual);
      }
    });
  }

  Future<void> _togglePcMute() async {
    final newMuted = !_pcMuted;
    setState(() => _pcMuted = newMuted);
    final ok = await _audioOutput.setMute(_device, newMuted);
    if (!ok && mounted) {
      setState(() => _pcMuted = !newMuted);
    }
  }

  Future<void> _switchPcAudioDevice(String deviceId) async {
    final (ok, error) = await _audioOutput.setActiveDevice(_device, deviceId);
    if (ok && mounted) {
      await _loadPcAudio();
    } else if (!ok && mounted && error.isNotEmpty) {
      showTopNotification(
        context,
        message: error,
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.red,
      );
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
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _online == true
                          ? AppColors.green.withValues(alpha: 0.12)
                          : _startedAt != null &&
                                  DateTime.now().difference(_startedAt!).inSeconds < 60
                              ? AppColors.orange.withValues(alpha: 0.12)
                              : _online == false
                                  ? AppColors.red.withValues(alpha: 0.12)
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
                      size: 18,
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

            // Actions grid + Volume
            if (d.hasAgent)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 8),
                      child: Text(
                        'Actions',
                        style: TextStyle(
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
                      child: Column(
                        children: [
                          // 4-column icon grid
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _ActionGridItem(
                                  icon: Icons.restart_alt_rounded,
                                  iconColor: AppColors.orange,
                                  label: 'Reboot',
                                  onTap: _busy ? null : () => _handleAgent('reboot'),
                                ),
                                _ActionGridItem(
                                  icon: Icons.power_settings_new_rounded,
                                  iconColor: AppColors.red,
                                  label: 'Shutdown',
                                  onTap: _busy ? null : () => _handleAgent('shutdown'),
                                ),
                                _ActionGridItem(
                                  icon: Icons.bedtime_rounded,
                                  iconColor: AppColors.indigo,
                                  label: 'Sleep',
                                  onTap: _busy ? null : () => _handleAgent('sleep'),
                                ),
                                _ActionGridItem(
                                  icon: Icons.lock_rounded,
                                  iconColor: AppColors.secondaryLabel,
                                  label: 'Lock',
                                  onTap: _busy ? null : () => _handleAgent('lock'),
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 1, color: AppColors.separator, indent: 16, endIndent: 16),

                          // Volume
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _pcMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                      color: _pcMuted ? AppColors.red : AppColors.secondaryLabel,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Volume',
                                      style: TextStyle(
                                        color: AppColors.label,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: _togglePcMute,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Text(
                                          _pcMuted ? 'Muted' : '$_pcVolume%',
                                          style: TextStyle(
                                            color: _pcMuted ? AppColors.red : AppColors.secondaryLabel,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: AppColors.green,
                                    inactiveTrackColor: AppColors.separator,
                                    thumbColor: AppColors.green,
                                    overlayColor: AppColors.green.withValues(alpha: 0.1),
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                  ),
                                  child: Slider(
                                    value: _pcMuted ? 0 : _pcVolume.toDouble(),
                                    min: 0,
                                    max: 100,
                                    onChanged: (v) => setState(() => _pcVolume = v.round()),
                                    onChangeEnd: (v) {
                                      if (_pcMuted) _togglePcMute();
                                      _setPcVolume(v.round());
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Audio device selector — Windows 11 style
                          if (_audioLoaded && _pcAudioDevices.isNotEmpty) ...[
                            const Divider(height: 1, color: AppColors.separator, indent: 16, endIndent: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.surround_sound_rounded, color: AppColors.secondaryLabel, size: 16),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Output Device',
                                        style: TextStyle(
                                          color: AppColors.label,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ..._pcAudioDevices.map((dev) {
                                    final isCurrent = dev.id == _activePcAudioDeviceId;
                                    final devIcon = _getAudioDeviceIcon(dev.type);
                                    final devSubtitle = _getAudioDeviceSubtitle(dev.type);

                                    return GestureDetector(
                                      onTap: isCurrent ? null : () => _switchPcAudioDevice(dev.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                        margin: const EdgeInsets.only(bottom: 2),
                                        decoration: BoxDecoration(
                                          color: isCurrent
                                              ? AppColors.blue.withValues(alpha: 0.1)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: isCurrent
                                                    ? AppColors.blue.withValues(alpha: 0.12)
                                                    : AppColors.separator.withValues(alpha: 0.3),
                                              ),
                                              child: Icon(devIcon, color: isCurrent ? AppColors.blue : AppColors.tertiaryLabel, size: 16),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    dev.name.length > 30 ? '${dev.name.substring(0, 27)}...' : dev.name,
                                                    style: TextStyle(
                                                      color: isCurrent ? AppColors.blue : AppColors.label,
                                                      fontSize: 13,
                                                      fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    devSubtitle,
                                                    style: TextStyle(
                                                      color: isCurrent
                                                          ? AppColors.blue.withValues(alpha: 0.7)
                                                          : AppColors.tertiaryLabel,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isCurrent)
                                              const Icon(Icons.check_circle_rounded, color: AppColors.blue, size: 16),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
      ],
    ),
    );
  }
}

// ============================================================
// ACTION GRID ITEM
// ============================================================

class _ActionGridItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _ActionGridItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: onTap != null ? AppColors.secondaryLabel : AppColors.quaternaryLabel,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              header: 'Getting Started',
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
              header: 'Tips',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    step.number,
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        color: AppColors.label,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.detail,
                      style: const TextStyle(
                        color: AppColors.secondaryLabel,
                        fontSize: 13,
                        height: 1.4,
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
            padding: EdgeInsets.only(left: 50),
            child: Divider(color: AppColors.separator, height: 0.5),
          ),
      ],
    );
  }
}
