import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// What a [DiagnosticEntry] records.
enum DiagnosticKind {
  /// A line from [Seaproof.log].
  log,

  /// Console output: `debugPrint`, or `print` inside [Seaproof.runZoned].
  console,

  /// An HTTP request made through [SeaproofHttpClient] or [Seaproof.recordRequest].
  network,

  /// An uncaught error.
  error,
}

/// One line in the diagnostics attached to a report.
final class DiagnosticEntry {
  /// Creates an entry.
  const DiagnosticEntry({required this.time, required this.kind, required this.message, this.data = const {}});

  /// When it happened, in UTC.
  final DateTime time;

  /// What it is.
  final DiagnosticKind kind;

  /// A one-line summary.
  final String message;

  /// Details: for network entries method, url, status and duration; for errors the stack.
  final Map<String, Object?> data;

  /// One NDJSON line. The admin reads `t`, `kind` and `message`; the rest is shown as details.
  Map<String, Object?> toJson() => {'t': time.toIso8601String(), 'kind': kind.name, 'message': message, ...data};
}

/// The most recent diagnostics, attached to tester reports as `diagnostics.ndjson`.
///
/// Nothing is sent on its own: entries only leave the device inside a report.
final class Diagnostics {
  /// Creates a buffer that keeps the last [capacity] entries.
  Diagnostics({this.capacity = 500, DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Entries kept before the oldest are dropped.
  final int capacity;

  /// Longest message kept; longer ones are cut.
  static const int maxMessageLength = 2000;

  final DateTime Function() _now;
  final Queue<DiagnosticEntry> _entries = Queue();

  /// Whether nothing has been recorded.
  bool get isEmpty => _entries.isEmpty;

  /// The entries, oldest first.
  List<DiagnosticEntry> get entries => List.unmodifiable(_entries);

  /// Records an entry.
  void add(DiagnosticKind kind, String message, [Map<String, Object?> data = const {}]) {
    final text = message.length <= maxMessageLength ? message : '${message.substring(0, maxMessageLength)}…';
    _entries.addLast(DiagnosticEntry(time: _now().toUtc(), kind: kind, message: text, data: data));
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
  }

  /// The buffer as newline-delimited JSON, oldest first.
  Uint8List toNdjson() => utf8.encode(_entries.map((e) => jsonEncode(e.toJson())).join('\n'));

  /// Removes all entries.
  void clear() => _entries.clear();
}

/// The URL with query values replaced by `*`, so tokens and personal data in query strings
/// are not recorded. Keys stay, as they help debugging.
String redactUrl(Uri url) => url.hasQuery
    ? url
          .replace(query: url.queryParametersAll.keys.map((k) => '${Uri.encodeQueryComponent(k)}=*').join('&'))
          .toString()
    : url.toString();
