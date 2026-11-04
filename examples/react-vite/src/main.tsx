import { FeedbackWidget, SeaproofProvider } from "@seaproof/react";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";

// The whole Seaproof setup: a provider with the key and build details, and the widget.
// With a test or staging key, a Feedback button appears in the corner (and Ctrl/Cmd+Alt+F
// opens it). With a production key, open it from your own button; see App.tsx.
createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <SeaproofProvider
      apiKey={import.meta.env.VITE_SEAPROOF_KEY}
      appVersion={import.meta.env.VITE_APP_VERSION}
      commit={import.meta.env.VITE_COMMIT_SHA}
    >
      <App />
      <FeedbackWidget />
    </SeaproofProvider>
  </StrictMode>,
);
