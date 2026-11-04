import { browserContext, mergeContext } from "./context";
import { Diagnostics, installCapture } from "./diagnostics";
import { describeError, SeaproofError } from "./errors";
import { defaultStorage, ReporterIdentity } from "./reporter";
import type {
  AssistSettings,
  AttachmentInput,
  ConversationMessage,
  EnvironmentMode,
  FeedbackInput,
  OwnFeedback,
  OwnFeedbackDetail,
  PublicIdea,
  Reporter,
  ReviewResult,
  SeaproofBranding,
  SeaproofOptions,
  SeaproofProject,
  SubmittedFeedback,
  Suggestion,
} from "./types";

const DEFAULT_ENDPOINT = "https://api.seaproof.io";
const MAX_CRASH_REPORTS = 3;

interface UploadInstruction {
  attachmentId: string;
  method: string;
  url: string;
  headers: Record<string, string>;
}

interface SubmitResponse {
  id: string;
  number: number;
  uploads: UploadInstruction[];
}

export interface SeaproofClient {
  /**
   * Sends feedback. Attachments go straight to storage with presigned URLs; the call resolves
   * when the feedback and all its files are stored.
   */
  submit(feedback: FeedbackInput, options?: { automatic?: boolean }): Promise<SubmittedFeedback>;
  /** Fetches the project and environment of the key. Called by `start()`. */
  whoAmI(): Promise<SeaproofProject>;
  /** Fetches the environment in the background. Failures leave the client in production mode. */
  start(): Promise<void>;
  /** The mode of the key's environment, once known: `test` or `production`. */
  readonly environment: EnvironmentMode | undefined;
  /** The team's name for the key's environment, such as `UAT`, once known. */
  readonly environmentName: string | undefined;
  /** Tester or production, with `auto` resolved. */
  readonly isTesterMode: boolean;
  /** The project's colour and logo from the admin, once known; undefined with `branding: false`. */
  readonly branding: SeaproofBranding | undefined;
  /**
   * Sets the signed-in user, or null on sign-out. Used for submissions without their own
   * reporter, and, with a `userHash`, to share conversations and votes across devices.
   */
  identify(reporter: Reporter | null): void;
  /** The project's logo, or undefined when it has none. */
  logo(): Promise<Blob | undefined>;
  /** Recent console output, requests and errors. */
  readonly diagnostics: Diagnostics;
  /** Adds a line to the diagnostics. */
  log(message: string): void;
  /** Called when the environment becomes known. Returns an unsubscribe function. */
  subscribe(listener: () => void): () => void;
  /** Feedback sent from this browser, with the team's replies counted. */
  myFeedback(): Promise<OwnFeedback[]>;
  /** One of them with the conversation. Marks its replies as read. */
  myFeedbackItem(id: string): Promise<OwnFeedbackDetail>;
  /** Answers the team on one of this browser's items. */
  sendMessage(feedbackId: string, body: string): Promise<ConversationMessage>;
  /**
   * Adds files to one of this browser's items after it was sent, such as a marked-up screenshot
   * or a recording made later in the conversation. Resolves when they are stored.
   */
  addAttachments(feedbackId: string, attachments: AttachmentInput[]): Promise<void>;
  /** The ideas the team published, most votes first. */
  ideas(): Promise<PublicIdea[]>;
  vote(ideaId: string): Promise<void>;
  unvote(ideaId: string): Promise<void>;
  /** A reply arrived that the user has not opened. */
  hasUnreadReply(item: OwnFeedback): boolean;
  /** What Seaproof Assist offers in this project. Everything off when it cannot be fetched. */
  assistSettings(): Promise<AssistSettings>;
  /** Known problems and public ideas like a draft, best first. Empty for short drafts. */
  suggest(text: string, type?: FeedbackInput["type"]): Promise<Suggestion[]>;
  /**
   * Asks what a draft is missing. Never throws: on any failure there are simply no questions.
   * Pass the same `conversationId` (from {@link newConversationId}) for every call about one
   * draft, so they count as one Assist conversation against the plan's monthly quota.
   */
  review(type: NonNullable<FeedbackInput["type"]>, description: string, conversationId?: string): Promise<ReviewResult>;
  /** Stops capturing and restores console, fetch and XMLHttpRequest. */
  dispose(): void;
}

/** A new id for one draft's Assist conversation (a random UUID). */
export function newConversationId(): string {
  if (typeof crypto.randomUUID === "function") return crypto.randomUUID();
  // randomUUID needs a secure context; getRandomValues does not.
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6]! & 0x0f) | 0x40;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function createSeaproof(options: SeaproofOptions): SeaproofClient {
  if (!options.apiKey?.startsWith("sp_")) {
    throw new Error("Seaproof: apiKey must be a project API key starting with sp_.");
  }

  const endpoint = (options.endpoint ?? DEFAULT_ENDPOINT).replace(/\/+$/, "");
  // Bound before capture wraps window.fetch, so the SDK's own calls are never recorded.
  const doFetch = options.fetch ?? globalThis.fetch.bind(globalThis);
  const diagnostics = new Diagnostics();
  const listeners = new Set<() => void>();
  const reportedCrashes = new Set<string>();
  const identity = new ReporterIdentity(options.storage ?? defaultStorage());
  let environment: EnvironmentMode | undefined;
  let environmentName: string | undefined;
  let branding: SeaproofBranding | undefined;
  let reporter: Reporter | undefined = options.reporter;

  /** The verified user's headers; an id without a hash proves nothing, so it is not sent. */
  const userHeaders = (user: Reporter | undefined): Record<string, string> =>
    user?.externalId && user.userHash
      ? { "X-Seaproof-User": encodeURIComponent(user.externalId), "X-Seaproof-User-Hash": user.userHash }
      : {};

  async function api(path: string, body?: unknown, method = "POST", user = reporter): Promise<Response> {
    const response = await doFetch(`${endpoint}${path}`, {
      method,
      headers: {
        "Content-Type": "application/json",
        "X-Seaproof-Key": options.apiKey,
        "X-Seaproof-Reporter": identity.key,
        ...userHeaders(user),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!response.ok) {
      throw await SeaproofError.fromResponse(response);
    }
    return response;
  }

  /** Puts each file at its presigned URL, then tells the API it is there. Matched by position, as the API returns them in order. */
  async function upload(feedbackId: string, uploads: UploadInstruction[], attachments: AttachmentInput[]): Promise<void> {
    await Promise.all(
      uploads.map(async (instruction, index) => {
        const file = attachments[index]!.file;
        const put = await doFetch(instruction.url, { method: instruction.method, headers: instruction.headers, body: file });
        if (!put.ok) {
          throw new SeaproofError(put.status, "storage.upload_failed", `Uploading attachment ${index + 1} failed.`);
        }
        await api(`/api/v1/sdk/feedback/${feedbackId}/attachments/${instruction.attachmentId}/uploaded`);
      }),
    );
  }

  const isTesterMode = () =>
    options.mode === "tester" || ((options.mode ?? "auto") === "auto" && environment === "test");

  const client: SeaproofClient = {
    get environment() {
      return environment;
    },
    get environmentName() {
      return environmentName;
    },
    get isTesterMode() {
      return isTesterMode();
    },
    get branding() {
      return branding;
    },
    identify(next) {
      reporter = next ?? undefined;
    },
    diagnostics,

    async whoAmI() {
      return (await (await api("/api/v1/sdk/whoami", undefined, "GET")).json()) as SeaproofProject;
    },

    async start() {
      try {
        const project = await client.whoAmI();
        environment = modeOf(project);
        environmentName = project.environmentName;
        if (options.branding !== false) branding = project.branding;
        listeners.forEach((l) => l());
      } catch (error) {
        console.warn(`Seaproof: could not fetch the project for the API key. ${describeError(error)}`);
      }
    },

    async logo() {
      if (!branding?.logo) return undefined;
      // The version in the URL lets the browser cache it until the admin changes it.
      return (await api(`/api/v1/sdk/branding/logo?v=${encodeURIComponent(branding.logo)}`, undefined, "GET")).blob();
    },

    log(message) {
      diagnostics.add("log", message);
    },

    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },

    async submit(feedback, { automatic = false } = {}) {
      const attachments = [...(feedback.attachments ?? [])];
      if ((options.includeDiagnostics ?? isTesterMode()) || automatic) {
        if (!diagnostics.isEmpty) attachments.push({ kind: "log", file: diagnostics.toNdjson(), fileName: "diagnostics.ndjson" });
      }
      const context = mergeContext(
        browserContext(),
        options.appVersion ? { appVersion: options.appVersion } : undefined,
        options.commit ? { commit: options.commit } : undefined,
        options.context?.(),
        feedback.context,
        automatic ? { custom: { "seaproof.source": "crash" } } : undefined,
      );

      const sender = feedback.reporter ?? reporter;
      const response = await api(
        "/api/v1/sdk/feedback",
        {
          type: feedback.type,
          title: feedback.title,
          description: feedback.description,
          severity: feedback.severity,
          linkedTo: feedback.linkedTo,
          reporter: withoutHash(sender),
          context,
          attachments: attachments.map(describeAttachment),
        },
        "POST",
        sender,
      );
      const submitted = (await response.json()) as SubmitResponse;

      await upload(submitted.id, submitted.uploads, attachments);
      return { id: submitted.id, number: submitted.number };
    },

    async myFeedback() {
      return (await (await api("/api/v1/sdk/me/feedback", undefined, "GET")).json()) as OwnFeedback[];
    },

    async myFeedbackItem(id) {
      const detail = (await (await api(`/api/v1/sdk/me/feedback/${encodeURIComponent(id)}`, undefined, "GET")).json()) as OwnFeedbackDetail;
      const lastReply = detail.messages.filter((m) => m.from === "team").at(-1);
      if (lastReply) identity.markSeen({ id, lastReplyAt: lastReply.createdAt });
      return detail;
    },

    async sendMessage(feedbackId, body) {
      return (await (await api(`/api/v1/sdk/me/feedback/${encodeURIComponent(feedbackId)}/messages`, { body })).json()) as ConversationMessage;
    },

    async addAttachments(feedbackId, files) {
      const response = await api(`/api/v1/sdk/me/feedback/${encodeURIComponent(feedbackId)}/attachments`, {
        attachments: files.map(describeAttachment),
      });
      const { uploads } = (await response.json()) as { uploads: UploadInstruction[] };
      await upload(feedbackId, uploads, files);
    },

    async ideas() {
      return (await (await api("/api/v1/sdk/ideas", undefined, "GET")).json()) as PublicIdea[];
    },

    async vote(ideaId) {
      await api(`/api/v1/sdk/ideas/${encodeURIComponent(ideaId)}/vote`, undefined, "PUT");
    },

    async unvote(ideaId) {
      await api(`/api/v1/sdk/ideas/${encodeURIComponent(ideaId)}/vote`, undefined, "DELETE");
    },

    hasUnreadReply(item) {
      return identity.isUnread(item);
    },

    async assistSettings() {
      try {
        return (await (await api("/api/v1/sdk/assist", undefined, "GET")).json()) as AssistSettings;
      } catch {
        return { suggestions: false, followUpQuestions: false };
      }
    },

    async suggest(text, type) {
      return (await (await api("/api/v1/sdk/assist/suggestions", { text, type })).json()) as Suggestion[];
    },

    async review(type, description, conversationId) {
      try {
        return (await (await api("/api/v1/sdk/assist/review", { type, description, conversationId })).json()) as ReviewResult;
      } catch {
        return { questions: [], limited: false };
      }
    },

    dispose() {
      uninstall();
      listeners.clear();
    },
  };

  function reportCrash(error: unknown, message: string) {
    if (!options.reportCrashes || reportedCrashes.size >= MAX_CRASH_REPORTS || reportedCrashes.has(message)) return;
    reportedCrashes.add(message);
    const firstLine = message.split("\n")[0]!;
    const stack = error instanceof Error && error.stack ? `\n\n${error.stack}` : "";
    client
      .submit(
        {
          type: "bug",
          title: `Crash: ${firstLine.length <= 180 ? firstLine : `${firstLine.slice(0, 177)}...`}`,
          description: `${message}${stack}`,
        },
        { automatic: true },
      )
      .catch((e: unknown) => console.warn(`Seaproof: could not report the crash. ${describeError(e)}`));
  }

  const uninstall =
    options.diagnostics === false
      ? () => {}
      : installCapture(diagnostics, {
          ...options.diagnostics,
          ignoreUrl: (url) => url.startsWith(endpoint),
          onError: reportCrash,
        });

  return client;
}

function describeAttachment(a: AttachmentInput) {
  return {
    kind: a.kind,
    fileName: a.fileName ?? (a.file instanceof File ? a.file.name : undefined),
    contentType: a.file.type,
    sizeBytes: a.file.size,
  };
}

/** The hash travels in a header only; it is not stored with the feedback. */
function withoutHash(reporter: Reporter | undefined): Omit<Reporter, "userHash"> | undefined {
  if (!reporter) return undefined;
  const { userHash: _, ...rest } = reporter;
  return rest;
}

/**
 * The mode from whoami: `mode` from current APIs, else `environment`, where APIs from before teams
 * named their environments also sent `staging` (a tester environment).
 */
export function modeOf(project: Pick<SeaproofProject, "environment" | "mode">): EnvironmentMode {
  const value: string = project.mode ?? project.environment;
  return value === "test" || value === "staging" ? "test" : "production";
}
