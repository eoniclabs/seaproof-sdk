---
name: add-seaproof
description: Add Seaproof in-app bug reporting and user feedback to this app (React, Vite, Next.js or Flutter). Use when the user wants testers to report bugs with screenshots, a shake-to-report or feedback button, a way for users to send feedback or product ideas, or asks to set up Seaproof.
---

# Add Seaproof to this app

Seaproof lets testers report bugs (shake, floating button or Ctrl/Cmd+Alt+F, with a screenshot
and the app's logs) and lets end users send feedback and ideas. Follow these steps in order and
tell the user what you did at the end.

## 1. Find the stack

- `pubspec.yaml` with a Flutter dependency → **Flutter**. Guide: https://seaproof.io/docs/flutter.md
- `package.json` with `next` → **Next.js**. Guide: https://seaproof.io/docs/nextjs.md
- `package.json` with `react` (Vite, CRA and similar) → **React**. Guide: https://seaproof.io/docs/react.md
- Another web framework → `@seaproof/core` directly. Reference: https://seaproof.io/docs/react-sdk.md

If the repository holds several apps, ask which one, unless the user already said.

## 2. Get a project and an API key

Use the Seaproof MCP tools (the server is part of this plugin). If they are not connected, ask
the user to run `/mcp`, choose **seaproof → Authenticate**, sign in and tick **Set up projects**.
Someone without an account creates one on the same page (Google, GitHub, Microsoft or email;
free, no card).

1. `list_projects`. If a project for this app exists, use it; do not create a duplicate.
2. Otherwise `create_project` with the app's name.
3. `create_api_key` with `environment: "test"` for development. For a web app, pass
   `allowedOrigins` with the dev server origin (such as `http://localhost:5173` or
   `http://localhost:3000`) and any staging origin the user names.

If the tools say the connection lacks the setup permission, ask the user to create the project
and a test key in https://app.seaproof.io and paste the key, or to reconnect with **Set up projects**.

## 3. Store the key outside source control

- Vite/React: `VITE_SEAPROOF_KEY` in `.env.local`
- Next.js: `NEXT_PUBLIC_SEAPROOF_KEY` in `.env.local`
- Flutter: `--dart-define=SEAPROOF_KEY=...`; add it to the run configuration or a
  `--dart-define-from-file` JSON file that is git-ignored

Check that the file is git-ignored before you write the key. Never put the key in code,
commits or the README. Add the variable name, without the value, to `.env.example` if the
project has one.

## 4. Install and wire in the SDK

Call `get_sdk_setup` with the stack (`react`, `nextjs`, `flutter` or `web`) and follow its answer
exactly: the install command, the code for each file, the environment variables and how to run
it. It is written for the Seaproof the tools are connected to, so it includes the `endpoint` when
that is not the SDK's default (such as a staging server). If the tool is missing, follow the
guide for the stack instead:

- React: `npm install @seaproof/react` (or the project's package manager), then wrap the app in
  `SeaproofProvider` with `apiKey`, `appVersion` and `commit`, and render `<FeedbackWidget />`.
- Next.js: the same in a `"use client"` component used in `app/layout.tsx`.
- Flutter: `flutter pub add seaproof`, `Seaproof.init(SeaproofConfig(apiKey: String.fromEnvironment('SEAPROOF_KEY')))`
  in `main`, `SeaproofHost` in `MaterialApp.builder`, `SeaproofNavigatorObserver` in `navigatorObservers`.

Pass the build's git commit (`VITE_COMMIT_SHA`, `NEXT_PUBLIC_COMMIT_SHA`, or
`--dart-define=SEAPROOF_COMMIT`) so reports point at the code. If the project has CI, add the
variable to the build step.

## 5. Mark personal data

Look for screens with personal or payment data. Add `data-seaproof-mask` (web) or wrap in
`SeaproofMask` (Flutter) so they stay out of screenshots. Password fields are masked anyway.

## 6. Tell agents how it works

Add the section from https://seaproof.io/docs/agents-md.md to `AGENTS.md` or `CLAUDE.md`
(create `AGENTS.md` if neither exists), with the project's variable names.

## 7. Offer forwarding (optional)

Ask whether triaged bugs should go to the repository's tracker. If yes, and the setup tools are
connected: `list_tracker_connections`; if no account fits, `connect_tracker` and give the user the
link, then wait until they say they are done. Pick the target that matches this repository's
`git remote` (GitHub `owner/name`, or the Azure DevOps organization and project) with
`list_tracker_options`, then `create_integration` and `test_integration`. Never ask for an access
token; if signing in is not set up, point the user to **Integrations** in Seaproof.

## 8. Offer a triage job (optional)

If the member wants new reports triaged on a schedule, offer a GitHub Actions (or other CI) job:
`create_service_agent` with only the permissions the job needs, store the key with
`gh secret set SEAPROOF_AGENT_KEY`, and use the returned configuration in the workflow. Never write
the key into a file in the repository or repeat it in chat.

## 9. Check

Build or type-check the app. Then tell the user how to see it work: start the app with the
test key, press **Feedback** (web) or shake the device (Flutter), send a report and watch it
arrive in the Seaproof inbox. For production, they create a production key and add their own
"Send feedback" button (`useSeaproof().open()` or `SeaproofFeedbackButton`). If a request
fails, the console shows an error code with a link to https://seaproof.io/docs/errors.
