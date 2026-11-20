// ignore_for_file: avoid_print, print is what Seaproof.runZoned records.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seaproof/seaproof.dart';
import 'package:seaproof/src/diagnostics.dart';

import 'fake_api.dart';

void main() {
  late FakeApi api;
  late SeaproofController controller;

  SeaproofController create(SeaproofConfig config) => SeaproofController(
    config,
    client: SeaproofClient(apiKey: config.apiKey, endpoint: Uri.parse('https://api.test'), httpClient: api.client),
    appVersion: () async => '1.0.0',
    deviceModel: () async => 'Google Pixel 8',
  );

  List<Map<String, Object?>> lines(Diagnostics d) => [
    for (final line in utf8.decode(d.toNdjson()).split('\n')) jsonDecode(line) as Map<String, Object?>,
  ];

  setUp(() {
    api = FakeApi();
    controller = create(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
  });
  tearDown(() => controller.dispose());

  test('the buffer keeps the newest entries as NDJSON', () {
    final diagnostics = Diagnostics(capacity: 2, now: () => DateTime.utc(2026, 10, 21, 12));
    diagnostics
      ..add(DiagnosticKind.log, 'one')
      ..add(DiagnosticKind.console, 'two')
      ..add(DiagnosticKind.error, 'three', {'stack': '#0 main'});

    expect(lines(diagnostics), [
      {'t': '2026-10-21T12:00:00.000Z', 'kind': 'console', 'message': 'two'},
      {'t': '2026-10-21T12:00:00.000Z', 'kind': 'error', 'message': 'three', 'stack': '#0 main'},
    ]);
  });

  test('query values are redacted, keys kept', () {
    expect(
      redactUrl(Uri.parse('https://shop.test/search?q=kim%40example.com&token=abc')),
      'https://shop.test/search?q=*&token=*',
    );
    expect(redactUrl(Uri.parse('https://shop.test/cart')), 'https://shop.test/cart');
  });

  test('SeaproofHttpClient records requests without bodies or query values', () async {
    final inner = MockClient((request) async => http.Response('{"ok":true}', 201));
    final client = SeaproofHttpClient(inner, controller: controller);

    await client.post(Uri.parse('https://shop.test/orders?coupon=SECRET'), body: 'card=4111');

    final entry = lines(controller.diagnostics).single;
    expect(entry['kind'], 'network');
    expect(entry['method'], 'POST');
    expect(entry['url'], 'https://shop.test/orders?coupon=*');
    expect(entry['status'], 201);
    // Leave out the timestamp: its microseconds can contain any digits, such as 4111.
    final recorded = (Map.of(entry)..remove('t')).toString();
    expect(recorded, isNot(contains('4111')));
    expect(recorded, isNot(contains('SECRET')));
  });

  test("the SDK's own calls are not recorded", () {
    controller.recordRequest(method: 'POST', url: Uri.parse('https://api.test/api/v1/sdk/feedback'), status: 201);
    expect(controller.diagnostics.isEmpty, isTrue);
  });

  test('debugPrint and uncaught Flutter errors are captured, and the previous handlers still run', () {
    final printed = <String?>[];
    final previousPrint = debugPrint;
    final previousOnError = FlutterError.onError;
    FlutterErrorDetails? forwarded;
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    FlutterError.onError = (details) => forwarded = details;
    try {
      controller.installCapture();
      debugPrint('loaded cart');
      FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom'), stack: StackTrace.current));
    } finally {
      controller.uninstallCapture();
      debugPrint = previousPrint;
      FlutterError.onError = previousOnError;
    }

    expect(printed, ['loaded cart']);
    expect(forwarded?.exception, isA<StateError>());
    final entries = lines(controller.diagnostics);
    expect(entries.map((e) => e['kind']), ['console', 'error']);
    expect(entries.last['message'], contains('boom'));
    expect(entries.last['stack'], isNotNull);
  });

  test('Seaproof.runZoned records print once, also when it comes from debugPrint', () {
    final previousPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => print(message);
    try {
      Seaproof.runZoned(() {
        Seaproof.init(
          const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester),
          client: SeaproofClient(
            apiKey: 'sp_test_key_123456789',
            endpoint: Uri.parse('https://api.test'),
            httpClient: api.client,
          ),
        );
        debugPrint('Loaded products: 200');
        print('plain print');
      });
      expect(Seaproof.instance.diagnostics.entries.map((e) => e.message), ['Loaded products: 200', 'plain print']);
    } finally {
      Seaproof.reset();
      debugPrint = previousPrint;
    }
  });

  test('crash reports are sent once per error, at most three per session', () async {
    controller.dispose();
    controller = create(const SeaproofConfig(apiKey: 'sp_test_key_123456789', reportCrashes: true));
    controller.log('tapped pay');

    for (final message in ['a', 'a', 'b', 'c', 'd']) {
      controller.recordError(StateError(message), StackTrace.current);
    }
    await pumpEventQueue();

    final reports = api.submissions;
    expect(reports, hasLength(3));
    expect(reports.first['title'], 'Crash: Bad state: a');
    expect(reports.first['type'], 'bug');
    expect((reports.first['context']! as Map)['custom'], containsPair('seaproof.source', 'crash'));
    expect((reports.first['context']! as Map)['device'], 'Google Pixel 8');
    expect(
      (reports.first['attachments']! as List).single,
      containsPair('contentType', 'application/x-ndjson'),
      reason: 'crash reports carry the diagnostics even in production mode',
    );
  });
}
