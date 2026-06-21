/// 局域网内一台被发现的设备
class DeviceInfo {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String platform; // windows / macos / ios / android / linux

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.platform,
  });

  String get baseUrl => 'http://$ip:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'port': port,
        'platform': platform,
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        ip: json['ip'] as String,
        port: json['port'] as int,
        platform: json['platform'] as String,
      );

  @override
  bool operator ==(Object other) => other is DeviceInfo && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name ($platform) @ $ip:$port';
}
