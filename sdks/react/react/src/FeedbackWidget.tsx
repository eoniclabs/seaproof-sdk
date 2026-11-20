import {
  canRecordScreen,
  captureScreenshot,
  newConversationId,
  ScreenRecorder,
  type AssistSettings,
  type AttachmentInput,
  type FeedbackType,
  type OwnFeedback,
  type PublicIdea,
  type Reporter,
  type ScreenRecording,
  type Suggestion,
} from "@seaproof/core";
import { useCallback, useEffect, useId, useRef, useState, useSyncExternalStore, type CSSProperties, type FormEvent, type ReactNode } from "react";
import { Annotator } from "./Annotator";
import { SuggestionList } from "./AssistViews";
import { FeedbackLauncher } from "./FeedbackLauncher";
import { ArrowUpIcon, CameraIcon, CloseIcon, SeaproofMark, SparkleIcon, StopIcon, typeIcons, VideoIcon } from "./icons";
import { IdeasView } from "./IdeasView";
import { MyFeedbackView } from "./MyFeedbackView";
import { quickReplyLabels, script, type AssistantTurn, type QuickReply } from "./script";
import { useSeaproof } from "./SeaproofProvider";
import { css } from "./styles";

export interface FeedbackWidgetProps {
  /** Text on the floating button. Overrides the project setting. */
  label?: string;
  /**
   * Show the floating button. `"auto"` (default) shows it to testers only; in production,
   * open the widget from your own button with `useSeaproof().open()`.
   */
  launcher?: boolean | "auto";
  /** The signed-in user, if your app has one. Add a `userHash` from your backend to share their conversations across devices. */
  reporter?: Reporter;
  /**
   * Defaults to capturing the page when the widget opens. Pass a function to capture something
   * else, or `false` to never offer it.
   */
  screenshot?: (() => Promise<Blob>) | false;
  /** Called when the report is saved, which happens with the user's first message. */
  onSubmitted?: (result: { id: string; number: number }) => void;
  /**
   * The tabs to offer. "mine" (the user's own feedback and the team's replies) and "ideas" (the
   * idea board) appear only when there is something to show. Default: all three.
   */
  views?: WidgetView[];
  /**
   * Offer to record the screen. Default: testers only, in browsers that can. The recording shows
   * the whole shared surface; `data-seaproof-mask` only applies to screenshots.
   */
  recording?: boolean;
  /** Light, dark, or follow the system. Default: light. */
  colorScheme?: "light" | "dark" | "auto";
}

export type WidgetView = "send" | "mine" | "ideas";

const viewLabels: Record<WidgetView, string> = { send: "Send", mine: "Your feedback", ideas: "Ideas" };

const typeLabels: Record<FeedbackType, string> = { bug: "Something is wrong", idea: "Idea", feedback: "Feedback", question: "Question" };

/** Testers mostly report problems; people in production mostly suggest and comment. */
const typeOrder = { tester: ["bug", "idea", "feedback", "question"], production: ["idea", "feedback", "bug", "question"] } satisfies Record<
  string,
  FeedbackType[]
>;

const prompts: Record<FeedbackType, { label: string; placeholder: string }> = {
  bug: { label: "What happened?", placeholder: "What did you do, and what happened?" },
  idea: { label: "What would you like?", placeholder: "Describe your idea…" },
  feedback: { label: "What do you think?", placeholder: "Tell us what you think…" },
  question: { label: "What do you want to know?", placeholder: "Ask anything about the app…" },
};

/** Wait this long after the last keystroke before looking for similar reports. */
const SUGGEST_DELAY_MS = 600;
const MIN_SUGGEST_LENGTH = 10;
/** Seaproof Assist asks at most this many questions per report. */
const MAX_QUESTIONS = 5;

/** One line in the conversation. Media lines show what was attached. */
type ChatItem =
  | { id: number; from: "assistant"; text: string; quickReplies: QuickReply[] }
  | { id: number; from: "you"; text: string }
  | { id: number; from: "you"; media: "image" | "video"; url: string; label: string };

type Saved = { id: string; number: number };
type Shot = { file: Blob; url: string; hidden: number; marked: boolean };

export function FeedbackWidget({
  label,
  launcher = "auto",
  reporter,
  screenshot,
  onSubmitted,
  views = ["send", "mine", "ideas"],
  recording: allowRecording,
  colorScheme = "light",
}: FeedbackWidgetProps) {
  const { client, isTesterMode, isOpen, open, close } = useSeaproof();
  const showLauncher = launcher === "auto" ? isTesterMode : launcher;
  const [type, setType] = useState<FeedbackType>(isTesterMode ? "bug" : "feedback");
  const [draft, setDraft] = useState("");
  const [missingText, setMissingText] = useState(false);
  const [items, setItems] = useState<ChatItem[]>([]);
  const [saved, setSaved] = useState<Saved | null>(null);
  const activeReport = useRef<string | null>(null);
  const [finished, setFinished] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // The screenshot is taken when the widget opens, so it shows the page as the user saw it.
  const [shot, setShot] = useState<Shot | null>(null);
  const [shotRemoved, setShotRemoved] = useState(false);
  const [annotating, setAnnotating] = useState<Blob | null>(null);
  const [recording, setRecording] = useState<ScreenRecording | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const recorderRef = useRef<ScreenRecorder | null>(null);
  const [view, setView] = useState<WidgetView>("send");
  const [mine, setMine] = useState<OwnFeedback[]>([]);
  const [ideas, setIdeas] = useState<PublicIdea[]>([]);
  const [assist, setAssist] = useState<AssistSettings>({ suggestions: false, followUpQuestions: false });
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [voted, setVoted] = useState<ReadonlySet<string>>(new Set());
  const [questions, setQuestions] = useState<{ text: string; receipt?: string }[]>([]);
  // All Assist help for one report is one conversation against the plan's quota.
  const [conversationId, setConversationId] = useState(newConversationId);
  const nextId = useRef(0);
  // Object URLs for the thumbnails in the conversation, freed when it starts over.
  const urls = useRef<string[]>([]);
  // The first screenshot stays at hand after it is sent, to mark it up later in the conversation.
  const firstShot = useRef<Blob | null>(null);
  const offerRecording = (allowRecording ?? isTesterMode) && canRecordScreen();
  const offerScreenshot = screenshot !== false;
  const branding = useSyncExternalStore(
    client.subscribe,
    () => client.branding,
    () => undefined,
  );
  const launcherSettings = useSyncExternalStore(client.subscribe, () => client.launcher, () => undefined);
  const logoUrl = useLogoUrl(branding?.logo ?? null, client.logo);
  // "Your feedback" and votes belong to this user; with a userHash, on every device.
  useEffect(() => {
    if (reporter) client.identify(reporter);
  }, [client, reporter]);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const listRef = useRef<HTMLOListElement>(null);
  const id = useId();
  const wantsMine = views.includes("mine");
  const wantsIdeas = views.includes("ideas");
  const scriptOptions = { isTesterMode, canMark: offerScreenshot, canRecord: offerRecording };

  // Optional extras: a failure here must never get in the way of sending feedback.
  const loadExtras = useCallback(() => {
    if (wantsMine) client.myFeedback().then(setMine, () => setMine([]));
    if (wantsIdeas) client.ideas().then(setIdeas, () => setIdeas([]));
  }, [client, wantsMine, wantsIdeas]);

  useEffect(() => {
    if (isOpen) loadExtras();
  }, [isOpen, loadExtras]);

  useEffect(() => {
    if (isOpen) void client.assistSettings().then(setAssist);
  }, [isOpen, client]);

  const toUrl = useCallback((blob: Blob) => {
    const url = URL.createObjectURL(blob);
    urls.current.push(url);
    return url;
  }, []);

  // Before the widget draws itself over the page: the widget is left out of its own screenshot anyway.
  useEffect(() => {
    if (!isOpen || saved || shot || shotRemoved || !offerScreenshot) return;
    let cancelled = false;
    (screenshot || (() => captureScreenshot()))().then(
      (file) => {
        if (cancelled) return;
        firstShot.current = file;
        setShot({ file, url: toUrl(file), hidden: 0, marked: false });
      },
      // Without a screenshot the report still goes out.
      () => {},
    );
    return () => {
      cancelled = true;
    };
  }, [isOpen, saved, shot, shotRemoved, offerScreenshot, screenshot, toUrl]);

  // Known problems and ideas like the first message, once the user pauses typing.
  const text = draft.trim();
  const suggestFor = !saved && assist.suggestions && type !== "question" && text.length >= MIN_SUGGEST_LENGTH ? text : "";
  useEffect(() => {
    if (!suggestFor) {
      setSuggestions([]);
      return;
    }
    let cancelled = false;
    const timer = setTimeout(() => {
      client.suggest(suggestFor, type).then(
        (found) => !cancelled && setSuggestions(found),
        () => !cancelled && setSuggestions([]),
      );
    }, SUGGEST_DELAY_MS);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [client, suggestFor, type]);

  const available = views.filter((v) => v === "send" || (v === "mine" ? mine.length > 0 : ideas.length > 0));
  const unread = mine.some((m) => client.hasUnreadReply(m));

  const startOver = useCallback(() => {
    urls.current.forEach((u) => URL.revokeObjectURL(u));
    urls.current = [];
    firstShot.current = null;
    activeReport.current = null;
    setItems([]);
    setSaved(null);
    setBusy(false);
    setFinished(false);
    setError(null);
    setShot(null);
    setShotRemoved(false);
    setRecording(null);
    setSuggestions([]);
    setQuestions([]);
    setConversationId(newConversationId());
    setDraft("");
    setMissingText(false);
    setType(isTesterMode ? "bug" : "feedback");
    setView("send");
  }, [isTesterMode]);

  /** Closing ends the conversation once it is saved; a draft that was never sent stays. */
  const dismiss = useCallback(() => {
    if (saved) startOver();
    close();
  }, [saved, startOver, close]);

  useEffect(() => {
    if (!isOpen || annotating) return;
    if (view === "send") textareaRef.current?.focus();
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && dismiss();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [isOpen, dismiss, view, annotating]);

  useEffect(() => {
    const list = listRef.current;
    if (list) list.scrollTop = list.scrollHeight;
  }, [items, busy]);

  function say(turn: AssistantTurn) {
    setItems((all) => [...all, { id: nextId.current++, from: "assistant", ...turn }]);
  }

  function addYours(item: { text: string } | { media: "image" | "video"; url: string; label: string }) {
    setItems((all) => [...all, { id: nextId.current++, from: "you", ...item }]);
  }

  function shotLabel(s: Shot): string {
    return s.hidden > 0 ? `Screenshot, marked up, ${s.hidden} ${s.hidden === 1 ? "area" : "areas"} hidden` : s.marked ? "Screenshot, marked up" : "Screenshot";
  }

  /** The attachments waiting in the composer, shown in the conversation as they go out. */
  function takePending(): AttachmentInput[] {
    const attachments: AttachmentInput[] = [];
    if (shot) {
      attachments.push({ kind: "screenshot", file: shot.file, fileName: shot.marked ? "screenshot-marked.png" : "screenshot.png" });
      addYours({ media: "image", url: shot.url, label: shotLabel(shot) });
    }
    if (recording) {
      attachments.push({ kind: "recording", file: recording.file, fileName: recording.fileName });
      addYours({ media: "video", url: toUrl(recording.file), label: `Screen recording, ${formatDuration(recording.durationMs)}` });
    }
    setShot(null);
    setRecording(null);
    return attachments;
  }

  async function send(event?: FormEvent, linkedTo?: string) {
    event?.preventDefault();
    if (busy) return;
    setError(null);
    if (!saved) {
      // The button stays enabled so it can say what is missing instead of silently doing nothing.
      if (!text) {
        setMissingText(true);
        textareaRef.current?.focus();
        return;
      }
      await saveReport(linkedTo);
    } else {
      if (!text && !shot && !recording) return;
      await addToReport(saved);
    }
  }

  /** The first message saves the report, with what is attached. Assist only adds to it after that. */
  async function saveReport(linkedTo?: string) {
    const description = text;
    const firstItem = nextId.current;
    addYours({ text: description });
    setDraft("");
    setBusy(true);
    const pendingShot = shot;
    const pendingRecording = recording;
    const attachments = takePending();
    let result: Saved;
    try {
      result = await client.submit({ type, description, reporter, attachments, linkedTo });
    } catch (e) {
      // Nothing was saved: put it all back so the user can try again.
      setItems((all) => all.filter((i) => i.id < firstItem));
      setDraft(description);
      setShot(pendingShot);
      setRecording(pendingRecording);
      setError(e instanceof Error ? e.message : "Sending failed.");
      setBusy(false);
      return;
    }
    // Saved: nothing after this may undo the conversation, or a retry would send it twice.
    activeReport.current = result.id;
    setSaved(result);
    setSuggestions([]);
    try {
      onSubmitted?.(result);
      await followUp(result, description, linkedTo);
    } catch (e) {
      console.warn("Seaproof: the report was saved, but the follow-up failed.", e);
      if (activeReport.current === result.id) say(script.saved(type, result.number, scriptOptions));
    } finally {
      if (activeReport.current === result.id) setBusy(false);
    }
  }

  async function followUp(result: Saved, description: string, linkedTo: string | undefined) {
    if (linkedTo) {
      say({ text: `Thanks! It is linked to the problem the team already knows about (#${result.number}). You will see updates under Your feedback.`, quickReplies: ["done"] });
      return;
    }
    if (assist.followUpQuestions) {
      const review = await client.review(type, description, conversationId, result.id);
      if (activeReport.current !== result.id) return;
      const [first, ...rest] = review.questions.slice(0, MAX_QUESTIONS).map((text, index) => ({
        text, receipt: review.questionReceipts?.[index],
      }));
      const recorded = first && await recordQuestion(result.id, first.receipt);
      if (activeReport.current !== result.id) return;
      if (first && recorded) {
        setQuestions(rest);
        say(script.question(type, result.number, first.text, true, scriptOptions));
        return;
      }
    }
    say(script.saved(type, result.number, scriptOptions));
  }

  async function recordQuestion(feedbackId: string, receipt?: string) {
    return !receipt || await client.recordAssistQuestion?.(feedbackId, receipt);
  }

  /** Later messages and files go to the saved report. */
  async function addToReport(report: Saved) {
    const message = text;
    if (message) addYours({ text: message });
    setDraft("");
    setBusy(true);
    const hadShot = !!shot;
    const attachments = takePending();
    try {
      const sent = message ? await client.sendMessage(report.id, message) : null;
      if (attachments.length) await client.addAttachments(report.id, attachments, sent?.id);
      if (activeReport.current !== report.id) return;
      const [next, ...rest] = questions;
      const recorded = message && next && await recordQuestion(report.id, next.receipt);
      if (activeReport.current !== report.id) return;
      if (next && recorded) {
        setQuestions(rest);
        say(script.question(type, report.number, next.text, false, scriptOptions));
      } else {
        if (message) setQuestions([]);
        say(script.added(report.number, message ? "message" : hadShot ? "screenshot" : "recording"));
      }
    } catch (e) {
      if (activeReport.current === report.id) setError(e instanceof Error ? `It could not be added: ${e.message}` : "It could not be added.");
    } finally {
      if (activeReport.current === report.id) setBusy(false);
    }
  }

  async function startMarking() {
    setError(null);
    let image = shot?.file ?? firstShot.current;
    if (!image && offerScreenshot) {
      try {
        image = await (screenshot || (() => captureScreenshot()))();
      } catch {
        setError("The screenshot could not be taken.");
        return;
      }
    }
    if (image) setAnnotating(image);
  }

  function finishMarking(marked: Blob, hidden: number) {
    setAnnotating(null);
    setShotRemoved(false);
    const next = { file: marked, url: toUrl(marked), hidden, marked: true };
    setShot(next);
    // Once the report is saved, a marked-up screenshot goes straight to it.
    if (saved) void sendAttachmentsNow(saved, [{ kind: "screenshot", file: marked, fileName: "screenshot-marked.png" }], next);
  }

  async function sendAttachmentsNow(report: Saved, attachments: AttachmentInput[], sentShot?: Shot) {
    setBusy(true);
    if (sentShot) {
      addYours({ media: "image", url: sentShot.url, label: shotLabel(sentShot) });
      setShot(null);
    }
    try {
      await client.addAttachments(report.id, attachments);
      say(script.added(report.number, sentShot ? "screenshot" : "recording"));
    } catch (e) {
      setError(e instanceof Error ? `It could not be added: ${e.message}` : "It could not be added.");
    } finally {
      setBusy(false);
    }
  }

  async function startRecording() {
    setError(null);
    const report = saved;
    const recorder = new ScreenRecorder({
      // Also runs when the user ends sharing in the browser or the time limit is reached.
      onStop: (result) => {
        recorderRef.current = null;
        setIsRecording(false);
        open();
        if (report) {
          addYours({ media: "video", url: toUrl(result.file), label: `Screen recording, ${formatDuration(result.durationMs)}` });
          void sendAttachmentsNow(report, [{ kind: "recording", file: result.file, fileName: result.fileName }]);
        } else {
          setRecording(result);
        }
      },
    });
    try {
      // Must run in the click handler: browsers only allow it after a user gesture.
      await recorder.start();
    } catch (e) {
      if (!(e instanceof DOMException && e.name === "NotAllowedError")) {
        setError(e instanceof Error ? e.message : "The screen could not be recorded.");
      }
      return;
    }
    recorderRef.current = recorder;
    setIsRecording(true);
    // Hidden, not ended: the conversation is waiting when the recording stops.
    close();
  }

  function onQuickReply(reply: QuickReply) {
    if (reply === "mark") void startMarking();
    else if (reply === "record") void startRecording();
    else setFinished(true);
  }

  function suggestIdea() {
    setType("idea");
    setView("send");
  }

  async function toggleVote(idea: Suggestion) {
    const voting = !voted.has(idea.id);
    const next = new Set(voted);
    if (voting) next.add(idea.id);
    else next.delete(idea.id);
    setVoted(next);
    try {
      await (voting ? client.vote(idea.id) : client.unvote(idea.id));
    } catch {
      setVoted(voted);
    }
  }

  const prompt = prompts[type];
  const greeting = script.greeting(scriptOptions);
  const lastAssistant = [...items].reverse().find((i) => i.from === "assistant");

  return (
    <div
      className="seaproof-root"
      data-seaproof-ignore=""
      data-seaproof-theme={colorScheme}
      style={brandStyle(branding?.primaryColor ?? null)}
    >
      <style>{css}</style>
      {isRecording && <RecordingBar recorder={recorderRef.current} onStop={() => void recorderRef.current?.stop()} />}
      {showLauncher && !isOpen && !isRecording && (
        <FeedbackLauncher label={label} config={launcherSettings} tester={isTesterMode} unread={unread} onOpen={open} />
      )}
      {isOpen && annotating && (
        <Annotator image={annotating} isTesterMode={isTesterMode} onDone={finishMarking} onCancel={() => setAnnotating(null)} />
      )}
      {isOpen && !annotating && (
        <div className="seaproof-backdrop" onClick={(e) => e.target === e.currentTarget && dismiss()}>
          <div className="seaproof-panel seaproof-chat-panel" role="dialog" aria-modal="true" aria-labelledby={`${id}-title`}>
            {isTesterMode && (
              <div className="seaproof-test-strip">
                <span className="seaproof-dot" aria-hidden="true" />
                <span className="seaproof-test-strip-mode">Test mode</span>
                {client.environmentName && <span className="seaproof-test-strip-env">{client.environmentName}</span>}
              </div>
            )}
            {finished && saved ? (
              <div className="seaproof-sent">
                <div className="seaproof-mark-wrap">
                  <SeaproofMark />
                </div>
                <h2 id={`${id}-title`}>Thanks!</h2>
                <p>{type === "question" ? "The team answers under Your feedback." : "Your feedback is with the team."}</p>
                <span className="seaproof-ref">#{saved.number}</span>
                <div className="seaproof-sent-actions">
                  <button type="button" className="seaproof-button seaproof-primary" onClick={dismiss}>
                    Close
                  </button>
                  <button type="button" className="seaproof-link" style={{ justifyContent: "center" }} onClick={startOver}>
                    Send something else
                  </button>
                </div>
              </div>
            ) : (
              <>
                <div className="seaproof-header">
                  <h2 id={`${id}-title`}>
                    {logoUrl && <img className="seaproof-logo" src={logoUrl} alt="" />}
                    Send feedback
                  </h2>
                  <button type="button" className="seaproof-icon-button" aria-label="Close" onClick={dismiss}>
                    <CloseIcon />
                  </button>
                </div>
                {available.length > 1 && (
                  <div className="seaproof-tabs" role="tablist" aria-label="Feedback">
                    {available.map((v) => (
                      <button key={v} type="button" role="tab" aria-selected={view === v} onClick={() => setView(v)}>
                        {viewLabels[v]}
                        {v === "mine" && unread && <span className="seaproof-dot" role="img" aria-label="New reply" />}
                      </button>
                    ))}
                  </div>
                )}
                {view === "mine" ? (
                  <MyFeedbackView items={mine} onChanged={loadExtras} />
                ) : view === "ideas" ? (
                  <IdeasView ideas={ideas} onSuggest={suggestIdea} />
                ) : (
                  <form className="seaproof-chat" onSubmit={(e) => void send(e)} noValidate>
                    <ol ref={listRef} className="seaproof-conversation" aria-live="polite" aria-label="Conversation">
                      <AssistantLine text={greeting.text} />
                      {!saved && (
                        <li className="seaproof-chat-types">
                          <fieldset className="seaproof-chips" role="radiogroup" aria-label="Type">
                            {typeOrder[isTesterMode ? "tester" : "production"].map((t) => (
                              <label key={t} className="seaproof-chip" data-type={t}>
                                <input type="radio" name={`${id}-type`} value={t} checked={type === t} disabled={busy} onChange={() => setType(t)} />
                                {typeIcons[t]()}
                                {typeLabels[t]}
                              </label>
                            ))}
                          </fieldset>
                        </li>
                      )}
                      {items.map((item) =>
                        item.from === "assistant" ? (
                          <AssistantLine key={item.id} text={item.text}>
                            {item === lastAssistant && !busy && item.quickReplies.length > 0 && (
                              <span className="seaproof-quick-replies">
                                {item.quickReplies.map((r) => (
                                  <button
                                    key={r}
                                    type="button"
                                    className={r === "done" ? "seaproof-quick seaproof-quick-done" : "seaproof-quick"}
                                    onClick={() => onQuickReply(r)}
                                  >
                                    {r === "mark" ? <CameraIcon size={16} /> : r === "record" ? <VideoIcon size={16} /> : null}
                                    {quickReplyLabels[r]}
                                  </button>
                                ))}
                              </span>
                            )}
                          </AssistantLine>
                        ) : "media" in item ? (
                          <li key={item.id} className="seaproof-message seaproof-from-you seaproof-media">
                            {item.media === "image" ? (
                              <img src={item.url} alt="" />
                            ) : (
                              <video src={item.url} controls muted aria-label={item.label} />
                            )}
                            <span className="seaproof-media-label">{item.label}</span>
                          </li>
                        ) : (
                          <li key={item.id} className="seaproof-message seaproof-from-you">
                            <span className="seaproof-bubble">{item.text}</span>
                          </li>
                        ),
                      )}
                      {busy && (
                        <li className="seaproof-message seaproof-from-assistant" aria-label="Sending">
                          <span className="seaproof-bubble seaproof-typing" aria-hidden="true">
                            <span />
                            <span />
                            <span />
                          </span>
                        </li>
                      )}
                    </ol>
                    {!saved && suggestions.length > 0 && (
                      <div className="seaproof-chat-suggestions">
                        <SuggestionList
                          suggestions={suggestions}
                          voted={voted}
                          onLink={(s) => void send(undefined, s.id)}
                          onVote={(s) => void toggleVote(s)}
                        />
                      </div>
                    )}
                    {(missingText || error) && (
                      <p id={`${id}-error`} className="seaproof-error seaproof-chat-error" role="alert">
                        {missingText && !error ? "Please write a few words, so the team knows what this is about." : error}
                      </p>
                    )}
                    {(shot || recording) && (
                      <div className="seaproof-pending">
                        {shot && (
                          <span className="seaproof-pending-item">
                            <button type="button" className="seaproof-pending-thumb" aria-label="Mark up the screenshot" onClick={() => void startMarking()}>
                              <img src={shot.url} alt="" />
                            </button>
                            <span className="seaproof-pending-text">
                              <span className="seaproof-attachment-title">{shotLabel(shot)}</span>
                              <span className="seaproof-attachment-meta">{saved ? "Sent with your next message" : "Tap to mark it up"}</span>
                            </span>
                            <button
                              type="button"
                              className="seaproof-icon-button"
                              aria-label="Remove the screenshot"
                              onClick={() => {
                                setShot(null);
                                setShotRemoved(true);
                              }}
                            >
                              <CloseIcon size={16} />
                            </button>
                          </span>
                        )}
                        {recording && (
                          <span className="seaproof-pending-item">
                            <VideoIcon />
                            <span className="seaproof-pending-text">
                              <span className="seaproof-attachment-title">Screen recording, {formatDuration(recording.durationMs)}</span>
                            </span>
                            <button type="button" className="seaproof-icon-button" aria-label="Remove the recording" onClick={() => setRecording(null)}>
                              <CloseIcon size={16} />
                            </button>
                          </span>
                        )}
                      </div>
                    )}
                    <div className="seaproof-composer">
                      <label className="seaproof-visually-hidden" htmlFor={`${id}-message`}>
                        {saved ? "Add to your report" : prompt.label}
                      </label>
                      <textarea
                        id={`${id}-message`}
                        ref={textareaRef}
                        rows={1}
                        maxLength={10000}
                        value={draft}
                        aria-invalid={missingText}
                        aria-describedby={missingText || error ? `${id}-error` : undefined}
                        onChange={(e) => {
                          setDraft(e.target.value);
                          if (e.target.value.trim()) setMissingText(false);
                        }}
                        onKeyDown={(e) => {
                          // Enter sends, as in any chat; Shift+Enter starts a new line.
                          if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
                            e.preventDefault();
                            e.currentTarget.form?.requestSubmit();
                          }
                        }}
                        placeholder={saved ? "Add something…" : prompt.placeholder}
                      />
                      {offerScreenshot && (
                        <button type="button" className="seaproof-icon-button" aria-label="Mark on the screen" disabled={busy} onClick={() => void startMarking()}>
                          <CameraIcon />
                        </button>
                      )}
                      {offerRecording && (
                        <button
                          type="button"
                          className="seaproof-icon-button"
                          aria-label="Record the screen"
                          disabled={busy}
                          onClick={() => void startRecording()}
                        >
                          <VideoIcon />
                        </button>
                      )}
                      <button type="submit" className="seaproof-button seaproof-primary seaproof-round" aria-label={busy ? "Sending…" : "Send"} disabled={busy}>
                        <ArrowUpIcon />
                      </button>
                    </div>
                    {isTesterMode && !saved && <p className="seaproof-note seaproof-chat-note">Device details, console and network log are sent along.</p>}
                  </form>
                )}
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function AssistantLine({ text, children }: { text: string; children?: ReactNode }) {
  return (
    <li className="seaproof-message seaproof-from-assistant">
      <span className="seaproof-assistant-row">
        <span className="seaproof-avatar" aria-hidden="true">
          <SparkleIcon size={14} />
        </span>
        <span className="seaproof-bubble">{text}</span>
      </span>
      {children}
    </li>
  );
}

function formatDuration(ms: number): string {
  const seconds = Math.floor(ms / 1000);
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}

/** Shown while the dialog is hidden for recording, so the user can stop. */
function RecordingBar({ recorder, onStop }: { recorder: ScreenRecorder | null; onStop: () => void }) {
  const [elapsed, setElapsed] = useState(0);
  useEffect(() => {
    const timer = setInterval(() => setElapsed(recorder?.elapsedMs() ?? 0), 500);
    return () => clearInterval(timer);
  }, [recorder]);

  return (
    <div className="seaproof-recording" role="status">
      <span className="seaproof-recording-dot" aria-hidden="true" />
      Recording <span className="seaproof-recording-time">{formatDuration(elapsed)}</span>
      <span className="seaproof-recording-hint">Show the problem in the app</span>
      <button type="button" onClick={onStop}>
        <StopIcon />
        Stop
      </button>
    </div>
  );
}

/**
 * The admin's colour, as fallback variables: `--seaproof-primary` set by the app still wins.
 * The text colour on it is black or white, whichever reads better.
 */
function brandStyle(primary: string | null): CSSProperties | undefined {
  if (!primary || !/^#[0-9a-f]{6}$/i.test(primary)) return undefined;
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(primary.slice(i, i + 2), 16) / 255);
  const linear = (c: number) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
  const luminance = 0.2126 * linear(r!) + 0.7152 * linear(g!) + 0.0722 * linear(b!);
  return {
    "--seaproof-brand-primary": primary,
    "--seaproof-brand-on-primary": luminance > 0.4 ? "#111111" : "#ffffff",
  } as CSSProperties;
}

/** An object URL for the project's logo, fetched once per version. */
function useLogoUrl(version: string | null, fetchLogo: () => Promise<Blob | undefined>): string | undefined {
  const [url, setUrl] = useState<string>();
  useEffect(() => {
    if (!version) return;
    let objectUrl: string | undefined;
    let cancelled = false;
    fetchLogo().then(
      (blob) => {
        if (cancelled || !blob) return;
        objectUrl = URL.createObjectURL(blob);
        setUrl(objectUrl);
      },
      // A missing logo must never get in the way of feedback.
      () => {},
    );
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
      setUrl(undefined);
    };
  }, [version, fetchLogo]);
  return url;
}
