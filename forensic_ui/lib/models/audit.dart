class Audit {
  final String id;
  final String filename;
  final String sha256Hash;
  final String? previousHash;
  final DateTime uploadTime;
  final int fileSize;
  final String status;

  Audit({
    required this.id,
    required this.filename,
    required this.sha256Hash,
    required this.previousHash,
    required this.uploadTime,
    required this.fileSize,
    required this.status,
  });

  factory Audit.fromJson(Map<String, dynamic> j) {
    return Audit(
      id: (j['id'] ?? '').toString(),
      filename: (j['filename'] ?? '').toString(),
      sha256Hash: (j['sha256_hash'] ?? '').toString(),
      previousHash: j['previous_hash'] == null ? null : j['previous_hash'].toString(),
      uploadTime: DateTime.parse(j['upload_time'].toString()),
      fileSize: (j['file_size'] as num).toInt(),
      status: (j['status'] ?? '').toString(),
    );
  }
}
