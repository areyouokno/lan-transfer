import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/device_info.dart';
import '../models/transfer_task.dart';

/// 自定义异常：对方拒绝了传输请求
class TransferRejectedException implements Exception {
  @override
  String toString() => '对方拒绝了文件传输';
}

/// 发送方逻辑：先发请求询问对方是否接受，对方同意后再实际上传文件流
class TransferClient {
  final DeviceInfo selfInfo;

  TransferClient(this.selfInfo);

  /// 发送一个文件给目标设备，progressCallback会随着上传进度持续调用
  Future<void> sendFile({
    required DeviceInfo target,
    required File file,
    required void Function(TransferTask task) onProgressUpdate,
  }) async {
    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();

    final task = TransferTask(
      id: 'pending',
      fileName: fileName,
      totalBytes: fileSize,
      direction: TransferDirection.sending,
      peerName: target.name,
      status: TransferStatus.pending,
    );
    onProgressUpdate(task);

    // 第一步：发起传输请求，等待对方确认
    final requestUrl = Uri.parse('${target.baseUrl}/transfer/request');
    final requestResp = await http
        .post(
          requestUrl,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'fileName': fileName,
            'fileSize': fileSize,
            'fromName': selfInfo.name,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (requestResp.statusCode == 403) {
      task.status = TransferStatus.rejected;
      onProgressUpdate(task);
      throw TransferRejectedException();
    }

    if (requestResp.statusCode != 200) {
      task.status = TransferStatus.failed;
      task.errorMessage = 'HTTP ${requestResp.statusCode}';
      onProgressUpdate(task);
      throw Exception('传输请求失败: ${requestResp.statusCode}');
    }

    final respData = jsonDecode(requestResp.body) as Map<String, dynamic>;
    final transferId = respData['transferId'] as String;

    // 第二步：对方同意后，把文件流PUT上去，同时上报进度
    final uploadUrl = Uri.parse('${target.baseUrl}/transfer/upload/$transferId');
    final fileStream = file.openRead();

    int sent = 0;
    final reportingStream = fileStream.map((chunk) {
      sent += chunk.length;
      task.transferredBytes = sent;
      task.status = TransferStatus.inProgress;
      onProgressUpdate(task);
      return chunk;
    });

    final request = http.StreamedRequest('PUT', uploadUrl)
      ..headers['content-type'] = 'application/octet-stream'
      ..headers['x-from-name'] = selfInfo.name
      ..contentLength = fileSize;

    unawaited(() async {
      await for (final chunk in reportingStream) {
        request.sink.add(chunk);
      }
      await request.sink.close();
    }());

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      task.status = TransferStatus.failed;
      task.errorMessage = 'HTTP ${streamedResponse.statusCode}: $responseBody';
      onProgressUpdate(task);
      throw Exception('文件上传失败: ${streamedResponse.statusCode}');
    }

    task.status = TransferStatus.completed;
    onProgressUpdate(task);
  }
}
