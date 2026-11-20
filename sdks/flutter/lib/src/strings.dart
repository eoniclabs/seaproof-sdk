import 'package:flutter/widgets.dart';

import 'models.dart';

/// The SDK's own texts. English and Swedish are built in; pick another language by
/// passing your own instance to [SeaproofHost.strings].
@immutable
class SeaproofStrings {
  /// Creates a set of texts. Every field is required so no language is half translated.
  const SeaproofStrings({
    required this.title,
    required this.typeLabels,
    required this.descriptionHint,
    required this.descriptionRequired,
    required this.emailLabel,
    required this.mayContact,
    required this.includeScreenshot,
    required this.markScreenshot,
    required this.send,
    required this.sending,
    required this.cancel,
    required this.close,
    required this.hideKeyboard,
    required this.thanks,
    required this.thanksDetail,
    required this.failed,
    required this.annotateTitle,
    required this.undo,
    required this.clear,
    required this.done,
    required this.openFeedback,
    required this.tabSend,
    required this.tabOwnFeedback,
    required this.tabIdeas,
    required this.statusLabels,
    required this.oneReply,
    required this.manyReplies,
    required this.newReply,
    required this.fromTeam,
    required this.fromYou,
    required this.reply,
    required this.back,
    required this.loadFailed,
    required this.suggestIdea,
    required this.voteFor,
    required this.removeVote,
    required this.recordScreen,
    required this.recordingNow,
    required this.stopRecording,
    required this.recordingAttached,
    required this.removeRecording,
    required this.suggestionsTitle,
    required this.similarIdeasTitle,
    required this.sameProblem,
    required this.sameAs,
    required this.notSameProblem,
    required this.questionsTitle,
    required this.questionsHint,
    required this.sendAsIs,
    required this.checking,
    required this.testMode,
    required this.greeting,
    required this.greetingTester,
    required this.savedShow,
    required this.savedBug,
    required this.savedIdea,
    required this.savedQuestion,
    required this.savedFeedback,
    required this.savedWithQuestion,
    required this.savedLinked,
    required this.addedMessage,
    required this.addedScreenshot,
    required this.addedRecording,
    required this.addFailed,
    required this.markOnScreen,
    required this.addHint,
    required this.screenshotLabel,
    required this.screenshotMarked,
    required this.removeScreenshot,
    required this.toolBox,
    required this.toolArrow,
    required this.toolPen,
    required this.toolHide,
    this.addEmail = 'Add e-mail',
    this.editEmail = 'Edit e-mail',
    this.closeChat = 'Close chat',
    this.applyScreenshotEdits = 'Save changes',
    this.attachments = 'Attachments',
    this.screenRecording = 'Screen recording',
    this.statusUpdates = const {},
    this.pasteScreenshot = 'Paste screenshot',
    this.pastedScreenshot = 'Pasted screenshot',
    this.noClipboardScreenshot = 'There is no screenshot to paste. Copy an image first.',
    this.pasteScreenshotFailed = 'The image could not be pasted. Try a smaller screenshot.',
  });

  /// English.
  static const en = SeaproofStrings(
    title: 'Send feedback',
    typeLabels: {
      FeedbackType.bug: 'Something is wrong',
      FeedbackType.feedback: 'Feedback',
      FeedbackType.idea: 'Idea',
      FeedbackType.question: 'Question',
    },
    descriptionHint: 'What happened, or what would you like?',
    descriptionRequired: 'Please write a few words.',
    emailLabel: 'E-mail (optional)',
    mayContact: 'You may contact me about this',
    includeScreenshot: 'Attach a screenshot',
    markScreenshot: 'Mark up',
    send: 'Send',
    sending: 'Sending…',
    cancel: 'Cancel',
    close: 'Close',
    hideKeyboard: 'Hide keyboard',
    thanks: 'Thank you!',
    thanksDetail: 'Your feedback has been sent.',
    failed: 'It could not be sent. Check your connection and try again.',
    annotateTitle: 'Mark up the screenshot',
    undo: 'Undo',
    clear: 'Clear',
    done: 'Done',
    openFeedback: 'Send feedback',
    tabSend: 'Send',
    tabOwnFeedback: 'Your feedback',
    tabIdeas: 'Ideas',
    statusLabels: {
      PublicStatus.received: 'Received',
      PublicStatus.underReview: 'Under review',
      PublicStatus.inProgress: 'In progress',
      PublicStatus.done: 'Done',
      PublicStatus.closed: 'Closed',
    },
    statusUpdates: {
      PublicStatus.received: 'Your report was reopened.',
      PublicStatus.underReview: 'The team is reviewing your report.',
      PublicStatus.inProgress: 'The team is working on your report.',
      PublicStatus.done: 'The team marked your report as resolved.',
      PublicStatus.closed: 'The team closed your report.',
    },
    oneReply: '1 reply',
    manyReplies: '{count} replies',
    newReply: 'New reply',
    fromTeam: 'Team',
    fromYou: 'You',
    reply: 'Reply',
    back: 'Back',
    loadFailed: 'It could not be loaded. Check your connection and try again.',
    suggestIdea: 'Suggest an idea',
    voteFor: 'Vote for {title}, {count} votes',
    removeVote: 'Remove vote for {title}, {count} votes',
    recordScreen: 'Record the screen',
    recordingNow: 'Recording',
    stopRecording: 'Stop',
    recordingAttached: 'Screen recording, {duration}',
    removeRecording: 'Remove',
    suggestionsTitle: 'The team may already know about this',
    similarIdeasTitle: 'Similar ideas',
    sameProblem: 'Same for me',
    sameAs: 'Same as',
    notSameProblem: 'Not the same problem',
    questionsTitle: 'A little more would help the team',
    questionsHint: 'Add it to your text above, or send it as it is.',
    sendAsIs: 'Send as it is',
    checking: 'Checking…',
    testMode: 'Test mode',
    greeting: 'Hi! What would you like to tell us?',
    greetingTester: "What did you find? Describe it and send. A screenshot and the app's logs come along.",
    savedShow: 'Report #{number} was sent. You can add more details here.',
    savedBug: 'Report #{number} was sent. You can add more details here.',
    savedIdea: 'Thanks for the idea, the team has it as #{number}. What would it help you do?',
    savedQuestion: 'Thanks! The team answers here, and you find it under Your feedback (#{number}).',
    savedFeedback: 'Thanks for telling us, it is saved as #{number}. Anything to add?',
    savedWithQuestion: 'Thanks, it is saved as #{number}. {question}',
    savedLinked:
        'Thanks! It is linked to the problem the team already knows about (#{number}). You will see updates under Your feedback.',
    addedMessage: 'Added to #{number}.',
    addedScreenshot: 'The screenshot is attached to #{number}.',
    addedRecording: 'The recording is attached to #{number}.',
    addFailed: 'It could not be added. Check your connection and try again.',
    markOnScreen: 'Mark up screenshot',
    addHint: 'Add something…',
    screenshotLabel: 'Screenshot',
    screenshotMarked: 'Screenshot, marked up',
    removeScreenshot: 'Remove the screenshot',
    toolBox: 'Circle',
    toolArrow: 'Arrow',
    toolPen: 'Draw',
    toolHide: 'Hide',
  );

  /// Swedish.
  static const sv = SeaproofStrings(
    title: 'Skicka feedback',
    typeLabels: {
      FeedbackType.bug: 'Något är fel',
      FeedbackType.feedback: 'Synpunkt',
      FeedbackType.idea: 'Förslag',
      FeedbackType.question: 'Fråga',
    },
    descriptionHint: 'Vad hände, eller vad önskar du?',
    descriptionRequired: 'Skriv några ord.',
    emailLabel: 'E-post (valfritt)',
    addEmail: 'Lägg till e-post',
    editEmail: 'Ändra e-post',
    closeChat: 'Stäng chatten',
    applyScreenshotEdits: 'Spara ändringar',
    attachments: 'Bilagor',
    screenRecording: 'Skärminspelning',
    mayContact: 'Ni får kontakta mig om detta',
    includeScreenshot: 'Bifoga skärmbild',
    markScreenshot: 'Markera',
    send: 'Skicka',
    sending: 'Skickar…',
    cancel: 'Avbryt',
    close: 'Stäng',
    hideKeyboard: 'Dölj tangentbord',
    thanks: 'Tack!',
    thanksDetail: 'Din feedback är skickad.',
    failed: 'Det gick inte att skicka. Kontrollera anslutningen och försök igen.',
    annotateTitle: 'Markera på skärmbilden',
    undo: 'Ångra',
    clear: 'Rensa',
    done: 'Klar',
    openFeedback: 'Skicka feedback',
    tabSend: 'Skicka',
    tabOwnFeedback: 'Din feedback',
    tabIdeas: 'Idéer',
    statusLabels: {
      PublicStatus.received: 'Mottagen',
      PublicStatus.underReview: 'Under granskning',
      PublicStatus.inProgress: 'På gång',
      PublicStatus.done: 'Klar',
      PublicStatus.closed: 'Avslutad',
    },
    statusUpdates: {
      PublicStatus.received: 'Din rapport har öppnats igen.',
      PublicStatus.underReview: 'Teamet granskar din rapport.',
      PublicStatus.inProgress: 'Teamet arbetar med din rapport.',
      PublicStatus.done: 'Teamet har markerat din rapport som löst.',
      PublicStatus.closed: 'Teamet har avslutat din rapport.',
    },
    oneReply: '1 svar',
    manyReplies: '{count} svar',
    newReply: 'Nytt svar',
    fromTeam: 'Teamet',
    fromYou: 'Du',
    reply: 'Svara',
    back: 'Tillbaka',
    loadFailed: 'Det gick inte att hämta. Kontrollera anslutningen och försök igen.',
    suggestIdea: 'Föreslå en idé',
    voteFor: 'Rösta på {title}, {count} röster',
    removeVote: 'Ta bort rösten på {title}, {count} röster',
    recordScreen: 'Spela in skärmen',
    recordingNow: 'Spelar in',
    stopRecording: 'Stoppa',
    recordingAttached: 'Skärminspelning, {duration}',
    removeRecording: 'Ta bort',
    suggestionsTitle: 'Teamet kanske redan känner till det här',
    similarIdeasTitle: 'Liknande idéer',
    sameProblem: 'Samma för mig',
    sameAs: 'Samma som',
    notSameProblem: 'Inte samma problem',
    questionsTitle: 'Lite mer skulle hjälpa teamet',
    questionsHint: 'Skriv det i texten ovan, eller skicka som det är.',
    sendAsIs: 'Skicka som det är',
    checking: 'Kollar…',
    testMode: 'Testläge',
    greeting: 'Hej! Vad vill du berätta?',
    greetingTester: 'Vad hittade du? Beskriv det och skicka. Skärmbild och appens loggar följer med.',
    savedShow: 'Rapport #{number} är skickad. Du kan lägga till fler detaljer här.',
    savedBug: 'Rapport #{number} är skickad. Du kan lägga till fler detaljer här.',
    savedIdea: 'Tack för idén, teamet har den som #{number}. Vad skulle den hjälpa dig med?',
    savedQuestion: 'Tack! Teamet svarar här, och du hittar det under Din feedback (#{number}).',
    savedFeedback: 'Tack för att du berättar, det är sparat som #{number}. Något att lägga till?',
    savedWithQuestion: 'Tack, det är sparat som #{number}. {question}',
    savedLinked:
        'Tack! Det är kopplat till problemet som teamet redan känner till (#{number}). Du ser uppdateringar under Din feedback.',
    addedMessage: 'Tillagt i #{number}.',
    addedScreenshot: 'Skärmbilden är bifogad till #{number}.',
    addedRecording: 'Inspelningen är bifogad till #{number}.',
    addFailed: 'Det gick inte att lägga till. Kontrollera anslutningen och försök igen.',
    markOnScreen: 'Markera skärmbild',
    addHint: 'Lägg till något…',
    screenshotLabel: 'Skärmbild',
    screenshotMarked: 'Skärmbild, markerad',
    removeScreenshot: 'Ta bort skärmbilden',
    toolBox: 'Ring in',
    toolArrow: 'Pil',
    toolPen: 'Rita',
    toolHide: 'Dölj',
    pasteScreenshot: 'Klistra in skärmbild',
    pastedScreenshot: 'Inklistrad skärmbild',
    noClipboardScreenshot: 'Det finns ingen skärmbild att klistra in. Kopiera en bild först.',
    pasteScreenshotFailed: 'Bilden gick inte att klistra in. Prova med en mindre skärmbild.',
  );

  /// The built-in texts for [locale]: Swedish for `sv`, English otherwise.
  static SeaproofStrings forLocale(Locale? locale) => locale?.languageCode == 'sv' ? sv : en;

  /// Panel heading.
  final String title;

  /// Label per feedback type.
  final Map<FeedbackType, String> typeLabels;

  /// Placeholder in the description field.
  final String descriptionHint;

  /// Shown when the description is empty.
  final String descriptionRequired;

  /// Label of the optional e-mail field.
  final String emailLabel;

  /// Opens the e-mail field.
  final String addEmail;

  /// Opens the e-mail field when it already has an address.
  final String editEmail;

  /// Consent checkbox.
  final String mayContact;

  /// Screenshot toggle.
  final String includeScreenshot;

  /// Button that opens the annotation view.
  final String markScreenshot;

  /// Send button.
  final String send;

  /// Send button while sending.
  final String sending;

  /// Cancel button.
  final String cancel;

  /// Close button.
  final String close;

  /// Dismisses the keyboard without closing the panel or losing the draft.
  final String hideKeyboard;

  /// Success heading.
  final String thanks;

  /// Success text.
  final String thanksDetail;

  /// Error text when sending fails.
  final String failed;

  /// Annotation view heading.
  final String annotateTitle;

  /// Undo the last stroke.
  final String undo;

  /// Remove all strokes.
  final String clear;

  /// Finish annotating.
  final String done;

  /// Closes the conversation after the report has been sent.
  final String closeChat;

  /// Applies the edits made to a screenshot.
  final String applyScreenshotEdits;

  /// Heading for attachments in a submitted conversation.
  final String attachments;

  /// Label for a saved screen recording.
  final String screenRecording;

  /// Reporter-facing messages for public status changes.
  final Map<PublicStatus, String> statusUpdates;

  /// Text for a status entry in the conversation.
  String statusUpdate(PublicStatus status) => statusUpdates[status] ?? statusLabels[status]!;

  /// Tooltip and semantics label of the floating button and [SeaproofFeedbackButton].
  final String openFeedback;

  /// Tab with the form.
  final String tabSend;

  /// Tab with the user's own feedback and the team's replies.
  final String tabOwnFeedback;

  /// Tab with the published ideas.
  final String tabIdeas;

  /// Label per status, as the user sees it.
  final Map<PublicStatus, String> statusLabels;

  /// Reply count of one.
  final String oneReply;

  /// Reply count; `{count}` is replaced.
  final String manyReplies;

  /// Marks an item with a reply the user has not read.
  final String newReply;

  /// Author of the team's messages.
  final String fromTeam;

  /// Author of the user's own messages.
  final String fromYou;

  /// Label of the answer field.
  final String reply;

  /// Back from a conversation to the list.
  final String back;

  /// Shown when the list or a conversation cannot be loaded.
  final String loadFailed;

  /// Opens the form with the idea type.
  final String suggestIdea;

  /// Semantics label of the vote button; `{title}` and `{count}` are replaced.
  final String voteFor;

  /// Semantics label of the button that takes a vote back; `{title}` and `{count}` are replaced.
  final String removeVote;

  /// Starts a screen recording from the panel.
  final String recordScreen;

  /// Shown, with the time, while recording.
  final String recordingNow;

  /// Stops the recording.
  final String stopRecording;

  /// Describes the attached recording; `{duration}` is replaced, for example with 0:12.
  final String recordingAttached;

  /// Removes the attached recording.
  final String removeRecording;

  /// Heading over known problems like the draft.
  final String suggestionsTitle;

  /// Heading over public ideas like the draft.
  final String similarIdeasTitle;

  /// Links the report to a known problem.
  final String sameProblem;

  /// Shown before the title of the linked known problem.
  final String sameAs;

  /// Removes the link to a known problem.
  final String notSameProblem;

  /// Heading over the follow-up questions.
  final String questionsTitle;

  /// Under the follow-up questions.
  final String questionsHint;

  /// Send button once follow-up questions are shown.
  final String sendAsIs;

  /// Send button while the draft is checked for follow-up questions.
  final String checking;

  /// Shown to testers at the top of the panel.
  final String testMode;

  /// The first line in the conversation, for end users.
  final String greeting;

  /// The first line in the conversation, for testers.
  final String greetingTester;

  /// After a bug is saved, when it can be shown; `{number}` is replaced.
  final String savedShow;

  /// After a bug is saved; `{number}` is replaced.
  final String savedBug;

  /// After an idea is saved; `{number}` is replaced.
  final String savedIdea;

  /// After a question is saved; `{number}` is replaced.
  final String savedQuestion;

  /// After feedback is saved; `{number}` is replaced.
  final String savedFeedback;

  /// After a report is saved, with Seaproof Assist's first question; `{number}` and `{question}` are replaced.
  final String savedWithQuestion;

  /// After a report is linked to a known problem; `{number}` is replaced.
  final String savedLinked;

  /// After a later message is added; `{number}` is replaced.
  final String addedMessage;

  /// After a screenshot is added; `{number}` is replaced.
  final String addedScreenshot;

  /// After a recording is added; `{number}` is replaced.
  final String addedRecording;

  /// When a later message or file could not be added.
  final String addFailed;

  /// Opens the screenshot to mark it up.
  final String markOnScreen;

  /// Placeholder in the message field once the report is saved.
  final String addHint;

  /// The screenshot waiting to be sent, or sent.
  final String screenshotLabel;

  /// A marked-up screenshot.
  final String screenshotMarked;

  /// Removes the screenshot waiting to be sent.
  final String removeScreenshot;

  /// Annotation tool: a box around something.
  final String toolBox;

  /// Annotation tool: an arrow.
  final String toolArrow;

  /// Annotation tool: free drawing.
  final String toolPen;

  /// Annotation tool: hides something private.
  final String toolHide;

  /// Reads a screenshot from the clipboard at the reporter's request.
  final String pasteScreenshot;

  /// Label for an attachment pasted into the draft.
  final String pastedScreenshot;

  /// Shown when there is no image on the clipboard.
  final String noClipboardScreenshot;

  /// Shown when the image could not be read or is too large to attach.
  final String pasteScreenshotFailed;

  /// [recordingAttached] for [duration].
  String recordingLabel(Duration duration) => recordingAttached.replaceAll('{duration}', formatDuration(duration));

  /// Minutes and seconds, such as 0:07.
  static String formatDuration(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  /// [oneReply] or [manyReplies] for [count].
  String replies(int count) => count == 1 ? oneReply : manyReplies.replaceAll('{count}', '$count');

  /// [voteFor] or [removeVote] for [idea].
  String voteLabel(PublicIdea idea) =>
      (idea.voted ? removeVote : voteFor).replaceAll('{title}', idea.title).replaceAll('{count}', '${idea.votes}');

  /// [template] with `{number}` and `{question}` filled in.
  static String fill(String template, {int? number, String? question}) =>
      template.replaceAll('{number}', number == null ? '' : '$number').replaceAll('{question}', question ?? '');
}
