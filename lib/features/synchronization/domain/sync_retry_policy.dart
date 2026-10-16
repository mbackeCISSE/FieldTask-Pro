class SyncRetryPolicy {
  const SyncRetryPolicy({this.maxAttempts = 5});
  final int maxAttempts;

  bool shouldRetry({required int attempt, int? statusCode}) {
    if (attempt >= maxAttempts) return false;
    if (statusCode == null) return true; // Network or timeout error.
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  Duration delayAfter(int attempt) {
    if (attempt < 1 || attempt >= maxAttempts) {
      throw RangeError.range(attempt, 1, maxAttempts - 1, 'attempt');
    }
    return Duration(seconds: 1 << (attempt - 1));
  }
}
