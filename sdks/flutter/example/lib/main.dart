import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:seaproof/seaproof.dart';

// Run with: flutter run --dart-define=SEAPROOF_KEY=sp_... [--dart-define=SEAPROOF_ENDPOINT=http://localhost:5080]
const _key = String.fromEnvironment('SEAPROOF_KEY');
const _endpoint = String.fromEnvironment('SEAPROOF_ENDPOINT');

final _http = SeaproofHttpClient(http.Client());

void main() => Seaproof.runZoned(() {
  // A test or staging key gives testers shake (mobile) or a floating button and Ctrl/Cmd+Alt+F
  // (desktop). A production key shows nothing until the app opens the panel itself.
  Seaproof.init(
    SeaproofConfig(
      apiKey: _key,
      endpoint: _endpoint.isEmpty ? null : Uri.parse(_endpoint),
      custom: const {'flavour': 'example'},
    ),
  );
  runApp(const ExampleApp());
});

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Seaproof example',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF0B6E99)),
    navigatorObservers: [SeaproofNavigatorObserver()],
    builder: (context, child) => SeaproofHost(child: child!),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    Seaproof.checkReplies();
  }

  void _toggleSignIn() {
    setState(() => _signedIn = !_signedIn);
    // Identified users are shown by name in the inbox; anonymous users may leave an e-mail.
    Seaproof.identify(
      _signedIn ? const SeaproofUser(id: 'user-42', name: 'Kim Andersson', email: 'kim@example.com') : null,
    );
    Seaproof.log(_signedIn ? 'signed in' : 'signed out');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Shop'),
      actions: [
        // A dot when the team has replied to something this user sent.
        ValueListenableBuilder(
          valueListenable: Seaproof.unreadReplies,
          builder: (context, unread, _) => IconButton(
            tooltip: 'Feedback',
            onPressed: Seaproof.show,
            icon: Badge(isLabelVisible: unread > 0, child: const Icon(Icons.forum_outlined)),
          ),
        ),
        PopupMenuButton<void>(
          itemBuilder: (_) => [
            // The discreet entry point for end users in production.
            const PopupMenuItem(child: SeaproofFeedbackButton.listTile()),
            const PopupMenuItem(
              child: SeaproofFeedbackButton.listTile(type: FeedbackType.idea, label: 'Suggest a feature'),
            ),
          ],
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton(onPressed: _toggleSignIn, child: Text(_signedIn ? 'Sign out' : 'Sign in')),
        const SizedBox(height: 24),
        const Text('Card number'),
        // Hidden in screenshots.
        const SeaproofMask(child: Text('4111 1111 1111 1111', style: TextStyle(fontSize: 20))),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Seaproof.show(type: FeedbackType.bug),
          child: const Text('Report a problem'),
        ),
        const SizedBox(height: 12),
        // Recorded in the diagnostics: method, URL with query values redacted, status, duration.
        OutlinedButton(
          onPressed: () async {
            final response = await _http.get(Uri.base.resolve('products.json?session=abc123'));
            debugPrint('Loaded products: ${response.statusCode}');
          },
          child: const Text('Load products'),
        ),
      ],
    ),
  );
}
