import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'client.dart';
import 'config.dart';
import 'device.dart';
import 'diagnostics.dart';
import 'models.dart';
import 'network.dart';
import 'platform_info.dart';
import 'reporter_identity.dart';
import 'storage.dart';
import 'theme.dart';
import 'version.dart';

/// A request to open the feedback panel.
@immutable
final class ShowRequest {
  /// Creates a request.
  const ShowRequest({this.type, this.includeScreenshot});

  /// The type to preselect.
  final FeedbackType? type;

  /// Whether a screenshot starts attached. When null, the mode decides.
  final bool? includeScreenshot;
}

/// The SDK's state: configuration, environment, the current user, diagnostics and screen.
///
/// Most apps use the static [Seaproof] facade. Create a controller yourself to pass it to a
/// [SeaproofHost] explicitly, for example in tests.
class SeaproofController extends ChangeNotifier {
  /// Creates a controller. [client] defaults to one built from [config].
  SeaproofController(
    this.config, {
    SeaproofClient? client,
    Future<String?> Function()? appVersion,
    Future<String?> Function()? deviceModel,
    SeaproofStorage? storage,
  }) : client = client ?? SeaproofClient(apiKey: config.apiKey, endpoint: config.endpoint),
       _appVersion = appVersion ?? _platformAppVersion,
       _deviceModel = deviceModel ?? platformDeviceModel,
       _identity = ReporterIdentity(storage ?? config.storage ?? PreferencesSeaproofStorage());

  /// The settings.
  final SeaproofConfig config;

  /// The API client.
  final SeaproofClient client;

  /// Recent logs, console output, requests and errors.
  final Diagnostics diagnostics = Diagnostics();

  final Future<String?> Function() _appVersion;
  final Future<String?> Function() _deviceModel;
  final ReporterIdentity _identity;
  final ValueNotifier<int> _unreadReplies = ValueNotifier(0);
  final Set<String> _reportedCrashes = {};
  DebugPrintCallback? _previousDebugPrint;
  FlutterExceptionHandler? _previousFlutterError;
  bool Function(Object, StackTrace)? _previousPlatformError;
  bool _captureInstalled = false;
  final StreamController<ShowRequest> _requests = StreamController.broadcast();
  SeaproofProject? _project;
  Uint8List? _logo;
  SeaproofUser? _user;
  String? _screen;
  bool _disposed = false;

  /// The project of the API key, once [start] has fetched it.
  SeaproofProject? get project => _project;

  /// The project's logo from the admin, once fetched; null when it has none or
  /// [SeaproofConfig.useProjectBranding] is off.
  Uint8List? get logo => _logo;

  /// The colours set in the admin, as a fallback theme; null when none is set or
  /// [SeaproofConfig.useProjectBranding] is off.
  SeaproofTheme? get brandingTheme {
    final color = config.useProjectBranding ? _project?.branding.color : null;
    if (color == null) {
      return null;
    }

    // Black or white text, whichever reads better on the colour.
    final onPrimary = color.computeLuminance() > 0.4 ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
    return SeaproofTheme(primaryColor: color, onPrimaryColor: onPrimary);
  }

  /// The mode of the API key's environment, once known.
  SeaproofEnvironmentMode? get environmentMode => _project?.mode;

  /// The team's name for the API key's environment, such as `UAT`, once known.
  String? get environmentName => _project?.environmentName;

  /// The mode of the API key's environment, once known.
  @Deprecated('Use environmentMode, or environmentName for the environment itself.')
  SeaproofEnvironmentMode? get environment => environmentMode;

  /// The identified user, or null for anonymous feedback.
  SeaproofUser? get user => _user;

  /// The current screen, from [setScreen] or [SeaproofNavigatorObserver].
  String? get screen => _screen;

  /// Tester or production, with [SeaproofMode.auto] resolved from the environment.
  SeaproofMode get resolvedMode => switch (config.mode) {
    SeaproofMode.auto => switch (environmentMode) {
      SeaproofEnvironmentMode.test => SeaproofMode.tester,
      SeaproofEnvironmentMode.production || null => SeaproofMode.production,
    },
    final mode => mode,
  };

  /// Whether the SDK behaves as for testers.
  bool get isTesterMode => resolvedMode == SeaproofMode.tester;

  /// The triggers in effect.
  Set<SeaproofTrigger> get triggers => config.triggers ?? defaultTriggers(resolvedMode);

  /// The types offered, in order.
  List<FeedbackType> get types => config.types ?? defaultTypes(resolvedMode);

  /// Whether the panel offers to record the screen.
  bool get allowScreenRecording => config.allowScreenRecording ?? isTesterMode;

  /// Whether the diagnostics are attached to reports.
  bool get includeDiagnostics => config.includeDiagnostics ?? isTesterMode;

  /// How many of the user's items have a reply they have not opened, as of the last
  /// [myFeedback] or [checkReplies]. Use it for a badge on your own feedback button.
  ValueListenable<int> get unreadReplies => _unreadReplies;

  /// Requests to open the panel; [SeaproofHost] listens to these.
  Stream<ShowRequest> get showRequests => _requests.stream;

  /// Fetches the key's environment. Safe to call more than once; failures are logged and
  /// leave the SDK in production behaviour (see [SeaproofMode.auto]).
  Future<void> start() async {
    try {
      _project = await client.whoAmI();
      if (!_disposed) {
        notifyListeners();
      }
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: could not fetch the project for the API key ($e).');
      return;
    }

    await _fetchLogo();
  }

  Future<void> _fetchLogo() async {
    final version = _project?.branding.logoVersion;
    if (!config.useProjectBranding || version == null) {
      return;
    }

    try {
      _logo = await client.logo(version);
      if (!_disposed) {
        notifyListeners();
      }
    } on SeaproofException catch (e) {
      // A missing logo must never get in the way of feedback.
      debugPrint('Seaproof: could not fetch the project logo ($e).');
    }
  }

  /// Sets who sends feedback, or null to make it anonymous. Call on sign-in and sign-out.
  ///
  /// With a [SeaproofUser.userHash] from your backend, the user's conversations and votes
  /// follow them to every device; without it they stay with this installation.
  void identify(SeaproofUser? user) {
    _user = user;
    client.user = user;
    notifyListeners();
  }

  /// Records the current screen name, sent as context.
  void setScreen(String? name) => _screen = name;

  /// Adds a line to the diagnostics.
  void log(String message) => diagnostics.add(DiagnosticKind.log, message);

  /// Records an HTTP request. [SeaproofHttpClient] calls this; call it from your own
  /// interceptor for other clients, such as Dio. Query values are redacted.
  void recordRequest({
    required String method,
    required Uri url,
    int? status,
    Duration? duration,
    int? responseBytes,
    String? error,
  }) {
    // The SDK's own calls are not the app's traffic.
    if (url.host == client.endpoint.host && url.path.startsWith('/api/v1/sdk/')) {
      return;
    }

    final (message, data) = networkEntry(
      method: method,
      url: url,
      status: status,
      duration: duration,
      responseBytes: responseBytes,
      error: error,
    );
    diagnostics.add(DiagnosticKind.network, message, data);
  }

  /// Records an uncaught error, and reports it when [SeaproofConfig.reportCrashes] is on.
  void recordError(Object error, StackTrace? stack, {String? context}) {
    final message = '${context == null ? '' : '$context: '}$error';
    diagnostics.add(DiagnosticKind.error, message, {if (stack != null) 'stack': stack.toString()});
    if (config.reportCrashes && _reportedCrashes.length < 3 && _reportedCrashes.add(error.toString())) {
      unawaited(_reportCrash(message, stack));
    }
  }

  /// Starts recording console output and uncaught errors, as configured. [Seaproof.init]
  /// calls this; call [uninstallCapture] to stop.
  void installCapture() {
    if (_captureInstalled) {
      return;
    }

    _captureInstalled = true;
    if (config.captureConsole) {
      _previousDebugPrint = debugPrint;
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null && !message.startsWith('Seaproof:')) {
          diagnostics.add(DiagnosticKind.console, message);
          // debugPrint ends in print, which Seaproof.runZoned records too.
          _debugPrintEchoes.add(message);
          if (_debugPrintEchoes.length > 50) {
            _debugPrintEchoes.removeAt(0);
          }
        }

        previous(message, wrapWidth: wrapWidth);
      };
    }

    if (config.captureErrors) {
      _previousFlutterError = FlutterError.onError;
      final previousFlutter = FlutterError.onError;
      FlutterError.onError = (details) {
        recordError(details.exception, details.stack, context: details.context?.toDescription());
        previousFlutter?.call(details);
      };
      final dispatcher = ui.PlatformDispatcher.instance;
      _previousPlatformError = dispatcher.onError;
      final previousPlatform = dispatcher.onError;
      dispatcher.onError = (error, stack) {
        recordError(error, stack);
        return previousPlatform?.call(error, stack) ?? false;
      };
    }
  }

  final List<String> _debugPrintEchoes = [];

  /// Whether a `print` line is (part of) a message already recorded from `debugPrint`, which
  /// may print it later and split into wrapped lines.
  bool _isDebugPrintEcho(String line) {
    final trimmed = line.trim();
    for (var i = 0; i < _debugPrintEchoes.length; i++) {
      final pending = _debugPrintEchoes[i];
      final at = pending.indexOf(trimmed);
      if (at < 0) {
        continue;
      }

      final rest = pending.substring(at + trimmed.length);
      if (rest.trim().isEmpty) {
        _debugPrintEchoes.removeAt(i);
      } else {
        _debugPrintEchoes[i] = rest;
      }

      return true;
    }

    return false;
  }

  /// Restores the handlers [installCapture] replaced.
  void uninstallCapture() {
    if (!_captureInstalled) {
      return;
    }

    _captureInstalled = false;
    if (config.captureConsole) {
      debugPrint = _previousDebugPrint ?? debugPrintThrottled;
    }

    if (config.captureErrors) {
      FlutterError.onError = _previousFlutterError;
      ui.PlatformDispatcher.instance.onError = _previousPlatformError;
    }
  }

  Future<void> _reportCrash(String message, StackTrace? stack) async {
    final firstLine = message.split('\n').first;
    try {
      final result = await submit(
        FeedbackDraft(
          type: FeedbackType.bug,
          title: 'Crash: ${firstLine.length <= 180 ? firstLine : '${firstLine.substring(0, 177)}...'}',
          description: [message, if (stack != null) stack.toString()].join('\n\n'),
          user: _user,
        ),
        automatic: true,
      );
      debugPrint('Seaproof: reported the crash as #${result.number}.');
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: could not report the crash ($e).');
    }
  }

  /// Feedback sent from this installation, newest first, with the number of team replies.
  Future<List<OwnFeedback>> myFeedback() async {
    final key = await _reporterKey();
    if (key == null) {
      return const [];
    }

    final items = await client.myFeedback(key);
    _setUnread(items);
    return items;
  }

  /// Fetches the user's items and returns how many have an unread reply; see [unreadReplies].
  Future<int> checkReplies() async {
    try {
      await myFeedback();
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: could not check for replies ($e).');
    }

    return _unreadReplies.value;
  }

  /// Whether [item] has a reply the user has not opened yet.
  bool hasUnreadReply(OwnFeedback item) => _identity.isUnread(item);

  /// One of the user's items with the conversation. Marks the team's replies as read.
  Future<OwnFeedbackDetail> myFeedbackItem(String id) async {
    final detail = await client.myFeedbackItem(id, await _requireReporterKey());
    final lastReply = detail.messages.where((m) => m.fromTeam).lastOrNull;
    if (lastReply != null && await _identity.markSeen(id, lastReply.createdAt)) {
      if (_unreadReplies.value > 0 && !_disposed) {
        _unreadReplies.value--;
      }
    }

    return detail;
  }

  /// Answers the team about one of the user's items.
  Future<ConversationMessage> sendMessage(String id, String body) async =>
      client.sendMessage(id, body, await _requireReporterKey());

  /// Adds files to one of the user's items after it was sent. Returns the ones that failed to upload.
  Future<List<FeedbackAttachment>> addAttachments(String id, List<FeedbackAttachment> attachments) async =>
      client.addAttachments(id, attachments, await _requireReporterKey());

  /// The ideas the team published, most voted first.
  Future<List<PublicIdea>> ideas() async {
    final key = await _reporterKey();
    return key == null ? const [] : client.ideas(key);
  }

  /// Votes for a published idea.
  Future<void> vote(String ideaId) async => client.vote(ideaId, await _requireReporterKey());

  /// Takes the vote for a published idea back.
  Future<void> unvote(String ideaId) async => client.unvote(ideaId, await _requireReporterKey());

  void _setUnread(List<OwnFeedback> items) {
    if (!_disposed) {
      _unreadReplies.value = items.where(_identity.isUnread).length;
    }
  }

  /// The installation's key, or null when the storage cannot be used. Feedback can still be
  /// sent then, only replies and votes are unavailable.
  Future<String?> _reporterKey() async {
    try {
      return await _identity.key();
    } on Object catch (e) {
      // Storage plugins throw platform-specific errors; none of them may break reporting.
      debugPrint('Seaproof: the reporter key could not be stored ($e).');
      return null;
    }
  }

  Future<String> _requireReporterKey() async =>
      await _reporterKey() ??
      (throw const SeaproofException('reporter.unavailable', 'This installation cannot store its reporter key.'));

  /// What Seaproof Assist offers in this project. Everything off when it cannot be fetched.
  Future<AssistSettings> assistSettings() => client.assistSettings();

  /// Known problems and public ideas like [text], best first.
  Future<List<Suggestion>> suggest(String text, {FeedbackType? type}) async =>
      client.suggest(text, type: type, reporterKey: await _reporterKey());

  /// What a draft is missing, as at most two questions. Never throws. Calls with the same
  /// [conversationId] count as one Assist conversation.
  Future<ReviewResult> review(FeedbackType type, String description, {String? conversationId}) async =>
      client.review(type, description, reporterKey: await _reporterKey(), conversationId: conversationId);

  /// Opens the feedback panel. Needs a [SeaproofHost] in the widget tree.
  void show({FeedbackType? type, bool? includeScreenshot}) {
    if (!_requests.hasListener) {
      debugPrint('Seaproof: show() was called, but no SeaproofHost is mounted.');
      return;
    }

    _requests.add(ShowRequest(type: type, includeScreenshot: includeScreenshot));
  }

  /// Sends a report with the SDK's context. Adds the diagnostics when [includeDiagnostics]
  /// is on, or always for [automatic] crash reports.
  Future<SubmittedFeedback> submit(FeedbackDraft draft, {bool automatic = false}) async {
    final attachments = [
      ...draft.attachments,
      if ((includeDiagnostics || automatic) && !diagnostics.isEmpty)
        FeedbackAttachment(
          kind: AttachmentKind.log,
          fileName: 'diagnostics.ndjson',
          contentType: 'application/x-ndjson',
          bytes: diagnostics.toNdjson(),
        ),
    ];
    final context = await buildContext();
    // Crash reports are not the user's own words, so they do not open a conversation.
    final reporterKey = automatic ? null : await _reporterKey();
    return client.submit(
      FeedbackDraft(
        type: draft.type,
        description: draft.description,
        title: draft.title,
        severity: draft.severity,
        user: draft.user,
        mayContact: draft.mayContact,
        attachments: attachments,
        linkedTo: draft.linkedTo,
      ),
      automatic
          ? FeedbackContext(
              platform: context.platform,
              appVersion: context.appVersion,
              osVersion: context.osVersion,
              device: context.device,
              locale: context.locale,
              screen: context.screen,
              sdkVersion: context.sdkVersion,
              commit: context.commit,
              custom: {...context.custom, 'seaproof.source': 'crash'},
            )
          : context,
      reporterKey: reporterKey,
    );
  }

  /// The context sent with every report.
  Future<FeedbackContext> buildContext() async => FeedbackContext(
    platform: 'flutter-${operatingSystem()}',
    appVersion: config.appVersion ?? await _appVersion(),
    osVersion: operatingSystemVersion(),
    device: config.device ?? await _deviceModel(),
    locale: ui.PlatformDispatcher.instance.locale.toLanguageTag(),
    screen: _screen,
    sdkVersion: seaproofSdkVersion,
    commit: config.commit ?? (_buildCommit.isEmpty ? null : _buildCommit),
    custom: config.custom,
  );

  static const _buildCommit = String.fromEnvironment('SEAPROOF_COMMIT');

  @override
  void dispose() {
    _disposed = true;
    uninstallCapture();
    unawaited(_requests.close());
    _unreadReplies.dispose();
    client.close();
    super.dispose();
  }

  static Future<String?> _platformAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.buildNumber.isEmpty ? info.version : '${info.version}+${info.buildNumber}';
    } on Object {
      return null;
    }
  }
}

/// The static entry point for apps that use one Seaproof project.
///
/// ```dart
/// void main() {
///   Seaproof.init(const SeaproofConfig(apiKey: 'sp_...'));
///   runApp(MaterialApp(builder: (context, child) => SeaproofHost(child: child!), home: ...));
/// }
/// ```
abstract final class Seaproof {
  static SeaproofController? _instance;

  /// The controller created by [init].
  static SeaproofController get instance =>
      _instance ?? (throw StateError('Call Seaproof.init(...) before using Seaproof.'));

  /// Whether [init] has been called.
  static bool get isInitialized => _instance != null;

  /// Configures the SDK and fetches the key's environment in the background.
  static SeaproofController init(SeaproofConfig config, {SeaproofClient? client}) {
    _instance?.dispose();
    final controller = SeaproofController(config, client: client);
    _instance = controller;
    controller.installCapture();
    unawaited(controller.start());
    return controller;
  }

  /// Runs [body], usually `runApp`, in a zone that also records `print` output and errors
  /// that escape Flutter's handlers. Optional: [init] already records `debugPrint` and
  /// uncaught errors.
  ///
  /// ```dart
  /// void main() => Seaproof.runZoned(() {
  ///   Seaproof.init(const SeaproofConfig(apiKey: '...'));
  ///   runApp(const MyApp());
  /// });
  /// ```
  static void runZoned(void Function() body) {
    runZonedGuarded(
      body,
      (error, stack) {
        if (isInitialized) {
          instance.recordError(error, stack);
        }

        Zone.root.print('Uncaught error: $error\n$stack');
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (isInitialized &&
              instance.config.captureConsole &&
              !line.startsWith('Seaproof:') &&
              !instance._isDebugPrintEcho(line)) {
            instance.diagnostics.add(DiagnosticKind.console, line);
          }

          parent.print(zone, line);
        },
      ),
    );
  }

  /// See [SeaproofController.recordRequest].
  static void recordRequest({
    required String method,
    required Uri url,
    int? status,
    Duration? duration,
    int? responseBytes,
    String? error,
  }) => instance.recordRequest(
    method: method,
    url: url,
    status: status,
    duration: duration,
    responseBytes: responseBytes,
    error: error,
  );

  /// See [SeaproofController.identify].
  static void identify(SeaproofUser? user) => instance.identify(user);

  /// See [SeaproofController.show].
  static void show({FeedbackType? type, bool? includeScreenshot}) =>
      instance.show(type: type, includeScreenshot: includeScreenshot);

  /// See [SeaproofController.log].
  static void log(String message) => instance.log(message);

  /// See [SeaproofController.unreadReplies].
  static ValueListenable<int> get unreadReplies => instance.unreadReplies;

  /// See [SeaproofController.checkReplies].
  static Future<int> checkReplies() => instance.checkReplies();

  /// See [SeaproofController.setScreen].
  static void setScreen(String? name) => instance.setScreen(name);

  /// Disposes the controller from [init].
  @visibleForTesting
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}

/// Reports the current route's name as the screen. Add it to `navigatorObservers`.
class SeaproofNavigatorObserver extends NavigatorObserver {
  /// Creates an observer for [controller], or for [Seaproof.instance] when null.
  SeaproofNavigatorObserver({SeaproofController? controller}) : _controller = controller;

  final SeaproofController? _controller;

  SeaproofController? get _target => _controller ?? (Seaproof.isInitialized ? Seaproof.instance : null);

  void _update(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) {
      _target?.setScreen(name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _update(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(previousRoute);
}
