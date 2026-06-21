import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 负责生成并持久化本机设备的唯一身份（id、显示名称）
/// 避免每次启动应用都生成新的设备id，导致"信任设备"之类的功能失效
class DeviceIdentity {
  static const _kIdKey = 'device_id';
  static const _kNameKey = 'device_name';

  static Future<String> getOrCreateId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_kIdKey, id);
    }
    return id;
  }

  static Future<String> getOrCreateName() async {
    final prefs = await SharedPreferences.getInstance();
    var name = prefs.getString(_kNameKey);
    if (name == null) {
      name = _defaultName();
      await prefs.setString(_kNameKey, name);
    }
    return name;
  }

  static Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNameKey, name);
  }

  static String _defaultName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return '未知设备';
    }
  }

  static String currentPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
