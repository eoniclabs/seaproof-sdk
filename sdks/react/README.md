# Seaproof for React and the web

Two packages:

- `@seaproof/react`: a feedback button and dialog for React apps.
- `@seaproof/core`: the client underneath, for any web app or framework.

## Install

```sh
npm install @seaproof/react     # React apps (includes @seaproof/core)
npm install @seaproof/core      # any other web app
```

Create a project and a **test** API key in the [Seaproof admin](https://app.seaproof.io) first,
and add where the app runs (such as `http://localhost:5173`) under **Allowed websites** on the
key so other sites cannot use it. Keep the key in `.env.local`, out of git:

```sh
VITE_SEAPROOF_KEY=sp_...
```

> **Beta.** While Seaproof is in beta, apps report to a test deployment rather than
> https://api.seaproof.io. Pass its address as `endpoint` (a prop on `SeaproofProvider`, an
> option to `createSeaproof`), for example `endpoint={import.meta.env.VITE_SEAPROOF_ENDPOINT}`.
> The admin's install steps and the MCP tool `get_sdk_setup` show the right address.

## React

```tsx
import { FeedbackWidget, SeaproofProvider } from "@seaproof/react";

<SeaproofProvider
  apiKey={import.meta.env.VITE_SEAPROOF_KEY}
  appVersion={import.meta.env.VITE_APP_VERSION}
  commit={import.meta.env.VITE_COMMIT_SHA} // optional: links reports to the build
>
  <App />
  <FeedbackWidget />
</SeaproofProvider>;
```

Start the app: with a test key, a **Feedback** button appears in the corner. Step-by-step
guides: [React](https://seaproof.io/docs/react.md), [Next.js](https://seaproof.io/docs/nextjs.md).
A runnable app is in [examples/react-vite](https://github.com/eoniclabs/seaproof-sdk/tree/main/examples/react-vite).

Open it from your own button with `useSeaproof().open()` and `<FeedbackWidget launcher={false} />`.

## Testers and end users

The SDK reads the API key's environment. You name your environments per project in the
Seaproof admin (Dev, QA, UAT, Prod...), and each is in test or production mode. With a key in
a test-mode environment, the floating **Feedback** button is shown and the diagnostics are
attached to reports. With a key in a production-mode environment, neither happens, and you open the widget from your own button with
`useSeaproof().open()`. You can override this with `mode: "tester" | "production"` and
`<FeedbackWidget launcher={true} />`.

### Feedback button placement

In **Project Settings → Feedback button**, choose the built-in button's position, text and
orientation. The SDK applies the settings on startup. An explicit `label` prop overrides the
project's text.

When **Avoid covering other controls** is on, mark the elements that the button should stay clear
of. It uses the preferred position whenever that spot is free.

```tsx
<aside data-seaproof-avoid>
  <HelpButton />
</aside>
```

## Diagnostics

The SDK keeps the last 500 entries in memory: `console` output, `fetch` and
`XMLHttpRequest` calls, and uncaught errors and unhandled promise rejections. Only the
method, the URL with query values replaced by `*`, the status and the duration are recorded
for each request; bodies and headers never are. The SDK's own calls are left out.
`client.log("...")` adds your own lines. Testers' reports include the entries as
`diagnostics.ndjson`, which the inbox shows as a timeline.

```ts
createSeaproof({
  apiKey,
  diagnostics: { console: true, network: true, errors: true }, // or false
  includeDiagnostics: true,                                    // send also in production
  reportCrashes: true,                                         // report uncaught errors on their own
});
```

## Styling

You restyle the widget with CSS variables. Set them on `:root` or on any ancestor of the
widget:

```css
:root {
  --seaproof-primary: #6d28d9;      /* launcher, send button */
  --seaproof-on-primary: #fff;
  --seaproof-surface: #fff;         /* panel background */
  --seaproof-surface-sunken: #edf2f5; /* tab track, conversation */
  --seaproof-text: #111;
  --seaproof-text-muted: #555;
  --seaproof-border: #d4d4d8;       /* dividers and cards */
  --seaproof-border-strong: #71717a; /* text fields; keep 3:1 against the surface */
  --seaproof-focus: #e8590c;        /* focus ring */
  --seaproof-radius: 16px;          /* the panel; fields and buttons scale with it */
  --seaproof-font: "Inter", sans-serif;
  --seaproof-z-index: 1000;
}
```

The widget is light by default. `<FeedbackWidget colorScheme="dark" />` uses Seaproof's dark
palette, and `"auto"` follows the visitor's system setting. Your variables win in every scheme.

A colour and logo set under **Branding** in the Seaproof admin are used without a release:
the colour fills in when you have not set `--seaproof-primary`, and the logo sits at the top of
the panel (`.seaproof-logo`). Turn both off with `branding: false` in the client options.

For anything else, you can target the stable classes `seaproof-launcher`, `seaproof-backdrop`,
`seaproof-panel`, `seaproof-type`, `seaproof-tabs`, `seaproof-footer`, `seaproof-primary` and
`seaproof-error`. The built-in
rules sit inside `:where()`, so any selector of yours wins without `!important`:

```css
.seaproof-launcher { left: 20px; right: auto; }
```

## Without React

```ts
import { captureScreenshot, createSeaproof } from "@seaproof/core";

const seaproof = createSeaproof({ apiKey: "sp_…" });
await seaproof.submit({
  type: "bug",
  description: "Checkout button does nothing",
  attachments: [{ kind: "screenshot", file: await captureScreenshot() }],
});
```

## Screen recording

Testers get **Record the screen** in the widget, in browsers that support screen sharing
(desktop Chrome, Edge, Firefox and Safari; not mobile browsers). The browser asks what to
share, the widget hides, and a bar with a timer and **Stop** appears. The video (WebM, or MP4
in Safari) is attached when they stop, after 60 seconds at most. Offer it to end users with
`<FeedbackWidget recording />`, or use `ScreenRecorder` from `@seaproof/core` directly.

A recording shows everything on the shared surface: `data-seaproof-mask` only applies to
screenshots.

## Replies and ideas

The widget gets two more tabs when they have content: **Your feedback**, where users read the
team's replies to what they sent from this browser and answer, and **Ideas**, where they vote
on ideas the team published. Pick the views with `<FeedbackWidget views={["send"]} />`.

No account is needed: the SDK creates a random reporter key per browser in `localStorage`
(pass `storage` to `createSeaproof` to use something else). Without React, the same calls are
on the client: `myFeedback()`, `myFeedbackItem(id)`, `sendMessage(id, body)`, `ideas()`,
`vote(id)`, `unvote(id)` and `hasUnreadReply(item)`.

To show a signed-in user their conversations on every device, turn on **Identity
verification** under API keys in the admin, sign the user's id on your backend
(`HMAC-SHA256(secret, userId)` as hex, never in the browser) and pass it along:

```tsx
<FeedbackWidget reporter={{ externalId: user.id, name: user.name, userHash: user.seaproofHash }} />
// or, without the widget: client.identify({ externalId: user.id, userHash: user.seaproofHash });
```

## Seaproof Assist

The widget is a short conversation. The first message saves the report, so nothing is lost if
the user stops there; everything after it (more text, a marked-up screenshot, a recording) is
added to the same report. Without Assist, or when the plan's quota is used up, the widget asks
with fixed lines instead.

When the team turns Assist on in the admin, the widget helps while the user writes. Nothing
changes in your code.

- **Suggestions:** known problems and public ideas that look like the draft appear under the
  text. "Same for me" sends the report linked to the known one, and ideas can be voted for
  there. Only the title and summary the team made public are ever shown.
- **Follow-up questions:** after the report is saved, an AI model asks what it is missing, one
  question at a time and at most five. The answers are added to the report. A slow or failing
  model never stops a report.

Without React: `assistSettings()`, `suggest(text, type)`, `review(type, description, conversationId)`
(one id per draft from `newConversationId()`, so one draft counts as one Assist conversation), and
`linkedTo` on `submit()`. `addAttachments(id, files)` adds files to a report already sent.
## When something fails

The SDK logs a console warning with what went wrong, the error code and a link to the fix, for
example `Seaproof: could not fetch the project for the API key. This API key is unknown or
revoked. … (sdk.key_invalid). How to fix: https://seaproof.io/docs/errors#sdk.key_invalid`. `SeaproofError` carries `code`, `status` and
`helpUrl`, and `describeError(error)` gives the same text. All codes:
[error reference](https://seaproof.io/docs/errors.md).

## Using a coding agent

Agents find the docs at https://seaproof.io/llms.txt. Claude Code users can install the
Seaproof plugin, which adds an `add-seaproof` skill and the MCP server; there are rules for
Cursor and Copilot too. See [AI agents](https://seaproof.io/docs/ai-agents.md).

## Privacy

Screenshots are taken in the browser. Elements with `data-seaproof-mask` and all password fields
are left out, so their content never leaves the device. Mark anything personal.

## How a submission travels

1. `POST /api/v1/sdk/feedback` with the text, context and a list of files (type and size only).
2. The API answers with one presigned upload URL per file.
3. The SDK `PUT`s each file straight to object storage, then reports it with
   `POST /api/v1/sdk/feedback/{id}/attachments/{attachmentId}/uploaded`.

The object-storage bucket needs a CORS rule that allows `PUT` from any origin with a
`Content-Type` header.
