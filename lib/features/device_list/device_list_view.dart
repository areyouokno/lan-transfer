import 'package:flutter/material.dart';
import '../../core/models/device_info.dart';

class DeviceListView extends StatelessWidget {
  final List<DeviceInfo> devices;
  final void Function(DeviceInfo device) onDeviceTap;

  const DeviceListView({
    super.key,
    required this.devices,
    required this.onDeviceTap,
  });

  IconData _iconForPlatform(String platform) {
    switch (platform) {
      case 'windows':
        return Icons.desktop_windows;
      case 'macos':
        return Icons.laptop_mac;
      case 'ios':
        return Icons.phone_iphone;
      case 'android':
        return Icons.phone_android;
      default:
        return Icons.devices_other;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_find, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                '正在搜索局域网内的设备...\n请确保其他设备已打开本应用并连接同一WiFi',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return ListTile(
          leading: Icon(_iconForPlatform(device.platform), size: 32),
          title: Text(device.name),
          subtitle: Text('${device.platform} · ${device.ip}'),
          trailing: const Icon(Icons.send),
          onTap: () => onDeviceTap(device),
        );
      },
    );
  }
}
