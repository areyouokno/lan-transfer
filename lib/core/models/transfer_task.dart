/// 单次文件传输任务的状态，用于UI展示进度
enum TransferDirection { sending, receiving }

enum TransferStatus { pending, inProgress, completed, failed, rejected }

class TransferTask {
  final String id;
  final String fileName;
  final int totalBytes;
  final TransferDirection direction;
  final String peerName; // 对端设备名称

  int transferredBytes;
  TransferStatus status;
  String? errorMessage;

  TransferTask({
    required this.id,
    required this.fileName,
    required this.totalBytes,
    required this.direction,
    required this.peerName,
    this.transferredBytes = 0,
    this.status = TransferStatus.pending,
    this.errorMessage,
  });

  double get progress =>
      totalBytes == 0 ? 0 : transferredBytes / totalBytes;
}
