import type { FeedbackContext } from "./types";
import { SDK_VERSION } from "./version";

/** Context the browser can tell us without asking anyone. */
export function browserContext(): FeedbackContext {
  if (typeof window === "undefined") {
    return { platform: "web", sdkVersion: `react-${SDK_VERSION}` };
  }

  return {
    platform: "web",
    sdkVersion: `react-${SDK_VERSION}`,
    url: window.location.href,
    locale: navigator.language,
    device: navigator.userAgent,
    screen: `${window.innerWidth}x${window.innerHeight}@${window.devicePixelRatio}`,
  };
}

export function mergeContext(...parts: (FeedbackContext | undefined)[]): FeedbackContext {
  const merged: FeedbackContext = {};
  for (const part of parts) {
    if (!part) continue;
    for (const [key, value] of Object.entries(part)) {
      if (value === undefined) continue;
      if (key === "custom") {
        merged.custom = { ...merged.custom, ...(value as Record<string, string>) };
      } else {
        (merged as Record<string, unknown>)[key] = value;
      }
    }
  }
  return merged;
}
