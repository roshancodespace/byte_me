import 'dart:io';

import 'download_error.dart';

/// Represents the final outcome of a download task.
///
/// A result is either a success containing the downloaded [file],
/// or a failure containing the [error] that occurred.
class DownloadResult {
  /// Whether the download completed successfully.
  final bool isSuccess;

  /// The successfully downloaded file. Null if the download failed.
  final File? file;

  /// The error that caused the download to fail. Null if successful.
  final DownloadError? error;

  const DownloadResult._({required this.isSuccess, this.file, this.error});

  /// Factory for a successful download
  factory DownloadResult.success(File file) {
    return DownloadResult._(isSuccess: true, file: file);
  }

  /// Factory for a failed download
  factory DownloadResult.failure(DownloadError error) {
    return DownloadResult._(isSuccess: false, error: error);
  }
}
