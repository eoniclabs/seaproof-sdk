import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:seaproof/seaproof.dart';

import 'fake_api.dart';

void main() {
  final endpoint = Uri.parse('https://api.test');

  test('whoAmI returns the project and environment of the key', () async {
    final api = FakeApi(environment: 'production');
    final client = SeaproofClient(apiKey: 'sp_test_key_123456789', endpoint: endpoint, httpClient: api.client);

    final project = await client.whoAmI();

    expect(project.name, 'Shop app');
    expect(project.mode, SeaproofEnvironmentMode.production);
    expect(project.environmentName, 'Production');
    expect(api.requests.single.headers['X-Seaproof-Key'], 'sp_test_key_123456789');
  });

  test('a staging key from an older API is a tester environment', () async {
    final api = FakeApi(environment: 'staging');
    final client = SeaproofClient(apiKey: 'sp_test_key_123456789', endpoint: endpoint, httpClient: api.client);

    final project = await client.whoAmI();

    expect(project.mode, SeaproofEnvironmentMode.test);
    expect(project.environmentName, isNull);
  });

  test('a verified user is sent with the reporter calls, an unverified one is not', () async {
    final api = FakeApi();
    final client = SeaproofClient(apiKey: 'sp_test_key_123456789', endpoint: endpoint, httpClient: api.client)
      ..user = const SeaproofUser(id: 'kim@shop.example');
    await client.myFeedback('k' * 43);
    client.user = const SeaproofUser(id: 'kim@shop.example', userHash: 'abc123');
    await client.myFeedback('k' * 43);
    await client.whoAmI();

    final headers = api.requests.map((r) => r.headers).toList();
    expect(headers[0].containsKey('X-Seaproof-User'), isFalse, reason: 'no hash, nothing to prove');
    expect(headers[1]['X-Seaproof-User'], 'kim%40shop.example');
    expect(headers[1]['X-Seaproof-User-Hash'], 'abc123');
    expect(headers[2].containsKey('X-Seaproof-User'), isFalse, reason: 'only reporter calls');
  });

  test('whoAmI reads the branding and the logo comes as bytes', () async {
    final api = FakeApi()
      ..branding = {'primaryColor': '#0b6e99', 'logo': 'v1'}
      ..logo = [1, 2, 3];
    final client = SeaproofClient(apiKey: 'sp_test_key_123456789', endpoint: endpoint, httpClient: api.client);

    final branding = (await client.whoAmI()).branding;

    expect(branding.color, const Color(0xFF0B6E99));
    expect(await client.logo(branding.logoVersion!), [1, 2, 3]);
    expect(const SeaproofBranding(primaryColor: 'blue').color, isNull);
  });

  test('the reporter key goes only to the Seaproof API, with submit and the reporter calls', () async {
    final api = FakeApi()
      ..ideas = [
        {
          'id': 'i1',
          'title': 'Dark mode',
          'summary': null,
          'status': 'done',
          'votes': 2,
          'voted': true,
          'createdAt': '2026-10-21T10:00:00Z',
        },
      ];
    final client = SeaproofClient(apiKey: 'sp_test_key_123456789', endpoint: endpoint, httpClient: api.client);
    final key = 'k' * 43;

    await client.submit(
      FeedbackDraft(
        type: FeedbackType.bug,
        description: 'Broken',
        attachments: [
          FeedbackAttachment(
            kind: AttachmentKind.screenshot,
            fileName: 'screenshot.png',
            contentType: 'image/png',
            bytes: Uint8List.fromList([1]),
          ),
        ],
      ),
      const FeedbackContext(platform: 'flutter-ios'),
      reporterKey: key,
    );
    final ideas = await client.ideas(key);
    await client.unvote('i1', key);

    expect(api.requests.first.headers['X-Seaproof-Reporter'], key);
    expect(api.requests.singleWhere((r) => r.url.host == 'storage.test').headers['X-Seaproof-Reporter'], isNull);
    expect(ideas.single.status, PublicStatus.done);
    expect(ideas.single.withVote(value: false).votes, 1);
    expect(api.requests.last.method, 'DELETE');
    await expectLater(client.myFeedbackItem('nope', key), throwsA(isA<SeaproofException>()));
  });

  test('submit creates the item, uploads each attachment and marks it uploaded', () async {
    final api = FakeApi();
    final client = SeaproofClient(apiKey: 'sp_test_key_123456789', endpoint: endpoint, httpClient: api.client);

    final result = await client.submit(
      FeedbackDraft(
        type: FeedbackType.idea,
        description: 'Save my cart',
        user: const SeaproofUser(id: 'u1', email: 'kim@example.test'),
        mayContact: true,
        attachments: [
          FeedbackAttachment(
            kind: AttachmentKind.screenshot,
            fileName: 'screenshot.png',
            contentType: 'image/png',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      ),
      const FeedbackContext(platform: 'flutter-ios', commit: '9f2c1ab', custom: {'flavour': 'beta'}),
    );

    expect(result.number, 7);
    final body = api.submissions.single;
    expect(body['type'], 'idea');
    expect(body['reporter'], {'externalId': 'u1', 'name': null, 'email': 'kim@example.test', 'mayContact': true});
    expect((body['context']! as Map)['custom'], {'flavour': 'beta'});
    expect((body['context']! as Map)['commit'], '9f2c1ab');
    expect(body['attachments'], [
      {'kind': 'screenshot', 'fileName': 'screenshot.png', 'contentType': 'image/png', 'sizeBytes': 3},
    ]);

    final put = api.requests.singleWhere((r) => r.method == 'PUT');
    expect(put.url.host, 'storage.test');
    expect(put.headers['X-Seaproof-Key'], isNull, reason: 'the key must not leak to storage');
    expect(put.bodyBytes, [1, 2, 3]);
    expect(api.requests.last.url.path, '/api/v1/sdk/feedback/f1/attachments/a0/uploaded');
  });

  test('a failed upload keeps the report and lists the attachment', () async {
    final api = FakeApi(failUploads: true);
    final client = SeaproofClient(apiKey: 'sp_test_key_123456789', endpoint: endpoint, httpClient: api.client);
    final screenshot = FeedbackAttachment(
      kind: AttachmentKind.screenshot,
      fileName: 'screenshot.png',
      contentType: 'image/png',
      bytes: Uint8List.fromList([1]),
    );

    final result = await client.submit(
      FeedbackDraft(type: FeedbackType.bug, description: 'Crash', attachments: [screenshot]),
      const FeedbackContext(),
    );

    expect(result.number, 7);
    expect(result.failedUploads, [screenshot]);
    expect(api.requests.where((r) => r.url.path.endsWith('/uploaded')), isEmpty);
  });

  test('errors carry the problem code', () async {
    final api = FakeApi(failSubmit: true);
    final client = SeaproofClient(apiKey: 'sp_test_key_123456789', endpoint: endpoint, httpClient: api.client);

    await expectLater(
      client.submit(const FeedbackDraft(type: FeedbackType.bug, description: ''), const FeedbackContext()),
      throwsA(
        isA<SeaproofException>()
            .having((e) => e.code, 'code', 'feedback.description_invalid')
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.helpUrl, 'helpUrl', 'https://seaproof.io/docs/errors#feedback.description_invalid'),
      ),
    );
  });

  test('rejects something that is not an API key', () {
    expect(() => SeaproofClient(apiKey: 'secret'), throwsArgumentError);
  });
}
