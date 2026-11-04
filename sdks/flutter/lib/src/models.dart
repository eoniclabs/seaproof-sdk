import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// What kind of report this is. Matches the API's camelCase names.
enum FeedbackType {
  /// Something does not work as expected.
  bug,

  /// A general opinion: praise, complaint or anything else.
  feedback,

  /// A product suggestion or feature request.
  idea,

  /// A question to the team.
  question,
}

/// How serious a bug is. Testers may set it; triage can change it.
enum FeedbackSeverity {
  /// Cosmetic or minor.
  low,

  /// Annoying, with a workaround.
  medium,

  /// Blocks a flow.
  high,

  /// Crash or data loss.
  critical,
}

/// The mode of the API key's environment. Decides the default triggers and UI.
///
/// Teams name their own environments per project in the Seaproof admin (Dev, QA, UAT...);
/// each one is in one of these modes.
enum SeaproofEnvironmentMode {
  /// Testers: shake or a floating button, screenshots and diagnostics.
  test,

  /// End users of the live app: discreet, anonymous by default.
  production;

  /// Reads the API's value. `staging`, which APIs sent before environments were named per
  /// project, is a tester environment; anything unknown is treated as production.
  static SeaproofEnvironmentMode parse(String? value) => switch (value) {
    'test' || 'staging' => SeaproofEnvironmentMode.test,
    _ => SeaproofEnvironmentMode.production,
  };
}

/// The mode of the API key's environment.
@Deprecated('Environments are named per project now; use SeaproofEnvironmentMode.')
typedef SeaproofEnvironment = SeaproofEnvironmentMode;

/// The kind of file attached to a report.
enum AttachmentKind {
  /// An image of the screen.
  screenshot,

  /// A screen recording.
  recording,

  /// Recent log lines.
  log,

  /// Anything else.
  file,
}

/// The person sending feedback, as the host app knows them.
///
/// Testers and end users do not have Seaproof accounts. Leave it unset for anonymous feedback.
final class SeaproofUser {
  /// Creates a user. All fields are optional.
  const SeaproofUser({this.id, this.name, this.email, this.userHash});

  /// The app's own id for the user.
  final String? id;

  /// Proof from your backend that [id] is this user: `HMAC-SHA256(secret, id)` as hex, with
  /// the identity verification secret from the Seaproof admin. With it, the user's
  /// conversations and votes follow them to every device. Never compute it in the app, where
  /// the secret would leak.
  final String? userHash;

  /// Display name.
  final String? name;

  /// E-mail address, used when the team follows up.
  final String? email;

  /// JSON for the API.
  Map<String, Object?> toJson({bool mayContact = false}) => {
    'externalId': id,
    'name': name,
    'email': email,
    'mayContact': mayContact,
  };
}

/// A file to upload with a report.
final class FeedbackAttachment {
  /// Creates an attachment from bytes in memory.
  const FeedbackAttachment({
    required this.kind,
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  /// What it is.
  final AttachmentKind kind;

  /// File name shown in the inbox.
  final String fileName;

  /// MIME type, for example `image/png`.
  final String contentType;

  /// The content.
  final Uint8List bytes;
}

/// Where the report was sent from. Filled in by the SDK; [custom] is yours.
final class FeedbackContext {
  /// Creates a context.
  const FeedbackContext({
    this.platform,
    this.appVersion,
    this.osVersion,
    this.device,
    this.locale,
    this.screen,
    this.sdkVersion,
    this.commit,
    this.custom = const {},
  });

  /// For example `flutter-android` or `flutter-macos`.
  final String? platform;

  /// The app's version and build number.
  final String? appVersion;

  /// The operating system's version string.
  final String? osVersion;

  /// Device model, when the app provides it.
  final String? device;

  /// For example `sv-SE`.
  final String? locale;

  /// The route or screen the user was on.
  final String? screen;

  /// Version of this SDK.
  final String? sdkVersion;

  /// The commit the app was built from, such as a short git hash.
  final String? commit;

  /// Free-form metadata, for example a build flavour or feature flags.
  final Map<String, String> custom;

  /// JSON for the API.
  Map<String, Object?> toJson() => {
    'platform': platform,
    'appVersion': appVersion,
    'osVersion': osVersion,
    'device': device,
    'locale': locale,
    'screen': screen,
    'sdkVersion': sdkVersion,
    'commit': commit,
    'custom': custom,
  };
}

/// A report ready to send.
final class FeedbackDraft {
  /// Creates a draft.
  const FeedbackDraft({
    required this.type,
    required this.description,
    this.title,
    this.severity,
    this.user,
    this.mayContact = false,
    this.attachments = const [],
    this.linkedTo,
  });

  /// What kind of report.
  final FeedbackType type;

  /// What happened or what the user wants. Required by the API.
  final String description;

  /// A short title. The API uses the first line of [description] when it is empty.
  final String? title;

  /// How serious it is, for bugs.
  final FeedbackSeverity? severity;

  /// Who sent it, or null when anonymous.
  final SeaproofUser? user;

  /// The user agreed to be contacted about this report.
  final bool mayContact;

  /// Files to upload.
  final List<FeedbackAttachment> attachments;

  /// The known problem or public idea this is about, from [SeaproofClient.suggest]. The team sees the link.
  final String? linkedTo;
}

/// What the API returned for a sent report.
final class SubmittedFeedback {
  /// Creates a result.
  const SubmittedFeedback({required this.id, required this.number, this.failedUploads = const []});

  /// The item's id.
  final String id;

  /// The per-project number, shown as #42 in the inbox.
  final int number;

  /// Attachments that could not be uploaded. The report itself was saved without them.
  final List<FeedbackAttachment> failedUploads;
}

/// The project an API key belongs to.
final class SeaproofProject {
  /// Creates a project description.
  const SeaproofProject({
    required this.id,
    required this.name,
    required this.mode,
    this.environmentId,
    this.environmentName,
    this.branding = const SeaproofBranding(),
  });

  /// The project id.
  final String id;

  /// The project name.
  final String name;

  /// The mode of the key's environment: testers or end users.
  final SeaproofEnvironmentMode mode;

  /// The id of the key's environment; null from APIs before environments were named per project.
  final String? environmentId;

  /// The team's name for the key's environment, such as `UAT`; null from older APIs.
  final String? environmentName;

  /// The mode of the key's environment.
  @Deprecated('Use mode; the environment itself is environmentName.')
  SeaproofEnvironmentMode get environment => mode;

  /// The project's colour and logo, as set in the admin.
  final SeaproofBranding branding;
}

/// A project's look, set in the Seaproof admin. The app's own `SeaproofTheme` wins over it.
@immutable
final class SeaproofBranding {
  /// Creates branding. Both fields are optional.
  const SeaproofBranding({this.primaryColor, this.logoVersion});

  /// The main colour as `#rrggbb`, or null.
  final String? primaryColor;

  /// Changes whenever the logo does; null when the project has none.
  final String? logoVersion;

  /// [primaryColor] as a [Color], or null when unset or malformed.
  Color? get color {
    final hex = primaryColor;
    if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return null;
    }

    return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
  }
}

/// A failed call to the Seaproof API.
final class SeaproofException implements Exception {
  /// Creates an exception.
  const SeaproofException(this.code, this.message, {this.statusCode, String? helpUrl}) : _helpUrl = helpUrl;

  /// Where every error code is explained, with how to fix it.
  static const errorReferenceUrl = 'https://seaproof.io/docs/errors';

  /// A stable code such as `feedback.description_invalid` or `network.unavailable`.
  final String code;

  /// A developer-facing message. Do not show it to users.
  final String message;

  /// The HTTP status, when the server answered.
  final int? statusCode;

  final String? _helpUrl;

  /// The code's entry in the error reference: what went wrong and how to fix it.
  String get helpUrl => _helpUrl ?? '$errorReferenceUrl#$code';

  @override
  String toString() => 'SeaproofException($code, $statusCode): $message How to fix: $helpUrl';
}

/// How an item's status reads to the person who sent it.
enum PublicStatus {
  /// Not looked at yet.
  received,

  /// The team is looking at it.
  underReview,

  /// Being worked on.
  inProgress,

  /// Fixed or shipped.
  done,

  /// Will not be done.
  closed,
}

DateTime _date(Object? value) => DateTime.parse(value! as String);

DateTime? _optionalDate(Object? value) => value == null ? null : DateTime.parse(value as String);

/// Feedback sent from this installation.
@immutable
final class OwnFeedback {
  /// Creates an item.
  const OwnFeedback({
    required this.id,
    required this.number,
    required this.type,
    required this.title,
    required this.status,
    required this.replies,
    required this.createdAt,
    this.lastReplyAt,
  });

  /// Reads the API's JSON.
  factory OwnFeedback.fromJson(Map<String, Object?> json) => OwnFeedback(
    id: json['id']! as String,
    number: (json['number']! as num).toInt(),
    type: FeedbackType.values.byName(json['type']! as String),
    title: json['title']! as String,
    status: PublicStatus.values.byName(json['status']! as String),
    replies: (json['replies']! as num).toInt(),
    createdAt: _date(json['createdAt']),
    lastReplyAt: _optionalDate(json['lastReplyAt']),
  );

  /// Item id.
  final String id;

  /// Per-project number.
  final int number;

  /// Kind of feedback.
  final FeedbackType type;

  /// Title.
  final String title;

  /// Where it stands.
  final PublicStatus status;

  /// Replies from the team.
  final int replies;

  /// When it was sent.
  final DateTime createdAt;

  /// When the team last replied.
  final DateTime? lastReplyAt;
}

/// A message in the conversation about an item.
@immutable
final class ConversationMessage {
  /// Creates a message.
  const ConversationMessage({required this.id, required this.fromTeam, required this.body, required this.createdAt});

  /// Reads the API's JSON.
  factory ConversationMessage.fromJson(Map<String, Object?> json) => ConversationMessage(
    id: json['id']! as String,
    fromTeam: json['from'] == 'team',
    body: json['body']! as String,
    createdAt: _date(json['createdAt']),
  );

  /// Message id.
  final String id;

  /// From the team; otherwise from this user.
  final bool fromTeam;

  /// Text.
  final String body;

  /// When it was written.
  final DateTime createdAt;
}

/// An item from this installation with its conversation.
@immutable
final class OwnFeedbackDetail {
  /// Creates a detail.
  const OwnFeedbackDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.messages,
  });

  /// Reads the API's JSON.
  factory OwnFeedbackDetail.fromJson(Map<String, Object?> json) => OwnFeedbackDetail(
    id: json['id']! as String,
    title: json['title']! as String,
    description: json['description']! as String,
    status: PublicStatus.values.byName(json['status']! as String),
    messages: [
      for (final m in (json['messages']! as List<Object?>).cast<Map<String, Object?>>())
        ConversationMessage.fromJson(m),
    ],
  );

  /// Item id.
  final String id;

  /// Title.
  final String title;

  /// What the user wrote.
  final String description;

  /// Where it stands.
  final PublicStatus status;

  /// Replies and the user's answers, oldest first.
  final List<ConversationMessage> messages;

  /// A copy with [message] added.
  OwnFeedbackDetail withMessage(ConversationMessage message) => OwnFeedbackDetail(
    id: id,
    title: title,
    description: description,
    status: status,
    messages: [...messages, message],
  );
}

/// An idea the team published on the project's idea board.
@immutable
final class PublicIdea {
  /// Creates an idea.
  const PublicIdea({
    required this.id,
    required this.title,
    required this.status,
    required this.votes,
    required this.voted,
    this.summary,
  });

  /// Reads the API's JSON.
  factory PublicIdea.fromJson(Map<String, Object?> json) => PublicIdea(
    id: json['id']! as String,
    title: json['title']! as String,
    summary: json['summary'] as String?,
    status: PublicStatus.values.byName(json['status']! as String),
    votes: (json['votes']! as num).toInt(),
    voted: json['voted']! as bool,
  );

  /// Item id.
  final String id;

  /// Title.
  final String title;

  /// The team's description, if any.
  final String? summary;

  /// Where it stands.
  final PublicStatus status;

  /// Number of votes.
  final int votes;

  /// This installation has voted for it.
  final bool voted;

  /// A copy with this installation's vote set to [value].
  PublicIdea withVote({required bool value}) => value == voted
      ? this
      : PublicIdea(
          id: id,
          title: title,
          summary: summary,
          status: status,
          votes: votes + (value ? 1 : -1),
          voted: value,
        );
}

/// What Seaproof Assist offers in a project. Both are off unless the team turned them on.
final class AssistSettings {
  /// Creates settings.
  const AssistSettings({this.suggestions = false, this.followUpQuestions = false});

  /// Reads the API's JSON.
  factory AssistSettings.fromJson(Map<String, Object?> json) => AssistSettings(
    suggestions: json['suggestions'] as bool? ?? false,
    followUpQuestions: json['followUpQuestions'] as bool? ?? false,
  );

  /// Everything off.
  static const off = AssistSettings();

  /// Known problems and public ideas like what the user is writing.
  final bool suggestions;

  /// Up to two questions about what a report is missing, before it is sent.
  final bool followUpQuestions;
}

/// A known problem ([FeedbackType.bug]) or public idea that matches a draft.
final class Suggestion {
  /// Creates a suggestion.
  const Suggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.votes,
    this.summary,
  });

  /// Reads the API's JSON.
  factory Suggestion.fromJson(Map<String, Object?> json) => Suggestion(
    id: json['id']! as String,
    type: FeedbackType.values.byName(json['type']! as String),
    title: json['title']! as String,
    summary: json['summary'] as String?,
    status: PublicStatus.values.byName(json['status']! as String),
    votes: (json['votes']! as num).toInt(),
  );

  /// Item id.
  final String id;

  /// [FeedbackType.bug] or [FeedbackType.idea].
  final FeedbackType type;

  /// The team's public title.
  final String title;

  /// The team's public description, if any.
  final String? summary;

  /// Where it stands.
  final PublicStatus status;

  /// Votes, for ideas.
  final int votes;
}

/// Follow-up questions about a draft.
final class ReviewResult {
  /// Creates a result.
  const ReviewResult({this.questions = const [], this.limited = false});

  /// Reads the API's JSON.
  factory ReviewResult.fromJson(Map<String, Object?> json) => ReviewResult(
    questions: [for (final q in (json['questions'] as List<Object?>? ?? const [])) q! as String],
    limited: json['limited'] as bool? ?? false,
  );

  /// What the team would need to know. Empty when the draft is complete.
  final List<String> questions;

  /// No questions this time because the organization's monthly Assist limit is reached.
  final bool limited;
}
