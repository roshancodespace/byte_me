/// Persistent state and tracking information for a download task.
///
/// This metadata can be serialized to JSON and saved locally (e.g. SQLite, Hive)
/// so downloads can be resumed after the application is restarted.
class DownloadMetadata {
  /// The unique identifier of the task this metadata belongs to.
  final String taskId;

  /// The original URL being downloaded.
  final String url;

  /// The absolute path on the local file system where the file is stored.
  final String destinationPath;

  /// The number of bytes successfully written to the destination so far.
  final int downloadedBytes;

  /// The total expected size of the file, if provided by the server.
  final int? totalBytes;

  /// The string representation of the [DownloadStatus].
  final String status;

  /// When this download was first initiated.
  final DateTime createdAt;

  /// When the status or progress was last updated.
  final DateTime updatedAt;

  /// The HTTP ETag from the server, useful for checking if the file changed.
  final String? eTag;

  /// The Last-Modified HTTP header from the server.
  final String? lastModified;

  const DownloadMetadata({
    required this.taskId,
    required this.url,
    required this.destinationPath,
    required this.downloadedBytes,
    this.totalBytes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.eTag,
    this.lastModified,
  });

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'url': url,
    'destinationPath': destinationPath,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'eTag': eTag,
    'lastModified': lastModified,
  };

  factory DownloadMetadata.fromJson(Map<String, dynamic> json) {
    return DownloadMetadata(
      taskId: json['taskId'] as String,
      url: json['url'] as String,
      destinationPath: json['destinationPath'] as String,
      downloadedBytes: json['downloadedBytes'] as int,
      totalBytes: json['totalBytes'] as int?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      eTag: json['eTag'] as String?,
      lastModified: json['lastModified'] as String?,
    );
  }
}
