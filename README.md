# 局域网文件传输 - Flutter 工程骨架

## 这是什么

一个可在 Windows 上运行演示的 Flutter 工程骨架，包含：
- 设备发现（mDNS风格组播，自定义简化协议）
- 单文件发送/接收 + 进度条 UI
- 接收前的"接受/拒绝"确认弹窗

用于团队后续在四端（Win/macOS/iOS/Android）展开开发的基础结构。

## 运行步骤

```bash
# 1. 安装依赖
flutter pub get

# 2. 在Windows上运行（需要先 flutter config --enable-windows-desktop 并安装好桌面开发组件）
flutter run -d windows

# 同时在另一台设备（或同一台机器开两个实例）运行，
# 应该能在"设备"标签页看到对方，点击设备即可选择文件发送
```

## 项目结构

```
lib/
├── core/
│   ├── identity/
│   │   └── device_identity.dart      # 设备ID/名称持久化（SharedPreferences）
│   ├── discovery/
│   │   └── discovery_service.dart    # 设备发现：查询+应答双向逻辑
│   ├── transfer/
│   │   ├── transfer_server.dart      # 接收方：HTTP Server
│   │   └── transfer_client.dart      # 发送方：HTTP Client
│   └── models/
│       ├── device_info.dart
│       └── transfer_task.dart
├── features/
│   ├── home/
│   │   └── home_page.dart            # 主页面，串联所有模块
│   ├── device_list/
│   │   └── device_list_view.dart     # 设备列表UI
│   └── transfer_progress/
│       └── transfer_progress_view.dart  # 传输进度UI
└── main.dart
```

## 重要：已知简化与限制（团队接手前必读）

这套代码是"打通整条链路"的骨架，以下几点是**有意简化**的，不代表生产可用：

### 1. 发现协议不是标准mDNS报文格式
`discovery_service.dart` 里用 224.0.0.251:5353 这个mDNS组播信道，但实际收发的是自定义JSON文本，而不是标准DNS二进制报文（PTR/SRV/TXT/A记录的字节编码）。
- **好处**：代码直观、易调试，自己的四端App互相发现完全没问题
- **代价**：不是真正的mDNS协议，无法与系统级Bonjour/其他厂商的mDNS服务互通
- 如果产品需求中不需要与第三方mDNS生态互通，可以保留现状；否则需要替换为标准报文解析（可参考 `multicast_dns` 包内部的解码逻辑，或引入 `nsd`/`bonsoir` 等更完整的封装包）

### 2. 安全机制未实现
- 当前没有传输内容加密（HTTPS/AES），局域网内的传输是明文HTTP
- 没有设备白名单/黑名单机制
- 生产环境建议至少加上：自签名证书+HTTPS，或应用层AES加密

### 3. 传输能力的边界
- 只支持单文件发送，未实现多文件队列、断点续传
- 没有文件传输的MD5/SHA256校验
- 大文件（GB级别）未做特别优化测试

### 4. 各平台权限未配置
本骨架未包含以下平台特定配置，正式开发前需要补上：
- **iOS**：`Info.plist` 中添加 `NSLocalNetworkUsageDescription`（本地网络权限说明文案）和 `NSBonjourServices`
- **Android**：`AndroidManifest.xml` 添加 `ACCESS_WIFI_STATE`、`CHANGE_WIFI_MULTICAST_STATE` 权限，并在代码里通过 `WifiManager.MulticastLock` 获取多播锁（当前未做，Android上mDNS组播可能收不到包）
- **macOS**：`.entitlements` 文件需要添加本地网络权限和沙盒文件访问权限
- **Windows**：首次运行需要用户允许防火墙弹窗（专用网络通信）

### 5. 未经实机验证
本代码在没有Flutter SDK的环境下编写完成，**未执行过 `flutter pub get` / `flutter run` 进行实际编译验证**。已对所有文件做了人工逐项核对（import路径、方法签名、回调类型匹配），但仍可能存在：
- 第三方包（`network_info_plus`、`file_picker`、`shelf_router`）的具体API在最新版本中可能有出入
- Windows桌面端特有的编译问题（比如Windows平台缺少某些Linux/macOS专属API的条件处理）

**建议团队拿到代码后第一件事是跑一次 `flutter pub get` && `flutter run -d windows`，把遇到的报错反馈回来，可以针对性快速修复。**

## 下一步建议

1. 先在Windows单机上跑通UI（哪怕收不到真实设备，至少页面能正常渲染）
2. 用两台真机（或两个模拟器/虚拟机）验证发现+传输的完整链路
3. 补齐Android/iOS的权限配置
4. 评估是否需要把简化的发现协议换成标准mDNS报文格式
5. 加上传输加密
