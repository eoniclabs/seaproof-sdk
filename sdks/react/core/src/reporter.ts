import type { KeyValueStorage, OwnFeedback } from "./types";

const KEY = "seaproof.reporter-key";
const SEEN = "seaproof.seen-replies";

/**
 * Identifies this browser to Seaproof, so the user can read replies to their own feedback and
 * vote, without an account. The project key ships in the page and cannot do that; this random
 * secret never leaves the browser except to the Seaproof API.
 */
export class ReporterIdentity {
  private cachedKey: string | undefined;

  constructor(private readonly storage: KeyValueStorage) {}

  get key(): string {
    this.cachedKey ??= this.storage.getItem(KEY) ?? this.create();
    return this.cachedKey;
  }

  /** The item has a reply the user has not opened yet. */
  isUnread(item: Pick<OwnFeedback, "id" | "lastReplyAt">): boolean {
    if (!item.lastReplyAt) return false;
    const seen = this.seen()[item.id];
    return !seen || seen < item.lastReplyAt;
  }

  markSeen(item: Pick<OwnFeedback, "id" | "lastReplyAt">): void {
    if (!item.lastReplyAt) return;
    this.storage.setItem(SEEN, JSON.stringify({ ...this.seen(), [item.id]: item.lastReplyAt }));
  }

  private seen(): Record<string, string> {
    try {
      return JSON.parse(this.storage.getItem(SEEN) ?? "{}") as Record<string, string>;
    } catch {
      return {};
    }
  }

  private create(): string {
    const bytes = crypto.getRandomValues(new Uint8Array(32));
    const key = btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    this.storage.setItem(KEY, key);
    return key;
  }
}

/** `localStorage` when the page may use it (not in some private modes or sandboxed frames), otherwise memory. */
export function defaultStorage(): KeyValueStorage {
  try {
    const probe = "seaproof.probe";
    localStorage.setItem(probe, "1");
    localStorage.removeItem(probe);
    return localStorage;
  } catch {
    const memory = new Map<string, string>();
    return { getItem: (k) => memory.get(k) ?? null, setItem: (k, v) => void memory.set(k, v) };
  }
}
