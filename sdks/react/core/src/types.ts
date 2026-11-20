import type { CaptureOptions } from "./diagnostics";

export type FeedbackType = "bug" | "feedback" | "idea" | "question";
/**
 * How the SDK behaves for the API key's environment. Teams name their own environments per
 * project (Dev, QA, UAT...); each is in test mode (testers) or production mode (end users).
 */
export type EnvironmentMode = "test" | "production";

/** @deprecated Environments are named per project now; this is their {@link EnvironmentMode}. */
export type Environment = EnvironmentMode;
export type FeedbackSeverity = "low" | "medium" | "high" | "critical";
export type AttachmentKind = "screenshot" | "recording" | "log" | "file";

/** Who sent the feedback, as your app knows them. Testers and end users do not need a Seaproof account. */
export interface Reporter {
  externalId?: string;
  name?: string;
  email?: string;
  /** The user agreed to be contacted about this feedback. */
  mayContact?: boolean;
  /**
   * Proof from your backend that `externalId` is this user: `HMAC-SHA256(secret, externalId)`
   * as hex, with the identity verification secret from the Seaproof admin. With it, the user's
   * conversations and votes follow them to every device. Never compute it in the browser,
   * where the secret would leak.
   */
  userHash?: string;
}

/** Where the feedback was sent from. Filled in automatically in the browser; anything you pass wins. */
export interface FeedbackContext {
  platform?: string;
  appVersion?: string;
  osVersion?: string;
  device?: string;
  locale?: string;
  url?: string;
  screen?: string;
  sdkVersion?: string;
  /** The commit the app was built from, such as a short git hash. */
  commit?: string;
  /** Free-form metadata, for example a build number or feature flags. Strings only. */
  custom?: Record<string, string>;
}

export interface AttachmentInput {
  kind: AttachmentKind;
  file: Blob;
  fileName?: string;
}

export interface FeedbackInput {
  description: string;
  type?: FeedbackType;
  title?: string;
  severity?: FeedbackSeverity;
  reporter?: Reporter;
  context?: FeedbackContext;
  attachments?: AttachmentInput[];
  /** The known problem or public idea this is about, from `suggest()`: the team sees the link. */
  linkedTo?: string;
}

export interface SubmittedFeedback {
  id: string;
  number: number;
}

/** Tester: diagnostics attached and the launcher shown. Production: neither, unless you opt in. */
export type SeaproofMode = "auto" | "tester" | "production";

export interface SeaproofProject {
  projectId: string;
  projectName: string;
  /** The environment's mode. Same as `mode`; older APIs send only this one. */
  environment: EnvironmentMode;
  /** The environment's mode: `test` for testers, `production` for end users. */
  mode?: EnvironmentMode;
  /** The team's name for the key's environment, such as `UAT`. */
  environmentName?: string;
  environmentId?: string;
  branding?: SeaproofBranding;
  /** The built-in feedback button's project settings. Null or absent uses SDK defaults. */
  launcher?: SeaproofLauncherSettings | null;
}

export type LauncherPosition = "top-left" | "middle-left" | "bottom-left" | "top-right" | "middle-right" | "bottom-right";

export interface SeaproofLauncherSettings {
  position: LauncherPosition | null;
  label: string | null;
  orientation: "horizontal" | "vertical";
  avoidObstructions: boolean;
}

/** The look set for the project in the Seaproof admin. Your own CSS variables win over it. */
export interface SeaproofBranding {
  /** `#rrggbb`, or null to keep the default. */
  primaryColor: string | null;
  /** The logo's version, or null when there is none. Fetch it with `client.logo()`. */
  logo: string | null;
}

export interface SeaproofOptions {
  /** The project's API key, starting with `sp_`. Create it under Project → API keys. */
  apiKey: string;
  /** Defaults to https://api.seaproof.io. */
  endpoint?: string;
  /** App version, reported with every submission. */
  appVersion?: string;
  /**
   * The commit the app was built from, so a bug leads straight to the code. Pass it from your
   * build, for example `commit: import.meta.env.VITE_COMMIT_SHA`.
   */
  commit?: string;
  /** Default reporter, for example the signed-in user. */
  reporter?: Reporter;
  /** Extra context merged into every submission. */
  context?: () => FeedbackContext;
  fetch?: typeof fetch;
  /**
   * `auto` (default) follows the API key's environment: keys in a test-mode environment are for
   * testers, keys in a production-mode environment for end users. Until the environment is known, it behaves as
   * production.
   */
  mode?: SeaproofMode;
  /** Use the colour and logo set for the project in the admin. Default true. */
  branding?: boolean;
  /** What to record locally for reports. `false` records nothing. Default: everything. */
  diagnostics?: CaptureOptions | false;
  /** Attach the diagnostics to reports. Default: only in tester mode. */
  includeDiagnostics?: boolean;
  /** Send a bug report on its own for uncaught errors. At most three per page load, each error once. */
  reportCrashes?: boolean;
  /** Where the reporter key and read markers are kept. Default: `localStorage`, or memory when it is unavailable. */
  storage?: KeyValueStorage;
}

/** How an item's status reads to the person who sent it. */
export type PublicStatus = "received" | "underReview" | "inProgress" | "done" | "closed";

/** Feedback sent from this browser, newest first. */
export interface OwnFeedback {
  id: string;
  number: number;
  type: FeedbackType;
  title: string;
  status: PublicStatus;
  /** Replies from the team. */
  replies: number;
  createdAt: string;
  lastReplyAt: string | null;
}

export interface ConversationMessage {
  id: string;
  from: "team" | "you";
  body: string;
  createdAt: string;
}

export interface ReporterAttachment {
  id: string;
  kind: "screenshot" | "recording";
  url: string;
  createdAt: string;
  messageId?: string | null;
}

export interface OwnFeedbackDetail {
  id: string;
  number: number;
  type: FeedbackType;
  title: string;
  description: string;
  status: PublicStatus;
  createdAt: string;
  messages: ConversationMessage[];
  /** Confirmed media with short-lived download URLs. */
  attachments?: ReporterAttachment[];
  /** Recent changes to the public status of this report. */
  statusUpdates?: { id: string; status: PublicStatus; createdAt: string }[];
}

/** An idea the team published on the project's idea board. */
export interface PublicIdea {
  id: string;
  title: string;
  summary: string | null;
  status: PublicStatus;
  votes: number;
  /** This browser has voted for it. */
  voted: boolean;
  createdAt: string;
}

/** Where the reporter key and read markers are kept. `localStorage` by default. */
/** What Seaproof Assist offers in this project. Both are off unless the team turned them on. */
export interface AssistSettings {
  /** Known problems and public ideas like what the user is writing. */
  suggestions: boolean;
  /** Up to five questions about what a report is missing, asked after it is saved. */
  followUpQuestions: boolean;
}

/** A known problem (`bug`) or public idea that matches a draft. */
export interface Suggestion {
  id: string;
  type: "bug" | "idea";
  title: string;
  summary: string | null;
  status: PublicStatus;
  votes: number;
}

export interface ReviewResult {
  questions: string[];
  /** Receipts for saving the corresponding questions when shown on a report. */
  questionReceipts?: string[] | null;
  /** No questions this time because the organization's monthly Assist limit is reached. */
  limited: boolean;
}

export interface KeyValueStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}
