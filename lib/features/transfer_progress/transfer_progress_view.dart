import 'package:flutter/material.dart';
import '../../core/models/transfer_task.dart';

class TransferProgressView extends StatelessWidget {
  final List<TransferTask> tasks;

  const TransferProgressView({super.key, required this.tasks});

  Color _statusColor(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
      case TransferStatus.rejected:
        return Colors.red;
      case TransferStatus.inProgress:
        return Colors.blue;
      case TransferStatus.pending:
        return Colors.grey;
    }
  }

  String _statusLabel(TransferStatus status) {
    switch (status) {
      case TransferStatus.pending:
        return '等待中';
      case TransferStatus.inProgress:
        return '传输中';
      case TransferStatus.completed:
        return '已完成';
      case TransferStatus.failed:
        return '失败';
      case TransferStatus.rejected:
        return '已拒绝';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text('暂无传输任务', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final directionIcon = task.direction == TransferDirection.sending
            ? Icons.upload
            : Icons.download;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(directionIcon, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.fileName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      _statusLabel(task.status),
                      style: TextStyle(
                        color: _statusColor(task.status),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: task.progress.clamp(0.0, 1.0),
                  color: _statusColor(task.status),
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.direction == TransferDirection.sending ? "发送到" : "来自"} '
                  '${task.peerName} · '
                  '${_formatBytes(task.transferredBytes)} / ${_formatBytes(task.totalBytes)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (task.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      task.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
