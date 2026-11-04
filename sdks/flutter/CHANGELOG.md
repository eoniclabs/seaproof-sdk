## 0.1.0

- First version: feedback panel with screenshot and annotation, shake and floating-button
  triggers, keyboard shortcut on desktop, tester and production modes, masking of sensitive
  widgets, identified or anonymous reporters, contact consent and theming
  through `SeaproofTheme`. Texts in English and Swedish.
- Diagnostics: `debugPrint`/`print`, HTTP calls through `SeaproofHttpClient` (query values
  redacted, no bodies or headers), uncaught errors and the device model are recorded and
  attached to reports. Optional automatic crash reports (`reportCrashes`).
- Replies and ideas: users read the team's replies under "Your feedback" and answer, and vote
  on published ideas under "Ideas". A random reporter key per installation, kept in shared
  preferences or your own `SeaproofStorage`. `Seaproof.unreadReplies` and
  `Seaproof.checkReplies()` for badges.
- Screen recording of the app (masked, as an animated PNG), for testers by default
  (`allowScreenRecording`, `maxRecordingDuration`).
- Branding from the admin: the project's colour (when the app's `SeaproofTheme` sets none) and
  logo in the panel. `SeaproofProject.branding`, `SeaproofController.logo`,
  `useProjectBranding`.
- Conversations and votes across devices for verified users: `SeaproofUser.userHash`.
- Seaproof Assist, when the team turns it on: known problems and public ideas like the draft
  while the user writes ("same problem" links the report, ideas can be voted for), and up to
  two follow-up questions before sending. `SeaproofClient.assistSettings`, `suggest`,
  `review` (with a `conversationId` per draft, from `newConversationId`, so one draft counts as
  one Assist conversation); `FeedbackDraft.linkedTo`.
