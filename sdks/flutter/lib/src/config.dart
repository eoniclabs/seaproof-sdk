import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'storage.dart';

/// Who the SDK is set up for.
enum SeaproofMode {
  /// Follow the API key's environment: keys in a production-mode environment get
  /// [production], keys in a test-mode environment [tester].
  ///
  /// Until the environment is known (or if it cannot be fetched), the SDK behaves as
  /// [production], so a test UI is never shown to end users by mistake.
  auto,

  /// Testers: visible triggers, screenshot on by default, diagnostics attached.
  tester,

  /// End users: no visible triggers unless you add them, screenshot only if the user
  /// chooses it, no diagnostics.
  production,
}

/// How the feedback panel can be opened, besides [Seaproof.show].
enum SeaproofTrigger {
  /// Shaking the phone or tablet. Ignored on desktop and web.
  shake,

  /// A small floating button that can be dragged to any edge.
  floatingButton,

  /// A keyboard shortcut, see [SeaproofConfig.shortcut]. Useful on desktop and web.
  keyboardShortcut,
}

/// Settings for the SDK.
@immutable
final class SeaproofConfig {
  /// Creates a configuration. Only [apiKey] is required.
  const SeaproofConfig({
    required this.apiKey,
    this.endpoint,
    this.mode = SeaproofMode.auto,
    this.triggers,
    this.shortcut,
    this.appVersion,
    this.commit,
    this.device,
    this.custom = const {},
    this.locale,
    this.types,
    this.includeDiagnostics,
    this.captureConsole = true,
    this.captureErrors = true,
    this.reportCrashes = false,
    this.showOwnFeedback = true,
    this.showIdeas = true,
    this.storage,
    this.allowScreenRecording,
    this.maxRecordingDuration = const Duration(seconds: 30),
    this.useProjectBranding = true,
  });

  /// The project API key (`sp_...`). Create one per environment in the Seaproof admin.
  final String apiKey;

  /// Base address of the API. Defaults to the hosted Seaproof API.
  final Uri? endpoint;

  /// Tester or production behaviour. Defaults to following the key's environment.
  final SeaproofMode mode;

  /// Explicit triggers. When null, the mode decides: testers get shake on mobile and a
  /// floating button plus keyboard shortcut on desktop and web; production gets none.
  final Set<SeaproofTrigger>? triggers;

  /// The keyboard shortcut. Defaults to Ctrl+Alt+F (Cmd+Option+F on macOS).
  final ShortcutActivator? shortcut;

  /// The app version to report. Read from the platform when null.
  final String? appVersion;

  /// The commit the app was built from, so a bug leads straight to the code. When null, the
  /// `SEAPROOF_COMMIT` build define is used:
  /// `flutter build --dart-define=SEAPROOF_COMMIT=$(git rev-parse --short HEAD)`.
  final String? commit;

  /// The device model to report. Read from the platform when null.
  final String? device;

  /// Metadata sent with every report, for example a build flavour.
  final Map<String, String> custom;

  /// Language of the SDK's own texts. Follows the app's locale when null.
  final Locale? locale;

  /// Types the user can pick, in order. When null, the mode decides.
  final List<FeedbackType>? types;

  /// Attach the diagnostics (logs, console, network and errors) to reports. When null, only
  /// testers send them. They are kept on the device until a report is sent.
  final bool? includeDiagnostics;

  /// Record `debugPrint` output, and `print` inside [Seaproof.runZoned].
  final bool captureConsole;

  /// Record uncaught Flutter and platform errors. The app's own handlers still run.
  final bool captureErrors;

  /// Send a bug report on its own when an uncaught error happens, with the diagnostics.
  /// At most three per app session, and each distinct error once.
  final bool reportCrashes;

  /// Show a "Your feedback" tab in the panel, where users read the team's replies to what they
  /// sent from this installation and answer them. Shown only once they have sent something.
  final bool showOwnFeedback;

  /// Show an "Ideas" tab with the ideas the team published, where users vote. Shown only when
  /// the project has published ideas.
  final bool showIdeas;

  /// Where the installation's reporter key and read markers are kept. Defaults to shared
  /// preferences.
  final SeaproofStorage? storage;

  /// Offer "Record the screen" in the panel. When null, testers only. The recording is of the
  /// app itself, a few frames per second, with [SeaproofMask]ed areas blacked out.
  final bool? allowScreenRecording;

  /// A recording stops by itself after this long.
  final Duration maxRecordingDuration;

  /// Whether the colour and logo set in the Seaproof admin are used where the app's own
  /// `SeaproofTheme` sets no primary colour. Default true.
  final bool useProjectBranding;
}

/// Whether the app runs on a phone or tablet, where shake is the natural trigger.
bool get isMobilePlatform =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// The defaults for a mode on the current platform.
Set<SeaproofTrigger> defaultTriggers(SeaproofMode resolvedMode) => switch (resolvedMode) {
  SeaproofMode.production || SeaproofMode.auto => const {},
  SeaproofMode.tester =>
    isMobilePlatform
        ? const {SeaproofTrigger.shake}
        : const {SeaproofTrigger.floatingButton, SeaproofTrigger.keyboardShortcut},
};

/// The default shortcut on the current platform.
ShortcutActivator defaultShortcut() => defaultTargetPlatform == TargetPlatform.macOS
    ? const SingleActivator(LogicalKeyboardKey.keyF, meta: true, alt: true)
    : const SingleActivator(LogicalKeyboardKey.keyF, control: true, alt: true);

/// The types offered by default: testers mostly report bugs, end users mostly give feedback.
List<FeedbackType> defaultTypes(SeaproofMode resolvedMode) => resolvedMode == SeaproofMode.tester
    ? const [FeedbackType.bug, FeedbackType.idea, FeedbackType.feedback, FeedbackType.question]
    : const [FeedbackType.feedback, FeedbackType.idea, FeedbackType.bug, FeedbackType.question];
