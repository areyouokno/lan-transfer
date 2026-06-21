import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/device_info.dart';

const String kServiceType = '_lantransfer._tcp.local';
const String kMulticastAddress = '224.0.0.251';
const int kMdnsPort = 5353;

/// 局域网设备发现服务。
/// 同时承担两个角色：
/// 1. 查询方：周期性发起mDNS查询，发现别的设备
/// 2. 应答方：监听别人的查询，回复自己的信息，让自己被发现
class DiscoveryService {
  final DeviceInfo selfInfo;

  final Map<String, DeviceInfo> _devices = {};
  final Map<String, DateTime> _lastSeen = {};
  final _devicesController = StreamController<List<DeviceInfo>>.broadcast();

  MDnsClient? _mdnsClient;
  RawDatagramSocket? _answerSocket;
  Timer? _queryTimer;
  Timer? _announceTimer;
  Timer? _cleanupTimer;

  bool _running = false;

  DiscoveryService(this.selfInfo);

  Stream<List<DeviceInfo>> get devicesStream => _devicesController.stream;
  List<DeviceInfo> get currentDevices => _devices.values.toList();

  Future<void> start() async {
    if (_running) return;
    _running = true;

    await _startAnswering();
    await _startQuerying();

    _announceTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _broadcastSelf());

    // 每5秒检查一次，超过30秒没收到应答的设备视为离线，从列表移除
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      final staleIds = _lastSeen.entries
          .where((e) => now.difference(e.value) > const Duration(seconds: 30))
          .map((e) => e.key)
          .toList();
      if (staleIds.isNotEmpty) {
        for (final id in staleIds) {
          _devices.remove(id);
          _lastSeen.remove(id);
        }
        _devicesController.add(_devices.values.toList());
      }
    });
  }

  Future<void> stop() async {
    _running = false;
    _queryTimer?.cancel();
    _announceTimer?.cancel();
    _cleanupTimer?.cancel();
    _mdnsClient?.stop();
    _answerSocket?.close();
    await _devicesController.close();
  }

  // ============ 查询方 ============

  Future<void> _startQuerying() async {
    _mdnsClient = MDnsClient();
    await _mdnsClient!.start();

    unawaited(_queryOnce());
    _queryTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _queryOnce());
  }

  Future<void> _queryOnce() async {
    final client = _mdnsClient;
    if (client == null) return;

    try {
      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(kServiceType))) {
        await for (final SrvResourceRecord srv in client
            .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName))) {
          String? deviceId;
          String? platform;
          String? displayName;

          await for (final TxtResourceRecord txt in client
              .lookup<TxtResourceRecord>(
                  ResourceRecordQuery.text(ptr.domainName))) {
            final parsed = _parseTxt(txt.text);
            deviceId = parsed['id'];
            platform = parsed['platform'];
            displayName = parsed['name'];
          }

          await for (final IPAddressResourceRecord ip in client
              .lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target))) {
            if (deviceId == null || deviceId == selfInfo.id) continue;

            final device = DeviceInfo(
              id: deviceId,
              name: displayName ?? srv.target,
              ip: ip.address.address,
              port: srv.port,
              platform: platform ?? 'unknown',
            );
            _registerDevice(device);
          }
        }
      }
    } catch (_) {
      // mDNS查询在某些网络环境下可能短暂失败，下一轮定时器会重试，这里不向上抛出
    }
  }

  Map<String, String> _parseTxt(String raw) {
    final map = <String, String>{};
    for (final line in raw.split('\n')) {
      final idx = line.indexOf('=');
      if (idx > 0) {
        map[line.substring(0, idx)] = line.substring(idx + 1);
      }
    }
    return map;
  }

  void _registerDevice(DeviceInfo device) {
    _devices[device.id] = device;
    _lastSeen[device.id] = DateTime.now();
    _devicesController.add(_devices.values.toList());
  }

  // ============ 应答方（手动实现，multicast_dns包不提供） ============

  Future<void> _startAnswering() async {
    try {
      _answerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        kMdnsPort,
        reuseAddress: true,
        reusePort: true,
      );
      _answerSocket!.joinMulticast(InternetAddress(kMulticastAddress));
      _answerSocket!.listen(_onSocketEvent);
    } on SocketException catch (e) {
      // 端口被占用等情况下，应答能力会缺失，但查询能力仍可用（只是自己不能被发现）
      // ignore: avoid_print
      print('警告：mDNS应答socket绑定失败，本机将无法被其他设备发现: $e');
    }
  }

  void _onSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final packet = _answerSocket?.receive();
    if (packet == null) return;

    try {
      final raw = utf8.decode(packet.data, allowMalformed: true);

      // 简化协议：约定收到的数据是我们自定义的JSON格式查询/应答包
      // 生产环境建议替换为标准DNS报文解析，见下方"已知简化"说明
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['service'] != kServiceType) return;

      final senderId = data['id'] as String?;
      if (senderId == selfInfo.id) return; // 忽略自己发的包

      if (data['type'] == 'query') {
        _broadcastSelf(); // 收到别人的查询，回应自己的信息
      } else if (data['type'] == 'announce' && senderId != null) {
        final device = DeviceInfo(
          id: senderId,
          name: data['name'] as String? ?? 'unknown',
          ip: packet.address.address,
          port: data['port'] as int? ?? 0,
          platform: data['platform'] as String? ?? 'unknown',
        );
        _registerDevice(device);
      }
    } catch (_) {
      // 收到的不是我们自定义协议的包（比如其他应用的mDNS流量），直接忽略
    }
  }

  void _broadcastSelf() {
    final payload = jsonEncode({
      'service': kServiceType,
      'type': 'announce',
      'id': selfInfo.id,
      'name': selfInfo.name,
      'platform': selfInfo.platform,
      'port': selfInfo.port,
    });
    _answerSocket?.send(
      utf8.encode(payload),
      InternetAddress(kMulticastAddress),
      kMdnsPort,
    );
  }
}
