# Seaproof for Flutter

Bug reports from testers and feedback and ideas from end users, sent from your Flutter app
on Android, iOS, macOS, Windows, Linux and web. Each report carries a screenshot the user can
mark up, along with app and device context and, for testers, recent log lines.

## Install

```sh
flutter pub add seaproof
```

Create a project and an API key in the [Seaproof admin](https://app.seaproof.io) first; the
[quickstart](https://seaproof.io/docs/quickstart.md) walks through
the whole setup.

> **Beta.** While Seaproof is in beta, apps report to a test deployment rather than
> https://api.seaproof.io. Pass its address as `endpoint`, for example
> `SeaproofConfig(apiKey: ..., endpoint: Uri.parse(const String.fromEnvironment('SEAPROOF_ENDPOINT')))`.
> The admin's install steps and the MCP tool `get_sdk_setup` show the right address.

## Set up

Create an API key under **Projects → API keys** in the Seaproof admin. Make one key for each
environment. You name the environments per project (Dev, QA, UAT, Prod...), and each is in
test mode, for testers, or production mode, for end users. Reports are tagged with the key's
environment, so the inbox can keep them apart.

```dart
void main() {
  Seaproof.init(const SeaproofConfig(apiKey: String.fromEnvironment('SEAPROOF_KEY')));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorObservers: [SeaproofNavigatorObserver()], // reports the route name as the screen
    builder: (context, child) => SeaproofHost(child: child!),
    home: const HomePage(),
  );
}
```

Run with the key, keeping it out of source control:

```sh
flutter run --dart-define=SEAPROOF_KEY=sp_... --dart-define=SEAPROOF_COMMIT=$(git rev-parse --short HEAD)
```

`SEAPROOF_COMMIT` is optional and links every report to the build it came from. With a test
key, shake the device (or press the floating button on desktop) to send a report. Step-by-step
guide: [Flutter](https://seaproof.io/docs/flutter.md); a runnable app is in `example/`.

On iPhone and iPad, use **Paste** in the message field to attach a copied image. Tap the
attachment row to mark up the screenshot or use its remove button to discard it before sending.
Use **@** below the message field to see or add an optional e-mail address.

`SeaproofHost` belongs in `MaterialApp.builder`, which places it inside your theme and
localizations. It also works with `MaterialApp.router`.

## Testers and end users

By default (`SeaproofMode.auto`) the SDK follows the key's environment:

| | Key in a test-mode environment | Key in a production-mode environment |
|---|---|---|
| Phone or tablet | Shake to open | Nothing visible |
| Desktop or web | Floating button and Ctrl+Alt+F (Cmd+Option+F on macOS) | Nothing visible |
| Default type | Bug | Feedback |
| Screenshot | Attached; the user can remove it | Only if the user ticks it |
| Diagnostics (logs, console, network, errors) | Attached | Not sent |
| Contact consent | Assumed | Asked once the user gives an e-mail |

The SDK behaves as in production until it knows the environment, and also when the
environment cannot be fetched. That way testing UI is never shown to end users by mistake.

In production, you choose where users open the panel, for example a menu item or the help
page:

```dart
const SeaproofFeedbackButton.listTile()                          // "Send feedback"
const SeaproofFeedbackButton(type: FeedbackType.idea, label: 'Suggest a feature')
Seaproof.show(type: FeedbackType.bug)                            // from your own widget
```

You can override any of these defaults:

```dart
SeaproofConfig(
  apiKey: '...',
  mode: SeaproofMode.tester,                       // or production
  triggers: {SeaproofTrigger.shake, SeaproofTrigger.floatingButton},
  shortcut: const SingleActivator(LogicalKeyboardKey.f1),
  types: [FeedbackType.idea, FeedbackType.bug],
  includeLogs: false,
)
```

## Diagnostics

The SDK keeps the last 500 diagnostic entries on the device. Testers' reports include them
as `diagnostics.ndjson`, which the inbox shows as a timeline. Nothing is sent outside a
report.

| What | How |
|---|---|
| Your own log lines | `Seaproof.log('opened cart')` |
| Console | `debugPrint` automatically; `print` too if you start the app with `Seaproof.runZoned` |
| Uncaught errors | `FlutterError.onError` and `PlatformDispatcher.onError`, chained so your own handlers (for example Sentry) still run |
| HTTP requests | `SeaproofHttpClient(http.Client())`, or `Seaproof.recordRequest(...)` from your own interceptor |
| Device model | Read automatically: `Google Pixel 8`, `iPhone16,1`, `MacBookPro18,3` |

For requests, only the method, the URL with query values replaced by `*`, the status, the
duration and the size are recorded. Bodies and headers are never recorded.

A Dio interceptor takes a few lines:

```dart
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (o, h) { o.extra['seaproof.start'] = DateTime.now(); h.next(o); },
  onResponse: (r, h) { _record(r.requestOptions, r.statusCode); h.next(r); },
  onError: (e, h) { _record(e.requestOptions, e.response?.statusCode, e.message); h.next(e); },
));

void _record(RequestOptions o, int? status, [String? error]) => Seaproof.recordRequest(
  method: o.method, url: o.uri, status: status, error: error,
  duration: DateTime.now().difference(o.extra['seaproof.start'] as DateTime),
);
```

Turn on `SeaproofConfig(reportCrashes: true)` to send a bug report automatically when an
uncaught error happens. Each report includes the diagnostics. The SDK sends each distinct
error once, and at most three per session. The inbox marks these as *Automatic crash
report*. You can switch off parts of the capture with `captureConsole` and `captureErrors`,
and choose what is sent with `includeDiagnostics`.

## Users

Feedback is anonymous unless you identify the user. Call `identify` on sign-in and pass
`null` on sign-out:

```dart
Seaproof.identify(SeaproofUser(id: user.id, name: user.name, email: user.email));
```

When nobody is signed in, users can leave an e-mail address and say whether you may
contact them.

## Screen recording

Testers get **Record the screen** in the panel. The panel hides, a bar with a timer and
**Stop** appears, and the recording is attached when they stop (after 30 seconds at most,
see `maxRecordingDuration`). Offer it to end users too with `allowScreenRecording: true`.

The SDK records the app itself, two frames per second, with `SeaproofMask` areas blacked
out, so it works the same on every platform without native permissions and never shows other
apps or system UI. Still screens are merged, so a typical recording is a few hundred kilobytes.
It is sent as an animated PNG that plays in the inbox.

## Replies and ideas

When the team replies to a report in the inbox, the user sees it under **Your feedback** in
the panel and can answer. Ideas the team publishes show under **Ideas**, where users vote.
Both tabs appear only when there is something in them, so a first-time user sees just the
form. Turn them off with `showOwnFeedback: false` or `showIdeas: false`.

No account is needed: the SDK creates a random reporter key per installation and keeps it in
shared preferences (pass `storage:` to use your own). Show a badge on your own button:

```dart
await Seaproof.checkReplies();
ValueListenableBuilder(
  valueListenable: Seaproof.unreadReplies,
  builder: (context, unread, _) => Badge(isLabelVisible: unread > 0, child: const Icon(Icons.feedback)),
);
```

### Across devices

By default a conversation stays with the installation it was sent from. To let a signed-in
user see theirs on every device, turn on **Identity verification** under API keys in the
admin, have your backend sign the user's id with the secret, and pass the signature:

```dart
// Backend: HMAC-SHA256(secret, userId) as hex. Never compute it in the app.
Seaproof.identify(SeaproofUser(id: user.id, name: user.name, userHash: user.seaproofHash));
```

Votes then count once per user. A wrong or missing hash is ignored, and the installation's own
items still show.

## Seaproof Assist

The panel is a short conversation. The first message saves the report, so nothing is lost if
the user stops there; everything after it (more text, a marked-up screenshot, a recording) is
added to the same report. Testers can always tap **Done**. Without Assist, or when the plan's
quota is used up, the panel asks with fixed lines instead.

When the team turns Assist on in the admin, the panel helps with no code changes:

- **Suggestions:** known problems and public ideas like the draft appear under the text. "Same
  for me" sends the report linked to the known one (`FeedbackDraft.linkedTo`); ideas can be
  voted for there. Only the title and summary the team made public are shown.
- **Follow-up questions:** after the report is saved, an AI model asks what it is missing, one
  question at a time and at most five. The answers are added to the report. A failing model
  never stops a report.

`controller.addAttachments(id, files)` adds files to a report the user already sent.

The calls are on the client too: `assistSettings()`, `suggest()` and `review()`.

## Privacy

Wrap anything that must never be sent in `SeaproofMask`. It is still shown in the app, but
it is blacked out in screenshots:

```dart
SeaproofMask(child: Text(cardNumber))
```

Screenshots are uploaded straight to object storage with a short-lived signed URL. The API
key never goes to storage.

## Look

By default the floating button and the panel follow your app's `ThemeData`, so colours,
fonts and shapes match the rest of the app. To give Seaproof its own look, add a
`SeaproofTheme` to the theme. This also lets it follow light and dark mode:

```dart
ThemeData(
  extensions: const [
    SeaproofTheme(
      primaryColor: Color(0xFF6D28D9),      // floating button, selected type, send button
      surfaceColor: Colors.white,           // panel background
      borderRadius: 20,
      fontFamily: 'Inter',
      floatingButtonIcon: Icons.bug_report_outlined,
      floatingButtonSize: 52,
      panelStyle: SeaproofPanelStyle.card,  // or fullScreen, or auto (by width)
      annotationColor: Colors.amber,        // pen colour when marking up screenshots
    ),
  ],
)
```

You can also pass it directly with `SeaproofHost(theme: ...)`. Any field you set there takes
precedence over the one in `ThemeData`.

### Branding from the admin

A colour and logo set under **Branding** in the Seaproof admin reach the app without a release.
The colour is used only when neither `SeaproofTheme` sets a `primaryColor`, and then with black
or white text, whichever reads better. The logo appears at the top of the panel. Turn both off
with `SeaproofConfig(useProjectBranding: false)`.

### Feedback button placement

In **Project Settings → Feedback button**, choose the built-in button's position, text and
orientation. The SDK applies settings on startup. With the default settings, the icon button
can still be dragged.

When **Avoid covering other controls** is on, pass a `ValueListenable<List<Rect>>` as
`SeaproofHost.launcherObstructions`. Publish the bounds of the controls in the host's
coordinate space whenever they appear, move or disappear. The launcher returns to its
preferred position as soon as the space is free.

## Language

The SDK's texts are built in for English and Swedish and follow the app's locale. You can
set a language with `SeaproofConfig(locale: ...)`, or pass a `SeaproofStrings` of your own
to `SeaproofHost(strings: ...)`.

## Development

```sh
cd sdks/flutter
flutter pub get
flutter analyze
flutter test
```

`example/` contains a small shop app. Run it with
`flutter run --dart-define=SEAPROOF_KEY=sp_... --dart-define=SEAPROOF_ENDPOINT=http://localhost:5080`.

## When something fails

Failed calls throw `SeaproofException` with `code`, `statusCode`, `message` and `helpUrl`, and
its `toString()` ends with `How to fix: <link>`. All codes:
[error reference](https://seaproof.io/docs/errors.md).

## Using a coding agent

Agents find the docs at https://seaproof.io/llms.txt. Claude Code users can install the
Seaproof plugin, which adds an `add-seaproof` skill and the MCP server. See
[AI agents](https://seaproof.io/docs/ai-agents.md).
