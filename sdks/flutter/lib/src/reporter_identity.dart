import 'dart:convert';
import 'dart:math';

import 'models.dart';
import 'storage.dart';

/// Identifies this installation to Seaproof, so the user can read replies to their own
/// feedback and vote, without an account. The project API key ships inside the app and cannot
/// do that; this random secret is only ever sent to the Seaproof API.
final class ReporterIdentity {
  /// Creates an identity kept in [storage].
  ReporterIdentity(this._storage);

  static const _keyName = 'seaproof.reporter-key';
  static const _seenName = 'seaproof.seen-replies';

  final SeaproofStorage _storage;
  Future<String>? _key;
  Map<String, DateTime> _seen = {};

  /// The installation's key, created and stored on first use. Also loads the read markers.
  /// A failure, such as unavailable storage, is retried on the next call.
  Future<String> key() async {
    final pending = _key ??= _load();
    try {
      return await pending;
    } on Object {
      if (identical(_key, pending)) {
        _key = null;
      }

      rethrow;
    }
  }

  /// Whether [item] has a reply the user has not opened yet. Accurate once [key] completed.
  bool isUnread(OwnFeedback item) {
    final last = item.lastReplyAt;
    if (last == null) {
      return false;
    }

    final seen = _seen[item.id];
    return seen == null || seen.isBefore(last);
  }

  /// Remembers that the replies up to [lastReplyAt] were read. Returns whether they were
  /// unread until now.
  Future<bool> markSeen(String id, DateTime lastReplyAt) async {
    final seen = _seen[id];
    if (seen != null && !seen.isBefore(lastReplyAt)) {
      return false;
    }

    _seen = {..._seen, id: lastReplyAt};
    await _storage.write(_seenName, jsonEncode({for (final e in _seen.entries) e.key: e.value.toIso8601String()}));
    return true;
  }

  Future<String> _load() async {
    try {
      final seen = await _storage.read(_seenName);
      if (seen != null) {
        _seen = {
          for (final e in (jsonDecode(seen) as Map<String, Object?>).entries) e.key: ?DateTime.tryParse('${e.value}'),
        };
      }
    } on FormatException {
      _seen = {};
    }

    final existing = await _storage.read(_keyName);
    if (existing != null) {
      return existing;
    }

    final random = Random.secure();
    final key = base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256))).replaceAll('=', '');
    await _storage.write(_keyName, key);
    return key;
  }
}
