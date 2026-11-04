/// Seaproof SDK for Flutter: bug reports from testers and feedback and ideas from end
/// users, with screenshots, annotations and app context.
library;

export 'src/client.dart' show SeaproofClient, newConversationId;
export 'src/config.dart' show SeaproofConfig, SeaproofMode, SeaproofTrigger;
export 'src/controller.dart' show Seaproof, SeaproofController, SeaproofNavigatorObserver, ShowRequest;
export 'src/diagnostics.dart' show DiagnosticEntry, DiagnosticKind, Diagnostics;
export 'src/models.dart';
export 'src/network.dart' show SeaproofHttpClient;
export 'src/screen_recorder.dart' show SeaproofRecording;
export 'src/storage.dart' show MemorySeaproofStorage, PreferencesSeaproofStorage, SeaproofStorage;
export 'src/strings.dart' show SeaproofStrings;
export 'src/theme.dart' show SeaproofPanelStyle, SeaproofTheme;
export 'src/widgets/feedback_button.dart' show SeaproofFeedbackButton;
export 'src/widgets/host.dart' show SeaproofHost;
export 'src/widgets/mask.dart' show SeaproofMask;
