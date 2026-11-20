import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seaproof/seaproof.dart';

import 'fake_api.dart';

void main() {
  late FakeApi api;
  late MemorySeaproofStorage storage;

  SeaproofController controllerFor(SeaproofConfig config) {
    final controller = SeaproofController(
      config,
      client: SeaproofClient(apiKey: config.apiKey, endpoint: Uri.parse('https://api.test'), httpClient: api.client),
      appVersion: () async => '2.4.1+77',
      deviceModel: () async => 'Google Pixel 8',
      storage: storage,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Widget app(SeaproofController controller, {Stream<(double, double, double)>? shake, Widget? home, Locale? locale}) =>
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('sv')],
        localizationsDelegates: GlobalMaterialLocalizationsFallback.delegates,
        builder: (context, child) =>
            SeaproofHost(controller: controller, shakeSamples: shake ?? const Stream.empty(), child: child!),
        home: Scaffold(
          body:
              home ??
              const Column(
                children: [
                  Text('Cart'),
                  SeaproofMask(child: Text('4111 1111 1111 1111')),
                ],
              ),
        ),
      );

  // Screenshots go through the engine, which only runs in real async.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    }

    await tester.pumpAndSettle();
  }

  setUp(() {
    api = FakeApi();
    storage = MemorySeaproofStorage();
  });

  testWidgets(
    'testers shake the phone, describe the bug and send it with a screenshot',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      final shake = StreamController<(double, double, double)>.broadcast();
      addTearDown(shake.close);
      final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789'));
      await tester.runAsync(controller.start);
      controller
        ..identify(const SeaproofUser(id: 'u1', name: 'Tess'))
        ..log('tapped checkout');

      await tester.pumpWidget(app(controller, shake: shake.stream));
      expect(controller.resolvedMode, SeaproofMode.tester);
      expect(find.byTooltip('Send feedback'), findsNothing, reason: 'no floating button on phones');

      for (var i = 0; i < 3; i++) {
        shake.add((20, 0, 0));
      }
      await settle(tester);

      expect(find.text('Send feedback'), findsOneWidget);
      expect(find.byKey(const ValueKey('seaproof-email')), findsNothing, reason: 'the user is identified');
      expect(find.byKey(const ValueKey('seaproof-test-strip')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('seaproof-pending-screenshot')),
        findsOneWidget,
        reason: 'testers attach screenshots by default',
      );

      await tester.enterText(find.byKey(const ValueKey('seaproof-description')), 'Checkout does nothing');
      await tester.tap(find.byKey(const ValueKey('seaproof-send')));
      await settle(tester);

      expect(find.text('Report #7 was sent. You can add more details here.'), findsOneWidget);
      expect(find.text('Close chat'), findsOneWidget);
      expect(find.byKey(const ValueKey('seaproof-pending-screenshot')), findsNothing, reason: 'sent with the report');
      final body = api.submissions.single;
      expect(body['type'], 'bug');
      expect(body['reporter'], containsPair('externalId', 'u1'));
      expect((body['context']! as Map)['appVersion'], '2.4.1+77');
      expect((body['context']! as Map)['platform'], startsWith('flutter-'));
      expect((body['attachments']! as List).map((a) => (a as Map)['kind']), ['screenshot', 'log']);
      expect(api.requests.where((r) => r.method == 'PUT'), hasLength(2));

      await tester.tap(find.byKey(const ValueKey('seaproof-quick-done')));
      await tester.pump();
      expect(find.text('Thank you!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Thank you!'), findsNothing, reason: 'closes by itself');
    },
  );

  testWidgets(
    'production shows no triggers and asks before attaching a screenshot or contacting',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      api.environment = 'production';
      final shake = StreamController<(double, double, double)>.broadcast();
      addTearDown(shake.close);
      final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789'));
      await tester.runAsync(controller.start);

      await tester.pumpWidget(
        app(
          controller,
          shake: shake.stream,
          home: SeaproofFeedbackButton(controller: controller, type: FeedbackType.idea),
        ),
      );
      expect(controller.resolvedMode, SeaproofMode.production);

      for (var i = 0; i < 3; i++) {
        shake.add((20, 0, 0));
      }
      await settle(tester);
      expect(find.byKey(const ValueKey('seaproof-description')), findsNothing, reason: 'no shake in production');

      await tester.tap(find.byType(SeaproofFeedbackButton));
      await settle(tester);

      expect(isSelectedType(tester, 'idea'), isTrue);
      expect(find.byKey(const ValueKey('seaproof-test-strip')), findsNothing);
      expect(find.text('Hi! What would you like to tell us?'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('seaproof-pending-screenshot')),
        findsNothing,
        reason: 'end users choose to share the screen',
      );
      expect(find.byKey(const ValueKey('seaproof-may-contact')), findsNothing, reason: 'only once there is an e-mail');

      await tester.enterText(find.byKey(const ValueKey('seaproof-description')), 'Let me save my cart');
      expect(find.byKey(const ValueKey('seaproof-email')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('seaproof-toggle-email')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('seaproof-email')), 'kim@example.test');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('seaproof-may-contact')));
      await tester.tap(find.byKey(const ValueKey('seaproof-send')));
      await settle(tester);

      final body = api.submissions.single;
      expect(body['type'], 'idea');
      expect(body['reporter'], {'externalId': null, 'name': null, 'email': 'kim@example.test', 'mayContact': true});
      expect(body['attachments'], isEmpty, reason: 'no screenshot and no logs unless chosen');
      expect(find.text('Thanks for the idea, the team has it as #7. What would it help you do?'), findsOneWidget);
      expect(find.byKey(const ValueKey('seaproof-email')), findsNothing, reason: 'asked only before saving');
    },
  );

  testWidgets(
    'without the environment yet, auto mode behaves as production',
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789'));
      await tester.pumpWidget(app(controller));

      expect(controller.resolvedMode, SeaproofMode.production);
      expect(find.byTooltip('Send feedback'), findsNothing);

      await tester.runAsync(controller.start);
      await tester.pump();
      expect(find.byTooltip('Send feedback'), findsOneWidget, reason: 'test key on desktop: floating button');
    },
  );

  testWidgets(
    'desktop testers open the panel with the floating button or the shortcut',
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
    (tester) async {
      final controller = controllerFor(
        const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester),
      );
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(controller));

      await tester.tap(find.byTooltip('Send feedback'));
      await settle(tester);
      expect(find.byKey(const ValueKey('seaproof-description')), findsOneWidget);
      expect(find.byTooltip('Send feedback'), findsNothing, reason: 'hidden while open');

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('seaproof-description')), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(find.byKey(const ValueKey('seaproof-description')), findsOneWidget);
    },
  );

  testWidgets('texts follow the app language', (tester) async {
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.pumpWidget(app(controller, locale: const Locale('sv')));

    controller.show();
    await settle(tester);

    expect(find.text('Skicka feedback'), findsOneWidget);
    expect(find.text('Något är fel'), findsOneWidget);
    expect(find.text('Testläge'), findsOneWidget);
  });

  for (final size in [const Size(400, 800), const Size(800, 600)]) {
    testWidgets(
      'the keyboard leaves the composer usable and can be dismissed at width ${size.width}',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = controllerFor(
          const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester),
        );
        await tester.pumpWidget(app(controller));
        controller.show();
        await settle(tester);

        final description = find.byKey(const ValueKey('seaproof-description'));
        final send = find.byKey(const ValueKey('seaproof-send'));
        expect(find.byKey(const ValueKey('seaproof-pending-screenshot')), findsOneWidget);
        await tester.enterText(description, 'The checkout button does nothing');
        tester.testTextInput.log.clear();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        expect(tester.testTextInput.isVisible, isTrue, reason: 'resizing must keep the keyboard open');
        expect(
          tester.testTextInput.log.where((call) => call.method == 'TextInput.hide'),
          isEmpty,
          reason: 'rebuilding the layout must not briefly dismiss the keyboard',
        );

        for (final control in [description, send, find.byKey(const ValueKey('seaproof-toggle-email'))]) {
          expect(tester.getBottomRight(control).dy, lessThanOrEqualTo(size.height - 300));
        }
        expect(tester.takeException(), isNull, reason: 'the conversation shrinks without overflowing');

        expect(find.byTooltip('Hide keyboard'), findsNothing);
        await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('seaproof-conversation'))) + const Offset(8, 8));
        await tester.pump();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.widget<TextField>(description).controller!.text, 'The checkout button does nothing');

        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('seaproof-pending-screenshot')), findsOneWidget);
        await tester.tap(description);
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('seaproof-conversation'))) + const Offset(8, 8));
        await tester.pump();
        expect(tester.testTextInput.isVisible, isFalse, reason: 'tapping outside the fields also dismisses it');

        await tester.tap(description);
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.tap(send);
        await settle(tester);
        expect(api.submissions.single['description'], 'The checkout button does nothing');
        expect((api.submissions.single['attachments']! as List).map((a) => (a as Map)['kind']), contains('screenshot'));
      },
    );
  }

  testWidgets(
    'the Flutter description keeps focus while the keyboard slides in',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      const keyboard = 336.0;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);
      final controller = controllerFor(
        const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester),
      );
      await tester.pumpWidget(app(controller));
      controller.show();
      await settle(tester);

      final description = find.byKey(const ValueKey('seaproof-description'));
      final preview = find.byKey(const ValueKey('seaproof-pending-screenshot'));
      expect(preview, findsOneWidget, reason: 'testers get the screenshot, which is what moved the field before');
      final field = find.descendant(of: description, matching: find.byType(EditableText));

      await tester.tap(description);
      await tester.pump();
      final editable = tester.state<EditableTextState>(field);
      expect(editable.widget.focusNode.hasFocus, isTrue);
      tester.testTextInput.log.clear();

      // iOS reports the keyboard frame by frame while it slides in, and it covers the home indicator.
      for (var frame = 1; frame <= 15; frame++) {
        final inset = keyboard * frame / 15;
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        tester.view.padding = FakeViewPadding(top: 47, bottom: (34 - inset).clamp(0, 34));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.state<EditableTextState>(field), same(editable), reason: 'frame $frame rebuilt the field');
        expect(editable.widget.focusNode.hasFocus, isTrue, reason: 'frame $frame took the focus');
      }
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.hide'), isEmpty);
      expect(tester.getBottomRight(description).dy, lessThanOrEqualTo(844 - keyboard));
      expect(
        tester.getTopLeft(preview).dy,
        lessThan(tester.getTopLeft(description).dy),
        reason: 'the preview stays where it was, above the composer',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pasted screenshots stay in the draft until send and can be retried without duplicating the report',
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final messenger = tester.binding.defaultBinaryMessenger;
      late MethodChannel composer;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        if (call.method == 'create') {
          final params = (call.arguments as Map).cast<String, Object?>();
          expect(params['viewType'], 'io.seaproof/composer');
          composer = MethodChannel('io.seaproof/composer/${params['id']}');
          final channel = composer;
          messenger.setMockMethodCallHandler(channel, (call) async => calls.add(call));
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));
      Future<void> native(String method, [Object? value]) async {
        await messenger.handlePlatformMessage(
          composer.name,
          composer.codec.encodeMethodCall(MethodCall(method, value)),
          null,
        );
        await tester.pumpAndSettle();
      }

      final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_example', mode: SeaproofMode.tester));
      await tester.pumpWidget(app(controller));
      controller.show();
      await settle(tester);

      final preview = find.byKey(const ValueKey('seaproof-pasted-screenshot'));
      final send = find.byKey(const ValueKey('seaproof-send'));
      final description = find.byKey(const ValueKey('seaproof-description'));
      expect(find.byTooltip('Paste screenshot'), findsNothing);
      expect(find.byType(UiKitView), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(description).dy, lessThanOrEqualTo(874 - 336));
      expect(tester.getBottomRight(send).dy, lessThanOrEqualTo(874 - 336));
      expect(tester.getTopLeft(send).dy, greaterThanOrEqualTo(tester.getBottomRight(description).dy));
      await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('seaproof-conversation'))) + const Offset(8, 8));
      expect(calls.last.method, 'blur');
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();

      await native('pasteImage');
      expect(find.text('The image could not be pasted. Try a smaller screenshot.'), findsOneWidget);
      await native('pasteImage', _onePixelPng);
      expect(preview, findsOneWidget);
      expect(find.byKey(const ValueKey('seaproof-pending-screenshot')), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'PUT'), isEmpty, reason: 'the draft is local');

      final remove = find.byKey(const ValueKey('seaproof-remove-pasted-screenshot'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(preview, findsNothing);
      await native('edit', 'The receipt is missing');
      await native('pasteImage', _onePixelPng);
      await tester.tap(find.text('Pasted screenshot'));
      await settle(tester);
      expect(find.byKey(const ValueKey('seaproof-annotation-canvas')), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await settle(tester);
      api.failUploads = true;
      await tester.tap(send);
      await settle(tester);
      final attachments = (api.submissions.single['attachments']! as List).cast<Map<String, Object?>>();
      expect(attachments.map((a) => a['fileName']), ['screenshot.png', 'screenshot-pasted.png']);
      expect(api.submissions.single['description'], 'The receipt is missing');
      expect(preview, findsOneWidget, reason: 'an upload error keeps the pasted image available to retry');

      api.failUploads = false;
      await tester.tap(send);
      await settle(tester);
      expect(api.submissions, hasLength(1));
      expect(api.addedAttachments.single['attachments'], [attachments.last]);
      expect(preview, findsNothing);
      expect(find.text('Pasted screenshot'), findsOneWidget);
    },
  );

  testWidgets('the user marks up the screenshot before sending, and adds more after', (tester) async {
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.pumpWidget(app(controller));
    controller.show();
    await settle(tester);

    Future<void> markUp(Finder open) async {
      await tester.tap(open);
      await settle(tester);
      expect(find.text('Hide'), findsOneWidget);
      await tester.drag(find.byKey(const ValueKey('seaproof-annotation-canvas')), const Offset(60, 40));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await settle(tester);
    }

    await markUp(find.byKey(const ValueKey('seaproof-mark')));
    expect(find.text('Screenshot, marked up'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('seaproof-description')), 'The total is wrong');
    await tester.tap(find.byKey(const ValueKey('seaproof-send')));
    await settle(tester);
    final sent = (api.submissions.single['attachments']! as List).cast<Map<String, Object?>>();
    expect(sent.map((a) => a['fileName']), contains('screenshot-marked.png'));

    await markUp(find.byKey(const ValueKey('seaproof-quick-mark')));
    expect(find.text('The screenshot is attached to #7.'), findsOneWidget);
    final added = (api.addedAttachments.single['attachments']! as List).cast<Map<String, Object?>>();
    expect(added.single['fileName'], 'screenshot-marked.png');

    await tester.enterText(find.byKey(const ValueKey('seaproof-description')), 'It shows 0 kr');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);
    expect(api.messages, ['It shows 0 kr']);
    expect(find.text('Added to #7.'), findsOneWidget);
    expect(api.submissions, hasLength(1), reason: 'later messages add to the same report');
  });

  testWidgets('a report that fails to save stays in the composer', (tester) async {
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.pumpWidget(app(controller));
    controller.show();
    await settle(tester);

    api.failSubmit = true;
    await tester.enterText(find.byKey(const ValueKey('seaproof-description')), 'Nothing loads');
    await tester.tap(find.byKey(const ValueKey('seaproof-send')));
    await settle(tester);

    final field = tester.widget<TextField>(find.byKey(const ValueKey('seaproof-description')));
    expect(field.controller!.text, 'Nothing loads');
    expect(find.byKey(const ValueKey('seaproof-pending-screenshot')), findsOneWidget);
    expect(find.byKey(const ValueKey('seaproof-type-bug')), findsOneWidget, reason: 'still before saving');
  });

  testWidgets(
    'the look follows SeaproofTheme from ThemeData or the host',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = controllerFor(
        const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [SeaproofTheme(primaryColor: Color(0xFF6D28D9), floatingButtonIcon: Icons.bug_report)],
          ),
          builder: (context, child) => SeaproofHost(
            controller: controller,
            shakeSamples: const Stream.empty(),
            theme: const SeaproofTheme(panelStyle: SeaproofPanelStyle.fullScreen),
            child: child!,
          ),
          home: const Scaffold(body: Text('Cart')),
        ),
      );

      expect(find.byIcon(Icons.bug_report), findsOneWidget);
      final button = tester.widget<Material>(
        find.ancestor(of: find.byIcon(Icons.bug_report), matching: find.byType(Material)).first,
      );
      expect(button.color, const Color(0xFF6D28D9));

      controller.show();
      await settle(tester);
      final description = tester.getSize(find.byKey(const ValueKey('seaproof-description')));
      expect(description.width, greaterThan(1000), reason: 'full screen even on a wide window');
      final send = tester.widget<IconButton>(find.byKey(const ValueKey('seaproof-send')));
      final context = tester.element(find.byKey(const ValueKey('seaproof-send')));
      expect(Theme.of(context).colorScheme.primary, const Color(0xFF6D28D9));
      expect(send.onPressed, isNotNull);
    },
  );

  testWidgets('users read the team\'s reply to their feedback and answer it', (tester) async {
    api
      ..environment = 'production'
      ..ownFeedback = [
        {
          'id': 'f1',
          'number': 3,
          'type': 'bug',
          'title': 'Cart is empty',
          'status': 'inProgress',
          'replies': 1,
          'createdAt': '2026-10-20T10:00:00Z',
          'lastReplyAt': '2026-10-21T10:00:00Z',
        },
      ]
      ..ownFeedbackDetails = {
        'f1': {
          'id': 'f1',
          'number': 3,
          'type': 'bug',
          'title': 'Cart is empty',
          'description': 'Cart is empty after login',
          'status': 'inProgress',
          'createdAt': '2026-10-20T10:00:00Z',
          'messages': [
            {'id': 'm1', 'from': 'team', 'body': 'Fixed in 2.1, can you update?', 'createdAt': '2026-10-21T10:00:00Z'},
          ],
          'attachments': [
            {
              'id': 'a1',
              'kind': 'screenshot',
              'url': 'https://storage.test/screenshot.png',
              'createdAt': '2026-10-20T10:00:00Z',
            },
          ],
          'statusUpdates': [
            {'status': 'underReview', 'createdAt': '2026-10-20T11:00:00Z'},
          ],
        },
      };
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_example', allowScreenRecording: true));
    await tester.runAsync(controller.start);
    expect(await tester.runAsync(controller.checkReplies), 1);
    expect(controller.unreadReplies.value, 1);

    await tester.pumpWidget(app(controller));
    controller.show();
    await settle(tester);
    final firstSendBottom = tester.getBottomRight(find.byKey(const ValueKey('seaproof-send'))).dy;

    expect(find.bySemanticsLabel(RegExp('New reply')), findsWidgets);
    await tester.tap(find.text('Your feedback'));
    await settle(tester);
    expect(find.textContaining('In progress'), findsOneWidget);
    await tester.tap(find.text('Cart is empty'));
    await settle(tester);

    expect(find.text('Fixed in 2.1, can you update?'), findsOneWidget);
    final screenshot = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is NetworkImage &&
          (widget.image as NetworkImage).url == 'https://storage.test/screenshot.png',
    );
    expect(screenshot, findsOneWidget);
    expect(tester.getTopLeft(screenshot).dy, lessThan(tester.getTopLeft(find.text('Cart is empty after login')).dy));
    expect(find.text('The team is reviewing your report.'), findsOneWidget);
    expect(tester.getBottomRight(find.byKey(const ValueKey('seaproof-reply-send'))).dy, firstSendBottom);
    expect(controller.unreadReplies.value, 0, reason: 'opening the item marks the reply read');
    await tester.enterText(find.byKey(const ValueKey('seaproof-reply')), 'Works now, thanks!');
    await tester.tap(find.byKey(const ValueKey('seaproof-reply-send')));
    await settle(tester);

    expect(find.text('Works now, thanks!'), findsOneWidget);
    final post = api.requests.lastWhere((r) => r.url.path.endsWith('/messages'));
    expect(post.url.path, '/api/v1/sdk/me/feedback/f1/messages');
    final keys = api.reporterKeys.nonNulls.toSet();
    expect(keys, hasLength(1), reason: 'one stable key per installation');
    expect(keys.single, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));

    await tester.tap(find.byKey(const ValueKey('seaproof-reply-screenshot')));
    await tester.pumpAndSettle();
    final draft = find.byKey(const ValueKey('seaproof-reply-draft-screenshot'));
    expect(draft, findsOneWidget);
    await tester.tap(find.descendant(of: draft, matching: find.text('Screenshot')));
    await settle(tester);
    await tester.drag(find.byKey(const ValueKey('seaproof-annotation-canvas')), const Offset(60, 40));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await settle(tester);
    const reply = 'Here is the marked screenshot.';
    await tester.enterText(find.byKey(const ValueKey('seaproof-reply')), reply);
    api.failUploads = true;
    await tester.tap(find.byKey(const ValueKey('seaproof-reply-send')));
    await settle(tester);

    final sent = (api.addedAttachments.single['attachments']! as List).cast<Map<String, Object?>>();
    expect(sent.single['fileName'], 'screenshot-marked.png');
    final replyPost = api.requests.lastWhere((r) => r.url.path.endsWith('/messages'));
    final messageId = 'm${api.requests.indexOf(replyPost) + 1}';
    expect(api.addedAttachments.single['messageId'], messageId);
    expect(draft, findsOneWidget, reason: 'a failed upload stays in the composer');

    final detail = api.ownFeedbackDetails['f1']!;
    (detail['messages']! as List).add({
      'id': messageId,
      'from': 'you',
      'body': reply,
      'createdAt': '2026-10-21T12:00:00Z',
    });
    (detail['attachments']! as List).add({
      'id': 'marked',
      'kind': 'screenshot',
      'url': 'https://storage.test/marked.png',
      'createdAt': '2026-10-21T12:00:01Z',
      'messageId': messageId,
    });
    api.failUploads = false;
    await tester.tap(find.byKey(const ValueKey('seaproof-reply-send')));
    await settle(tester);
    final marked = find.byKey(const ValueKey('seaproof-attachment-marked'));
    expect(marked, findsOneWidget);
    expect(tester.getBottomRight(marked).dy, lessThan(tester.getTopLeft(find.text(reply)).dy));
    expect(
      tester.getTopLeft(marked).dy,
      greaterThan(tester.getBottomRight(find.text('Fixed in 2.1, can you update?')).dy),
    );
    expect(api.addedAttachments.last['messageId'], messageId, reason: 'a retry keeps the original reply');
    expect(api.messages, ['Works now, thanks!', reply]);
    expect(draft, findsNothing);

    await tester.tap(find.byKey(const ValueKey('seaproof-reply-record')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.tap(find.byKey(const ValueKey('seaproof-stop-recording')));
    await settle(tester);
    expect(find.textContaining('Screen recording,'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('seaproof-reply-send')));
    await settle(tester);

    final clips = (api.addedAttachments.last['attachments']! as List).cast<Map<String, Object?>>();
    expect(clips.single['kind'], 'recording');
    expect(clips.single['contentType'], 'image/apng');
    expect(api.addedAttachments.last, isNot(contains('messageId')), reason: 'a recording can be sent by itself');
    expect(api.submissions, isEmpty, reason: 'both attachments go to the reopened report');
  });

  testWidgets('users vote on published ideas and can take the vote back', (tester) async {
    api.ideas = [
      {
        'id': 'i1',
        'title': 'Dark mode',
        'summary': 'A dark theme',
        'status': 'underReview',
        'votes': 4,
        'voted': false,
        'createdAt': '2026-10-21T10:00:00Z',
      },
    ];
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.pumpWidget(app(controller));
    controller.show();
    await settle(tester);

    await tester.tap(find.text('Ideas'));
    await settle(tester);
    expect(find.text('A dark theme'), findsOneWidget);
    expect(find.text('Under review'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Vote for Dark mode, 4 votes'));
    await settle(tester);
    expect(find.bySemanticsLabel('Remove vote for Dark mode, 5 votes'), findsOneWidget);
    expect(api.requests.last.method, 'PUT');
    expect(api.requests.last.url.path, '/api/v1/sdk/ideas/i1/vote');

    api.failVotes = true;
    await tester.tap(find.bySemanticsLabel('Remove vote for Dark mode, 5 votes'));
    await settle(tester);
    expect(find.bySemanticsLabel('Remove vote for Dark mode, 5 votes'), findsOneWidget, reason: 'restored on failure');

    await tester.tap(find.text('Suggest an idea'));
    await settle(tester);
    expect(isSelectedType(tester, 'idea'), isTrue);
  });

  testWidgets('Assist suggests a known problem while the user writes, and the report links to it', (tester) async {
    api
      ..assist = {'suggestions': true, 'followUpQuestions': false}
      ..suggestions = [
        {
          'id': 'k1',
          'type': 'bug',
          'title': 'Signing in can crash the app',
          'summary': 'We are on it.',
          'status': 'inProgress',
          'votes': 0,
        },
      ];
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.pumpWidget(app(controller));
    controller.show();
    await settle(tester);

    await tester.enterText(find.byKey(const ValueKey('seaproof-description')), 'The app crashes when I sign in');
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);

    expect(find.text('The team may already know about this'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    final asked = api.requests.where((r) => r.url.path == '/api/v1/sdk/assist/suggestions').toList();
    expect(asked, hasLength(1), reason: 'once, after the user paused');
    expect(jsonDecode(asked.single.body), {'text': 'The app crashes when I sign in', 'type': 'bug'});

    await tester.tap(find.byKey(const ValueKey('seaproof-same-k1')));
    await settle(tester);
    expect(api.submissions.single['linkedTo'], 'k1', reason: '"Same for me" sends straight away');
    expect(api.submissions.single['description'], 'The app crashes when I sign in');
    expect(find.textContaining('the team already knows about (#7)'), findsOneWidget);
    expect(find.text('The team may already know about this'), findsNothing);
  });

  testWidgets('Assist asks its questions after the report is saved, and the answers are added to it', (tester) async {
    const questions = [
      'Vad förväntade du dig skulle hända?',
      'Vilken sida var du på?',
      'Hur kom du dit?',
      'Vad gjorde knappen i stället?',
      'Händer det varje gång?',
      'Såg du ett felmeddelande?',
    ];
    api
      ..assist = {'suggestions': false, 'followUpQuestions': true}
      ..questions = questions
      ..questionReceipts = [for (final (index, _) in questions.indexed) 'receipt-$index'];
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.pumpWidget(app(controller, locale: const Locale('sv')));
    controller.show();
    await settle(tester);

    await tester.enterText(find.byKey(const ValueKey('seaproof-description')), 'Knappen gör ingenting');
    await tester.tap(find.byKey(const ValueKey('seaproof-send')));
    await settle(tester);

    expect(api.submissions.single['description'], 'Knappen gör ingenting', reason: 'saved before any question');
    expect(find.text('Tack, det är sparat som #7. Vad förväntade du dig skulle hända?'), findsOneWidget);
    expect(find.byKey(const ValueKey('seaproof-quick-done')), findsOneWidget, reason: 'the user may stop here');

    const answers = ['Jag väntade mig kassan.', 'Varukorgen.', 'Jag lade till en vara.', 'Ingenting.', 'Ja.'];
    for (final (index, answer) in answers.indexed) {
      await tester.enterText(find.byKey(const ValueKey('seaproof-description')), answer);
      await tester.tap(find.byKey(const ValueKey('seaproof-send')));
      await settle(tester);
      if (index + 1 < answers.length) {
        expect(find.text(questions[index + 1]), findsOneWidget);
        expect(find.text(questions[index + 2]), findsNothing);
      }
    }

    expect(find.text(questions.last), findsNothing);
    expect(api.messages, answers);
    final timeline = [
      for (final request in api.requests)
        if (request.url.path.endsWith('/questions/shown') || request.url.path.endsWith('/messages'))
          jsonDecode(request.body) as Map<String, Object?>,
    ];
    expect(timeline, [
      for (final (i, answer) in answers.indexed) ...[
        {'feedbackId': 'f1', 'receipt': 'receipt-$i'},
        {'body': answer},
      ],
    ]);
    expect(api.submissions, hasLength(1));
    expect(find.text('Tillagt i #7.'), findsOneWidget);
    final review = api.requests.where((r) => r.url.path == '/api/v1/sdk/assist/review');
    expect(review, hasLength(1));
    expect(
      (jsonDecode(review.single.body) as Map<String, dynamic>)['conversationId'],
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });

  testWidgets('the project launcher avoids an obstruction and returns to its preferred position', (tester) async {
    api.launcher = {
      'label': 'Report a bug',
      'orientation': 'vertical',
      'position': 'bottom-right',
      'avoidObstructions': true,
    };
    final controller = controllerFor(
      const SeaproofConfig(
        apiKey: 'sp_test_key_123456789',
        mode: SeaproofMode.tester,
        triggers: {SeaproofTrigger.floatingButton},
      ),
    );
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final obstructions = ValueNotifier<List<Rect>>(const []);
    addTearDown(obstructions.dispose);
    await tester.runAsync(controller.start);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            SeaproofHost(controller: controller, launcherObstructions: obstructions, child: child!),
        home: const Scaffold(body: Text('Checkout')),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byTooltip('Report a bug');
    final preferred = tester.getRect(button);
    expect(preferred.height, greaterThan(preferred.width));
    expect(preferred.center.dx, greaterThan(400));
    expect(preferred.center.dy, greaterThan(400));

    obstructions.value = const [Rect.fromLTWH(690, 440, 110, 160)];
    await tester.pumpAndSettle();
    final moved = tester.getRect(button);
    expect(moved.center.dx, preferred.center.dx);
    expect(moved.center.dy, 300);
    expect(moved.overlaps(obstructions.value.single), isFalse);

    obstructions.value = const [];
    await tester.pumpAndSettle();
    expect(tester.getRect(button), preferred);
    await tester.tap(button);
    await settle(tester);
    expect(find.byKey(const ValueKey('seaproof-description')), findsOneWidget);
  });

  testWidgets('the panel uses the colour and logo set in the admin', (tester) async {
    api
      ..branding = {'primaryColor': '#ffcc00', 'logo': 'abc123'}
      ..logo = _onePixelPng;
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.runAsync(controller.start);
    await tester.pumpWidget(app(controller));
    controller.show();
    await settle(tester);

    final scheme = Theme.of(tester.element(find.byKey(const ValueKey('seaproof-send')))).colorScheme;
    expect(scheme.primary, const Color(0xFFFFCC00));
    expect(scheme.onPrimary, const Color(0xFF111111), reason: 'dark text on a light colour');
    expect(find.byKey(const ValueKey('seaproof-logo')), findsOneWidget);
    expect(api.requests.map((r) => r.url.toString()), contains('https://api.test/api/v1/sdk/branding/logo?v=abc123'));
  });

  testWidgets("the app's own theme wins over the admin's colour", (tester) async {
    api.branding = {'primaryColor': '#ffcc00', 'logo': null};
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.runAsync(controller.start);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => SeaproofHost(
          controller: controller,
          theme: const SeaproofTheme(primaryColor: Color(0xFF123456)),
          shakeSamples: const Stream.empty(),
          child: child!,
        ),
        home: const Scaffold(body: Text('Cart')),
      ),
    );
    controller.show();
    await settle(tester);

    final scheme = Theme.of(tester.element(find.byKey(const ValueKey('seaproof-send')))).colorScheme;
    expect(scheme.primary, const Color(0xFF123456));
    expect(find.byKey(const ValueKey('seaproof-logo')), findsNothing);
    expect(api.requests.where((r) => r.url.path.endsWith('/branding/logo')), isEmpty, reason: 'no logo to fetch');
  });

  testWidgets('the panel shows only the form when the user has nothing else', (tester) async {
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.pumpWidget(app(controller));
    controller.show();
    await settle(tester);

    expect(find.byKey(const ValueKey('seaproof-tabs')), findsNothing);
    expect(find.byKey(const ValueKey('seaproof-description')), findsOneWidget);
  });

  testWidgets('testers record the screen; the panel hides meanwhile and keeps the text', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.pumpWidget(app(controller));
    controller.show();
    await settle(tester);

    await tester.enterText(find.byKey(const ValueKey('seaproof-description')), 'The menu flickers');
    await tester.tap(find.byKey(const ValueKey('seaproof-record')));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    }

    expect(find.byKey(const ValueKey('seaproof-description')), findsNothing, reason: 'hidden while recording');
    expect(find.textContaining('Recording 0:0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('seaproof-stop-recording')));
    await settle(tester);

    expect(find.byKey(const ValueKey('seaproof-pending-recording')), findsOneWidget);
    expect(find.text('The menu flickers'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('seaproof-send')));
    await settle(tester);

    final attachments = (api.submissions.single['attachments']! as List).cast<Map<String, Object?>>();
    expect(attachments.map((a) => (a['kind'], a['contentType'])), contains(('recording', 'image/apng')));
  });

  testWidgets('end users are not offered a recording unless the app allows it', (tester) async {
    final controller = controllerFor(
      const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.production),
    );
    await tester.pumpWidget(app(controller));
    controller.show();
    await settle(tester);

    expect(find.byKey(const ValueKey('seaproof-record')), findsNothing);
  });

  testWidgets('masked widgets are black in the screenshot', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = controllerFor(const SeaproofConfig(apiKey: 'sp_test_key_123456789', mode: SeaproofMode.tester));
    await tester.pumpWidget(
      app(
        controller,
        home: const Align(
          alignment: Alignment.topLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SeaproofMask(
                child: SizedBox.square(dimension: 100, child: ColoredBox(color: Color(0xFFFF0000))),
              ),
              SizedBox.square(dimension: 100, child: ColoredBox(color: Color(0xFF00FF00))),
            ],
          ),
        ),
      ),
    );

    controller.show();
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('seaproof-description')), 'Masked');
    await tester.tap(find.byKey(const ValueKey('seaproof-send')));
    await settle(tester);

    final png = api.requests.firstWhere((r) => r.method == 'PUT').bodyBytes;
    final pixels = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      return (await image.toByteData())!;
    });
    int argbAt(int x, int y) {
      final i = (y * 400 + x) * 4;
      return pixels!.getUint8(i + 3) << 24 |
          pixels.getUint8(i) << 16 |
          pixels.getUint8(i + 1) << 8 |
          pixels.getUint8(i + 2);
    }

    expect(argbAt(50, 50), 0xFF000000, reason: 'masked');
    expect(argbAt(150, 50), 0xFF00FF00, reason: 'not masked');
  });
}

/// Material localizations for English and Swedish without depending on flutter_localizations.
abstract final class GlobalMaterialLocalizationsFallback {
  static const delegates = <LocalizationsDelegate<Object>>[_AnyMaterial(), _AnyWidgets(), _AnyCupertino()];
}

class _AnyMaterial extends LocalizationsDelegate<MaterialLocalizations> {
  const _AnyMaterial();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) => DefaultMaterialLocalizations.load(locale);

  @override
  bool shouldReload(_AnyMaterial old) => false;
}

class _AnyWidgets extends LocalizationsDelegate<WidgetsLocalizations> {
  const _AnyWidgets();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) => DefaultWidgetsLocalizations.load(locale);

  @override
  bool shouldReload(_AnyWidgets old) => false;
}

class _AnyCupertino extends LocalizationsDelegate<CupertinoLocalizations> {
  const _AnyCupertino();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) => DefaultCupertinoLocalizations.load(locale);

  @override
  bool shouldReload(_AnyCupertino old) => false;
}

// A valid 1x1 transparent PNG.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Whether the type chip for [name] is the selected one, as assistive technology hears it.
bool isSelectedType(WidgetTester tester, String name) =>
    tester
        .widget<Semantics>(
          find
              .ancestor(
                of: find.byKey(ValueKey('seaproof-type-$name'), skipOffstage: false),
                matching: find.byType(Semantics, skipOffstage: false),
              )
              .first,
        )
        .properties
        .selected ??
    false;
