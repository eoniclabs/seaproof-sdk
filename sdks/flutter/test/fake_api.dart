import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An in-memory Seaproof API that records what the SDK sends.
final class FakeApi {
  FakeApi({this.environment = 'test', this.failSubmit = false, this.failUploads = false});

  String environment;
  bool failSubmit;
  bool failUploads;
  final List<http.Request> requests = [];

  /// Returned by GET /me/feedback.
  List<Map<String, Object?>> ownFeedback = [];

  /// Returned by GET /me/feedback/{id}, by id.
  Map<String, Map<String, Object?>> ownFeedbackDetails = {};

  /// Returned by GET /ideas.
  List<Map<String, Object?>> ideas = [];

  /// Returned as whoami's branding.
  Map<String, Object?>? branding;

  /// Returned as whoami's launcher settings.
  Map<String, Object?>? launcher;

  /// Returned by GET /branding/logo.
  List<int>? logo;

  /// Returned by GET /assist.
  Map<String, Object?> assist = {'suggestions': false, 'followUpQuestions': false};

  /// Returned by POST /assist/suggestions.
  List<Map<String, Object?>> suggestions = [];

  /// Returned by POST /assist/review.
  List<String> questions = [];
  List<String>? questionReceipts;

  /// Make vote calls fail.
  bool failVotes = false;

  /// The reporter keys the SDK sent, in order.
  List<String?> get reporterKeys => [for (final r in requests) r.headers['X-Seaproof-Reporter']];

  /// Bodies of POST /me/feedback/{id}/messages, in order.
  List<String> get messages => [
    for (final r in requests)
      if (r.method == 'POST' && r.url.path.endsWith('/messages'))
        (jsonDecode(r.body) as Map<String, Object?>)['body']! as String,
  ];

  /// Bodies of POST /me/feedback/{id}/attachments, in order.
  List<Map<String, Object?>> get addedAttachments => [
    for (final r in requests)
      if (r.method == 'POST' &&
          r.url.path.startsWith('/api/v1/sdk/me/feedback/') &&
          r.url.path.endsWith('/attachments'))
        jsonDecode(r.body) as Map<String, Object?>,
  ];

  List<Map<String, Object?>> get submissions => [
    for (final r in requests)
      if (r.method == 'POST' && r.url.path == '/api/v1/sdk/feedback') jsonDecode(r.body) as Map<String, Object?>,
  ];

  late final http.Client client = MockClient((request) async {
    requests.add(request);
    if (request.headers['X-Seaproof-Key'] == null && request.url.host != 'storage.test') {
      return _json(401, {'code': 'sdk.key_required', 'title': 'A project API key is required.'});
    }

    final reporter = request.headers['X-Seaproof-Reporter'];
    final path = request.url.path;
    if (path.contains('/sdk/me/') || path.contains('/sdk/ideas')) {
      if (reporter == null) {
        return _json(400, {'code': 'reporter.key_required', 'title': 'A reporter key is required.'});
      }
    }

    return switch ((request.method, path)) {
      ('GET', '/api/v1/sdk/me/feedback') => _json(200, ownFeedback),
      ('GET', final p) when p.startsWith('/api/v1/sdk/me/feedback/') => switch (ownFeedbackDetails[p.split('/').last]) {
        final detail? => _json(200, detail),
        null => _json(404, {'code': 'feedback.not_found', 'title': 'Not found.'}),
      },
      ('POST', final p) when p.endsWith('/messages') => _json(201, {
        'id': 'm${requests.length}',
        'from': 'you',
        'body': (jsonDecode(request.body) as Map<String, Object?>)['body'],
        'createdAt': '2026-10-21T12:00:00Z',
      }),
      ('POST', final p) when p.startsWith('/api/v1/sdk/me/feedback/') && p.endsWith('/attachments') => _json(200, {
        'uploads': [
          for (final (i, _)
              in ((jsonDecode(request.body) as Map<String, Object?>)['attachments']! as List<Object?>).indexed)
            {
              'attachmentId': 'b$i',
              'method': 'PUT',
              'url': 'https://storage.test/bucket/b$i?X-Amz-Signature=x',
              'headers': {'Content-Type': 'image/png'},
              'expiresAt': '2030-01-01T00:00:00Z',
            },
        ],
      }),
      ('GET', '/api/v1/sdk/ideas') => _json(200, ideas),
      ('GET', '/api/v1/sdk/assist') => _json(200, assist),
      ('POST', '/api/v1/sdk/assist/suggestions') => _json(200, suggestions),
      ('POST', '/api/v1/sdk/assist/review') => _json(200, {
        'questions': questions,
        'questionReceipts': questionReceipts,
        'limited': false,
      }),
      ('POST', '/api/v1/sdk/assist/questions/shown') => http.Response('', 204),
      ('PUT' || 'DELETE', final p) when p.endsWith('/vote') =>
        failVotes ? _json(503, {'code': 'http.503', 'title': 'Unavailable.'}) : http.Response('', 204),
      ('GET', '/api/v1/sdk/whoami') => _json(200, {
        'projectId': 'p1',
        'projectName': 'Shop app',
        'organizationId': 'o1',
        'environment': environment,
        // An API from before named environments sent only `environment`, with `staging` among its values.
        if (environment != 'staging') ...{
          'mode': environment,
          'environmentId': 'e-$environment',
          'environmentName': environment == 'production' ? 'Production' : 'QA',
        },
        'branding': branding ?? {'primaryColor': null, 'logo': null},
        'launcher': ?launcher,
      }),
      ('GET', '/api/v1/sdk/branding/logo') => switch (logo) {
        final bytes? => http.Response.bytes(bytes, 200, headers: {'content-type': 'image/png'}),
        null => _json(404, {'code': 'branding.logo_not_found', 'title': 'No logo.'}),
      },
      ('POST', '/api/v1/sdk/feedback') when failSubmit => _json(400, {
        'code': 'feedback.description_invalid',
        'title': 'The request is not valid.',
        'detail': 'A description of 1-10000 characters is required.',
      }),
      ('POST', '/api/v1/sdk/feedback') => _json(201, {
        'id': 'f1',
        'number': 7,
        'uploads': [
          for (final (i, _)
              in ((jsonDecode(request.body) as Map<String, Object?>)['attachments']! as List<Object?>).indexed)
            {
              'attachmentId': 'a$i',
              'method': 'PUT',
              'url': 'https://storage.test/bucket/a$i?X-Amz-Signature=x',
              'headers': {'Content-Type': 'image/png'},
              'expiresAt': '2030-01-01T00:00:00Z',
            },
        ],
      }),
      ('PUT', _) => http.Response('', failUploads ? 503 : 200),
      ('POST', final path) when path.endsWith('/uploaded') => http.Response('', 204),
      _ => http.Response('not found', 404),
    };
  });

  static http.Response _json(int status, Object body) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
}
