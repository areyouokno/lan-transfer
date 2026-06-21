import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../models/transfer_task.dart';

/// 接收方在本机起的HTTP Server，负责：
/// 1. 接收发送方的"传输请求"（文件名+大小），交给UI弹出确认
/// 2. 接收方确认后，接收实际的文件二进制流并写入磁盘
class TransferServer {
  final String saveDirectory;
  final String selfDeviceId;

  /// 当收到新的传输请求时触发，UI层订阅这个回调来弹出确认对话框。
  /// 返回true代表用户同意接收，false代表拒绝。
  final Future<bool> Function(String fileName, int fileSize, String fromName)
      onIncomingRequest;

  /// 传输进度回调，UI层订阅来更新进度条
  final void Function(TransferTask task) onProgressUpdate;

  HttpServer? _server;
  int? _boundPort;

  // 已批准的传输：key是临时传输id，value是约定好的文件名（防止恶意路径穿越攻击）
  final Map<String, String> _approvedTransfers = {};

  TransferServer({
    required this.saveDirectory,
    required this.selfDeviceId,
    required this.onIncomingRequest,
    required this.onProgressUpdate,
  });

  int? get port => _boundPort;

  Future<int> start({int preferredPort = 8080}) async {
    final router = Router();

    router.post('/transfer/request', _handleTransferRequest);
    router.put('/transfer/upload/<transferId>', _handleUpload);

    final handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    // 端口可能被占用，尝试preferredPort，失败则让系统分配随机可用端口
    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, preferredPort);
    } catch (_) {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    }
    _boundPort = _server!.port;
    return _boundPort!;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }

  /// 发送方先调用这个接口，告知要传什么文件，等待接收方确认
  Future<Response> _handleTransferRequest(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final fileName = data['fileName'] as String;
    final fileSize = data['fileSize'] as int;
    final fromName = data['fromName'] as String? ?? '未知设备';

    final accepted = await onIncomingRequest(fileName, fileSize, fromName);

    if (!accepted) {
      return Response.forbidden(
        jsonEncode({'accepted': false}),
        headers: {'content-type': 'application/json'},
      );
    }

    // 生成一个传输id，发送方接下来用这个id上传实际文件流
    final transferId = DateTime.now().microsecondsSinceEpoch.toString();
    _approvedTransfers[transferId] = _sanitizeFileName(fileName);

    return Response.ok(
      jsonEncode({'accepted': true, 'transferId': transferId}),
      headers: {'content-type': 'application/json'},
    );
  }

  /// 发送方确认后，调用这个接口把文件二进制流PUT上来
  Future<Response> _handleUpload(Request request, String transferId) async {
    final fileName = _approvedTransfers[transferId];
    if (fileName == null) {
      return Response.forbidden('未授权的传输，请先调用/transfer/request');
    }

    final contentLength = request.contentLength ?? 0;
    final savePath = p.join(saveDirectory, fileName);
    final file = File(savePath);
    final sink = file.openWrite();

    final task = TransferTask(
      id: transferId,
      fileName: fileName,
      totalBytes: contentLength,
      direction: TransferDirection.receiving,
      peerName: request.headers['x-from-name'] ?? '未知设备',
      status: TransferStatus.inProgress,
    );
    onProgressUpdate(task);

    int received = 0;
    try {
      await for (final chunk in request.read()) {
        sink.add(chunk);
        received += chunk.length;
        task.transferredBytes = received;
        onProgressUpdate(task);
      }
      await sink.close();

      task.status = TransferStatus.completed;
      onProgressUpdate(task);

      _approvedTransfers.remove(transferId);
      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      await sink.close();
      task.status = TransferStatus.failed;
      task.errorMessage = e.toString();
      onProgressUpdate(task);

      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  /// 防止文件名包含路径穿越字符（比如 ../../etc/passwd）
  String _sanitizeFileName(String fileName) {
    final base = p.basename(fileName);
    return base.isEmpty ? 'unnamed_file' : base;
  }
}
