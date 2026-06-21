import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/discovery/discovery_service.dart';
import '../../core/identity/device_identity.dart';
import '../../core/models/device_info.dart';
import '../../core/models/transfer_task.dart';
import '../../core/transfer/transfer_client.dart';
import '../../core/transfer/transfer_server.dart';
import '../device_list/device_list_view.dart';
import '../transfer_progress/transfer_progress_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DiscoveryService? _discovery;
  TransferServer? _server;
  TransferClient? _client;
  DeviceInfo? _selfInfo;

  List<DeviceInfo> _devices = [];
  final List<TransferTask> _tasks = [];

  bool _initializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final id = await DeviceIdentity.getOrCreateId();
      final name = await DeviceIdentity.getOrCreateName();
      final platform = DeviceIdentity.currentPlatform();

      // 接收的文件统一存到应用文档目录下的 LanTransfer 文件夹
      final docDir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${docDir.path}/LanTransfer');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 启动HTTP Server（接收方角色）
      final server = TransferServer(
        saveDirectory: saveDir.path,
        selfDeviceId: id,
        onIncomingRequest: _showIncomingRequestDialog,
        onProgressUpdate: _updateTask,
      );
      final boundPort = await server.start();

      // 获取局域网IP，用于让自己被发现
      final ip = await NetworkInfo().getWifiIP() ?? '0.0.0.0';

      final selfInfo = DeviceInfo(
        id: id,
        name: name,
        ip: ip,
        port: boundPort,
        platform: platform,
      );

      final discovery = DiscoveryService(selfInfo);
      await discovery.start();
      discovery.devicesStream.listen((devices) {
        if (mounted) setState(() => _devices = devices);
      });

      setState(() {
        _selfInfo = selfInfo;
        _discovery = discovery;
        _server = server;
        _client = TransferClient(selfInfo);
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _initError = e.toString();
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _discovery?.stop();
    _server?.stop();
    super.dispose();
  }

  /// 收到传输请求时弹出确认对话框，用户点击决定是否接受
  Future<bool> _showIncomingRequestDialog(
      String fileName, int fileSize, String fromName) async {
    if (!mounted) return false;
    final sizeStr = fileSize < 1024 * 1024
        ? '${(fileSize / 1024).toStringAsFixed(1)} KB'
        : '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('收到文件传输请求'),
        content: Text('$fromName 想要发送文件给你：\n$fileName ($sizeStr)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('接受'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _updateTask(TransferTask task) {
    if (!mounted) return;
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == task.id);
      if (idx >= 0) {
        _tasks[idx] = task;
      } else {
        _tasks.insert(0, task);
      }
    });
  }

  Future<void> _onDeviceTap(DeviceInfo device) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final client = _client;
    if (client == null) return;

    try {
      await client.sendFile(
        target: device,
        file: file,
        onProgressUpdate: _updateTask,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('初始化失败: $_initError', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('局域网传输 · ${_selfInfo?.name ?? ""}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '设备', icon: Icon(Icons.devices)),
              Tab(text: '传输记录', icon: Icon(Icons.swap_vert)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DeviceListView(devices: _devices, onDeviceTap: _onDeviceTap),
            TransferProgressView(tasks: _tasks),
          ],
        ),
      ),
    );
  }
}
