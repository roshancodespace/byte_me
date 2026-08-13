import 'dart:math';

/// Defines the retry strategy for transient network failures.
class RetryConfig {
  /// The maximum number of retry attempts before failing permanently.
  final int maxRetries;

  /// The initial delay before the first retry attempt.
  final Duration baseDelay;

  /// Whether to add randomness (jitter) to the exponential backoff to prevent thundering herds.
  final bool useJitter;

  const RetryConfig({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.useJitter = true,
  });

  /// Calculates the delay for the current attempt (1-based index)
  Duration calculateDelay(int attempt) {
    if (attempt <= 1) return baseDelay;

    // Exponential backoff
    final exponentialDelay = baseDelay.inMilliseconds * pow(2, attempt - 1);

    if (!useJitter) {
      return Duration(milliseconds: exponentialDelay.toInt());
    }

    // Add jitter: randomize between 50% to 100% of exponential delay
    final random = Random();
    final jitterMultiplier = 0.5 + (random.nextDouble() * 0.5);
    final jitterDelay = exponentialDelay * jitterMultiplier;

    return Duration(milliseconds: jitterDelay.toInt());
  }
}
