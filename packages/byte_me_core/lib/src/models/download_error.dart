/// Encapsulates information about a failed download attempt.
///
/// This provides a human-readable message and optionally includes the
/// underlying exception and stack trace that caused the failure.
class DownloadError {
  /// A human-readable description of what went wrong.
  final String message;

  /// The underlying exception that triggered the error, if available.
  final Object? exception;

  /// The stack trace associated with the [exception], if available.
  final StackTrace? stackTrace;

  const DownloadError({
    required this.message,
    this.exception,
    this.stackTrace,
  });

  @override
  String toString() => 'DownloadError: $message';
}