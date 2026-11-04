# Seaproof SDKs

In-app bug reporting for testers and feedback, questions and product ideas from end users, for
Flutter and React/web apps. Reports arrive in the [Seaproof](https://seaproof.io) inbox with a
screenshot, the device and the app's recent logs, and can be forwarded to GitHub or Azure DevOps.

This repository holds the open-source parts of Seaproof (MIT): the SDKs, the Claude Code plugin
and an example app. The service itself runs at [seaproof.io](https://seaproof.io); the Free plan
needs no card.

| Package | Install | Docs |
| --- | --- | --- |
| Flutter (Android, iOS, macOS, Windows, Linux, web) | `flutter pub add seaproof` | [sdks/flutter](sdks/flutter/README.md) |
| React | `npm install @seaproof/react` | [sdks/react](sdks/react/README.md) |
| Any web app | `npm install @seaproof/core` | [sdks/react](sdks/react/README.md) |
| Claude Code plugin | `/plugin marketplace add eoniclabs/seaproof-sdk`, then `/plugin install seaproof@seaproof` | [integrations/claude-code](integrations/claude-code/README.md) |

## Let your coding agent set it up

Paste this into Claude Code, Codex, Cursor or Copilot in your app's repository:

```text
Add Seaproof to this app so testers can report bugs and users can send feedback.
Follow the instructions at https://seaproof.io/docs/start.md step by step.
```

The agent connects to the Seaproof MCP server, helps you sign up, creates the project and key,
adds the SDK and sends a test report with you. Docs for agents: https://seaproof.io/llms.txt

## Contributing

This repository is a mirror; changes are made in Seaproof's own repository and copied here on
each release. Issues and pull requests are welcome all the same: we bring accepted changes over
by hand.
