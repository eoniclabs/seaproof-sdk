import 'package:http/http.dart' as http;

import 'controller.dart';
import 'diagnostics.dart';

/// An `http` client that records each request in the diagnostics: method, URL with query
/// values redacted, status, duration and response size. Bodies and headers are never recorded.
///
/// ```dart
/// final client = SeaproofHttpClient(http.Client());
/// ```
class SeaproofHttpClient extends http.BaseClient {
  /// Wraps [inner]. Records into [controller], or [Seaproof.instance] when null.
  SeaproofHttpClient(this._inner, {SeaproofController? controller}) : _controller = controller;

  final http.Client _inner;
  final SeaproofController? _controller;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final controller = _controller ?? (Seaproof.isInitialized ? Seaproof.instance : null);
    final watch = Stopwatch()..start();
    try {
      final response = await _inner.send(request);
      controller?.recordRequest(
        method: request.method,
        url: request.url,
        status: response.statusCode,
        duration: watch.elapsed,
        responseBytes: response.contentLength,
      );
      return response;
    } on Object catch (e) {
      controller?.recordRequest(method: request.method, url: request.url, duration: watch.elapsed, error: e.toString());
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}

/// Builds the diagnostics entry for a request. Shared by [SeaproofHttpClient] and
/// [SeaproofController.recordRequest].
(String, Map<String, Object?>) networkEntry({
  required String method,
  required Uri url,
  int? status,
  Duration? duration,
  int? responseBytes,
  String? error,
}) {
  final redacted = redactUrl(url);
  final summary =
      '$method $redacted → ${status ?? error ?? '?'}${duration == null ? '' : ' (${duration.inMilliseconds} ms)'}';
  return (
    summary,
    {
      'method': method,
      'url': redacted,
      'status': ?status,
      if (duration != null) 'durationMs': duration.inMilliseconds,
      'responseBytes': ?responseBytes,
      'error': ?error,
    },
  );
}
