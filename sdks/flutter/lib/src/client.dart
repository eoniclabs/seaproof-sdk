import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Talks to the Seaproof API with a project API key. Has no Flutter dependency.
final class SeaproofClient {
  /// Creates a client. Pass [httpClient] to share connections or to test.
  SeaproofClient({
    required this.apiKey,
    Uri? endpoint,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : endpoint = endpoint ?? defaultEndpoint,
       _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null {
    if (!apiKey.startsWith('sp_')) {
      throw ArgumentError.value(apiKey, 'apiKey', 'A Seaproof API key starts with "sp_".');
    }
  }

  /// The hosted Seaproof API.
  static final Uri defaultEndpoint = Uri.parse('https://api.seaproof.io');

  /// The project API key (`sp_...`).
  final String apiKey;

  /// Base address of the API.
  final Uri endpoint;

  /// Time allowed for each request.
  final Duration timeout;

  final http.Client _http;
  final bool _ownsHttp;

  /// The header that carries the installation's reporter key (a random secret per installation).
  static const reporterKeyHeader = 'X-Seaproof-Reporter';

  Map<String, String> get _headers => {'X-Seaproof-Key': apiKey, 'Accept': 'application/json'};

  /// The signed-in user. With an id and a [SeaproofUser.userHash], their conversations and
  /// votes are shared by all their devices; see `Seaproof.identify`.
  SeaproofUser? user;

  Map<String, String> _reporterHeaders(String reporterKey) => {
    ..._headers,
    reporterKeyHeader: reporterKey,
    if (user case SeaproofUser(id: final id?, userHash: final hash?)) ...{
      'X-Seaproof-User': Uri.encodeComponent(id),
      'X-Seaproof-User-Hash': hash,
    },
  };

  /// The project and environment of the key.
  Future<SeaproofProject> whoAmI() async {
    final body = await _sendObject(() => _http.get(_uri('/api/v1/sdk/whoami'), headers: _headers));
    return SeaproofProject(
      id: body['projectId']! as String,
      name: body['projectName']! as String,
      mode: SeaproofEnvironmentMode.parse((body['mode'] ?? body['environment']) as String?),
      environmentId: body['environmentId'] as String?,
      environmentName: body['environmentName'] as String?,
      branding: switch (body['branding']) {
        final Map<String, Object?> b => SeaproofBranding(
          primaryColor: b['primaryColor'] as String?,
          logoVersion: b['logo'] as String?,
        ),
        _ => const SeaproofBranding(),
      },
      launcher: switch (body['launcher']) {
        final Map<String, Object?> value => SeaproofLauncherSettings.fromJson(value),
        _ => null,
      },
    );
  }

  /// The project's logo image (PNG, JPEG or WebP). [version] is
  /// [SeaproofBranding.logoVersion]; it keeps caches from serving an old logo.
  Future<Uint8List> logo(String version) async {
    final uri = _uri('/api/v1/sdk/branding/logo').replace(queryParameters: {'v': version});
    final http.Response response;
    try {
      response = await _http.get(uri, headers: {..._headers, 'Accept': 'image/*'}).timeout(timeout);
    } on TimeoutException {
      throw const SeaproofException('network.timeout', 'The Seaproof API did not answer in time.');
    } on http.ClientException catch (e) {
      throw SeaproofException('network.unavailable', e.message);
    }

    if (response.statusCode != 200) {
      throw SeaproofException(
        'branding.logo_unavailable',
        'The logo could not be fetched.',
        statusCode: response.statusCode,
      );
    }

    return response.bodyBytes;
  }

  /// Sends a report and uploads its attachments straight to storage.
  ///
  /// The report is created first, so it is not lost when an upload fails. Attachments that
  /// fail are listed in [SubmittedFeedback.failedUploads] instead of throwing, because
  /// sending again would create a duplicate report.
  ///
  /// With a [reporterKey], the user can later read the team's replies and answer them.
  Future<SubmittedFeedback> submit(FeedbackDraft draft, FeedbackContext context, {String? reporterKey}) async {
    final body = await _sendObject(
      () => _http.post(
        _uri('/api/v1/sdk/feedback'),
        headers: {
          ...(reporterKey == null ? _headers : _reporterHeaders(reporterKey)),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type': draft.type.name,
          'title': draft.title,
          'description': draft.description,
          'severity': draft.severity?.name,
          'linkedTo': draft.linkedTo,
          'reporter': draft.user?.toJson(mayContact: draft.mayContact) ?? {'mayContact': draft.mayContact},
          'context': context.toJson(),
          'attachments': [
            for (final a in draft.attachments)
              {'kind': a.kind.name, 'fileName': a.fileName, 'contentType': a.contentType, 'sizeBytes': a.bytes.length},
          ],
        }),
      ),
    );

    final id = body['id']! as String;
    final uploads = (body['uploads']! as List<Object?>).cast<Map<String, Object?>>();
    final failed = <FeedbackAttachment>[];
    for (var i = 0; i < uploads.length; i++) {
      try {
        await _upload(id, uploads[i], draft.attachments[i]);
      } on SeaproofException {
        failed.add(draft.attachments[i]);
      }
    }

    return SubmittedFeedback(id: id, number: (body['number']! as num).toInt(), failedUploads: failed);
  }

  /// Feedback sent with [reporterKey], newest first.
  Future<List<OwnFeedback>> myFeedback(String reporterKey) async {
    final body = await _send(() => _http.get(_uri('/api/v1/sdk/me/feedback'), headers: _reporterHeaders(reporterKey)));
    return [for (final item in _list(body)) OwnFeedback.fromJson(item)];
  }

  /// One item sent with [reporterKey], with the conversation.
  Future<OwnFeedbackDetail> myFeedbackItem(String id, String reporterKey) async {
    final body = await _sendObject(
      () => _http.get(_uri('/api/v1/sdk/me/feedback/$id'), headers: _reporterHeaders(reporterKey)),
    );
    return OwnFeedbackDetail.fromJson(body);
  }

  /// Answers the team about an item sent with [reporterKey].
  Future<ConversationMessage> sendMessage(String id, String body, String reporterKey) async {
    final json = await _sendObject(
      () => _http.post(
        _uri('/api/v1/sdk/me/feedback/$id/messages'),
        headers: {..._reporterHeaders(reporterKey), 'Content-Type': 'application/json'},
        body: jsonEncode({'body': body}),
      ),
    );
    return ConversationMessage.fromJson(json);
  }

  /// Adds files to an item sent with [reporterKey], such as a marked-up screenshot or a
  /// recording made after the report was saved. Returns the ones that failed to upload.
  /// Pass [messageId] when the files accompany a reply.
  Future<List<FeedbackAttachment>> addAttachments(
    String id,
    List<FeedbackAttachment> attachments,
    String reporterKey, {
    String? messageId,
  }) async {
    final body = await _sendObject(
      () => _http.post(
        _uri('/api/v1/sdk/me/feedback/$id/attachments'),
        headers: {..._reporterHeaders(reporterKey), 'Content-Type': 'application/json'},
        body: jsonEncode({
          'messageId': ?messageId,
          'attachments': [
            for (final a in attachments)
              {'kind': a.kind.name, 'fileName': a.fileName, 'contentType': a.contentType, 'sizeBytes': a.bytes.length},
          ],
        }),
      ),
    );
    final uploads = (body['uploads']! as List<Object?>).cast<Map<String, Object?>>();
    final failed = <FeedbackAttachment>[];
    for (var i = 0; i < uploads.length; i++) {
      try {
        await _upload(id, uploads[i], attachments[i]);
      } on SeaproofException {
        failed.add(attachments[i]);
      }
    }

    return failed;
  }

  /// The project's published ideas, most voted first, with whether [reporterKey] voted.
  Future<List<PublicIdea>> ideas(String reporterKey) async {
    final body = await _send(() => _http.get(_uri('/api/v1/sdk/ideas'), headers: _reporterHeaders(reporterKey)));
    return [for (final idea in _list(body)) PublicIdea.fromJson(idea)];
  }

  /// Votes for a published idea. Voting twice counts once.
  Future<void> vote(String ideaId, String reporterKey) =>
      _send(() => _http.put(_uri('/api/v1/sdk/ideas/$ideaId/vote'), headers: _reporterHeaders(reporterKey)));

  /// Takes the vote back.
  Future<void> unvote(String ideaId, String reporterKey) =>
      _send(() => _http.delete(_uri('/api/v1/sdk/ideas/$ideaId/vote'), headers: _reporterHeaders(reporterKey)));

  /// What Seaproof Assist offers in this project. Everything off when it cannot be fetched.
  Future<AssistSettings> assistSettings() async {
    try {
      return AssistSettings.fromJson(await _sendObject(() => _http.get(_uri('/api/v1/sdk/assist'), headers: _headers)));
    } on SeaproofException {
      return AssistSettings.off;
    }
  }

  /// Known problems and public ideas like [text], best first. Empty for short texts.
  Future<List<Suggestion>> suggest(String text, {FeedbackType? type, String? reporterKey}) async {
    final body = await _send(
      () => _http.post(
        _uri('/api/v1/sdk/assist/suggestions'),
        headers: {
          ...(reporterKey == null ? _headers : _reporterHeaders(reporterKey)),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'text': text, 'type': type?.name}),
      ),
    );
    return [for (final item in _list(body)) Suggestion.fromJson(item)];
  }

  /// Asks what a draft is missing. Never throws: on any failure there are simply no questions.
  ///
  /// Pass the same [conversationId] (from [newConversationId]) for every call about one draft,
  /// so they count as one Assist conversation against the plan's monthly quota.
  Future<ReviewResult> review(
    FeedbackType type,
    String description, {
    String? reporterKey,
    String? conversationId,
    String? feedbackId,
  }) async {
    try {
      return ReviewResult.fromJson(
        await _sendObject(
          () => _http.post(
            _uri('/api/v1/sdk/assist/review'),
            headers: {
              ...(reporterKey == null ? _headers : _reporterHeaders(reporterKey)),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'type': type.name,
              'description': description,
              'conversationId': ?conversationId,
              'feedbackId': ?feedbackId,
            }),
          ),
        ),
      );
    } on SeaproofException {
      return const ReviewResult();
    }
  }

  /// Records the question before showing it in the widget.
  Future<bool> recordAssistQuestion(String feedbackId, String receipt, String reporterKey) async {
    try {
      await _send(
        () => _http.post(
          _uri('/api/v1/sdk/assist/questions/shown'),
          headers: {..._reporterHeaders(reporterKey), 'Content-Type': 'application/json'},
          body: jsonEncode({'feedbackId': feedbackId, 'receipt': receipt}),
        ),
      );
      return true;
    } on SeaproofException {
      return false;
    }
  }

  /// Closes the HTTP client if this instance created it.
  void close() {
    if (_ownsHttp) {
      _http.close();
    }
  }

  Future<void> _upload(String feedbackId, Map<String, Object?> instruction, FeedbackAttachment attachment) async {
    final attachmentId = instruction['attachmentId']! as String;
    final request = http.Request(instruction['method']! as String, Uri.parse(instruction['url']! as String))
      ..headers.addAll((instruction['headers']! as Map<String, Object?>).cast<String, String>())
      ..bodyBytes = attachment.bytes;
    try {
      final response = await _http.send(request).timeout(timeout);
      await response.stream.drain<void>();
      if (response.statusCode >= 300) {
        throw SeaproofException(
          'attachment.upload_failed',
          'Upload of ${attachment.fileName} failed with ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw SeaproofException('attachment.upload_failed', 'Upload of ${attachment.fileName} timed out.');
    } on http.ClientException catch (e) {
      throw SeaproofException('attachment.upload_failed', 'Upload of ${attachment.fileName} failed: ${e.message}');
    }

    await _send(
      () => _http.post(_uri('/api/v1/sdk/feedback/$feedbackId/attachments/$attachmentId/uploaded'), headers: _headers),
    );
  }

  Uri _uri(String path) => endpoint.resolve(path);

  static List<Map<String, Object?>> _list(Object? body) => (body! as List<Object?>).cast<Map<String, Object?>>();

  Future<Map<String, Object?>> _sendObject(Future<http.Response> Function() call) async =>
      (await _send(call))! as Map<String, Object?>;

  /// The decoded JSON body, or null when there is none.
  Future<Object?> _send(Future<http.Response> Function() call) async {
    final http.Response response;
    try {
      response = await call().timeout(timeout);
    } on TimeoutException {
      throw const SeaproofException('network.timeout', 'The Seaproof API did not answer in time.');
    } on http.ClientException catch (e) {
      throw SeaproofException('network.unavailable', e.message);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }

    // Errors are RFC 9457 problem details with a stable "code" extension.
    var code = 'http.${response.statusCode}';
    var message = response.reasonPhrase ?? 'Request failed.';
    String? helpUrl;
    try {
      final problem = jsonDecode(response.body) as Map<String, Object?>;
      code = problem['code'] as String? ?? code;
      message = problem['detail'] as String? ?? problem['title'] as String? ?? message;
      final type = problem['type'] as String?;
      if (type != null && type.startsWith(SeaproofException.errorReferenceUrl)) {
        helpUrl = type;
      }
    } on FormatException {
      // Not JSON; keep the status-based code.
    }

    throw SeaproofException(code, message, statusCode: response.statusCode, helpUrl: helpUrl);
  }
}

/// A new id for one draft's Assist conversation (a random version 4 UUID).
String newConversationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
