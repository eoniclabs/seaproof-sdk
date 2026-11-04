export type DiagnosticKind = "log" | "console" | "network" | "error";

/** One line of the diagnostics attached to a report, serialized as NDJSON. */
export interface DiagnosticEntry {
  /** ISO time in UTC. */
  t: string;
  kind: DiagnosticKind;
  message: string;
  [detail: string]: unknown;
}

export interface CaptureOptions {
  /** console.log/info/warn/error/debug. Default true. */
  console?: boolean;
  /** fetch and XMLHttpRequest: method, URL with query values redacted, status, duration. Default true. */
  network?: boolean;
  /** Uncaught errors and unhandled promise rejections. Default true. */
  errors?: boolean;
}

const MAX_MESSAGE = 2000;

/**
 * The most recent diagnostics. Nothing leaves the browser on its own: entries are only sent
 * inside a report.
 */
export class Diagnostics {
  private readonly entries: DiagnosticEntry[] = [];

  constructor(
    readonly capacity = 500,
    private readonly now: () => Date = () => new Date(),
  ) {}

  get isEmpty(): boolean {
    return this.entries.length === 0;
  }

  add(kind: DiagnosticKind, message: string, details: Record<string, unknown> = {}): void {
    const text = message.length <= MAX_MESSAGE ? message : `${message.slice(0, MAX_MESSAGE)}…`;
    this.entries.push({ ...details, t: this.now().toISOString(), kind, message: text });
    if (this.entries.length > this.capacity) this.entries.splice(0, this.entries.length - this.capacity);
  }

  list(): readonly DiagnosticEntry[] {
    return this.entries;
  }

  toNdjson(): Blob {
    return new Blob([this.entries.map((e) => JSON.stringify(e)).join("\n")], { type: "application/x-ndjson" });
  }

  clear(): void {
    this.entries.length = 0;
  }
}

/** The URL with query values replaced by `*`, so tokens and personal data are not recorded. */
export function redactUrl(raw: string, base = typeof location === "undefined" ? "http://localhost" : location.href): string {
  try {
    const url = new URL(raw, base);
    if (!url.search) return url.toString();
    const keys = [...new Set(url.searchParams.keys())];
    url.search = keys.map((k) => `${encodeURIComponent(k)}=*`).join("&");
    return url.toString().replace(/=%2A/g, "=*");
  } catch {
    return raw.split("?")[0] ?? raw;
  }
}

function describe(value: unknown): string {
  if (typeof value === "string") return value;
  if (value instanceof Error) return `${value.name}: ${value.message}`;
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

const consoleMethods = ["log", "info", "warn", "error", "debug"] as const;

/**
 * Starts recording into `diagnostics`. Returns a function that restores everything it
 * replaced. Calls to `ignoreUrl` (the Seaproof API itself) are not recorded.
 */
export function installCapture(
  diagnostics: Diagnostics,
  options: CaptureOptions & { ignoreUrl?: (url: string) => boolean; onError?: (error: unknown, message: string) => void } = {},
): () => void {
  if (typeof window === "undefined") return () => {};
  const restore: (() => void)[] = [];
  const ignore = options.ignoreUrl ?? (() => false);

  if (options.console !== false) {
    for (const level of consoleMethods) {
      const original = console[level];
      console[level] = (...args: unknown[]) => {
        const message = args.map(describe).join(" ");
        if (!message.startsWith("Seaproof:")) diagnostics.add("console", message, { level });
        original.apply(console, args);
      };
      restore.push(() => (console[level] = original));
    }
  }

  if (options.errors !== false) {
    const onError = (event: ErrorEvent) => {
      const message = event.message || describe(event.error);
      diagnostics.add("error", message, { stack: event.error instanceof Error ? event.error.stack : undefined, source: event.filename });
      options.onError?.(event.error ?? message, message);
    };
    const onRejection = (event: PromiseRejectionEvent) => {
      const message = `Unhandled rejection: ${describe(event.reason)}`;
      diagnostics.add("error", message, { stack: event.reason instanceof Error ? event.reason.stack : undefined });
      options.onError?.(event.reason, message);
    };
    window.addEventListener("error", onError);
    window.addEventListener("unhandledrejection", onRejection);
    restore.push(() => {
      window.removeEventListener("error", onError);
      window.removeEventListener("unhandledrejection", onRejection);
    });
  }

  if (options.network !== false) {
    const record = (method: string, url: string, status: number | undefined, started: number, error?: string) => {
      if (ignore(url)) return;
      const redacted = redactUrl(url);
      const durationMs = Math.round(performance.now() - started);
      diagnostics.add("network", `${method} ${redacted} → ${status ?? error ?? "?"} (${durationMs} ms)`, {
        method,
        url: redacted,
        status,
        durationMs,
        error,
      });
    };

    if (typeof window.fetch === "function") {
      const originalFetch = window.fetch;
      window.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
        const url = input instanceof Request ? input.url : String(input);
        const method = (init?.method ?? (input instanceof Request ? input.method : "GET")).toUpperCase();
        const started = performance.now();
        try {
          const response = await originalFetch(input, init);
          record(method, url, response.status, started);
          return response;
        } catch (error) {
          record(method, url, undefined, started, describe(error));
          throw error;
        }
      };
      restore.push(() => (window.fetch = originalFetch));
    }

    if (typeof XMLHttpRequest !== "undefined") {
      const proto = XMLHttpRequest.prototype;
      const originalOpen = proto.open;
      const originalSend = proto.send;
      const meta = new WeakMap<XMLHttpRequest, { method: string; url: string }>();
      proto.open = function (this: XMLHttpRequest, method: string, url: string | URL, ...rest: unknown[]) {
        meta.set(this, { method: method.toUpperCase(), url: String(url) });
        return (originalOpen as (...a: unknown[]) => void).call(this, method, url, ...rest);
      } as typeof proto.open;
      proto.send = function (this: XMLHttpRequest, body?: Document | XMLHttpRequestBodyInit | null) {
        const info = meta.get(this);
        if (info) {
          const started = performance.now();
          this.addEventListener("loadend", () => record(info.method, info.url, this.status || undefined, started, this.status ? undefined : "network error"));
        }
        return originalSend.call(this, body);
      };
      restore.push(() => {
        proto.open = originalOpen;
        proto.send = originalSend;
      });
    }
  }

  return () => restore.reverse().forEach((r) => r());
}
