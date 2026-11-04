# Seaproof in a React + Vite app

A minimal app with the Seaproof feedback widget: the provider and widget in
[`src/main.tsx`](src/main.tsx), a "Send feedback" button and a masked element in
[`src/App.tsx`](src/App.tsx). The step-by-step guide is [docs/guides/react.md](../../docs/guides/react.md).

## Run it

1. Create a project and a **test** API key in [Seaproof](https://app.seaproof.io), and add
   `http://localhost:5174` under **Allowed websites** on the key.
2. `cp .env.example .env.local` and set `VITE_SEAPROOF_KEY`.
3. From the repository root: `npm install`, then `npm run dev -w @seaproof/example-react-vite`.

Open http://localhost:5174, press **Feedback** and send a report. If nothing arrives, the
browser console shows an error code and a link to the fix.

## Use it as a template

Outside this repository, copy the folder and change the `@seaproof/react` dependency to the
published version. Everything else is plain Vite.
