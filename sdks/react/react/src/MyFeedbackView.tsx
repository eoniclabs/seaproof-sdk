import type { OwnFeedback, OwnFeedbackDetail, PublicStatus, ReporterAttachment } from "@seaproof/core";
import { Fragment, useEffect, useState, type FormEvent } from "react";
import { statusLabels } from "./labels";
import { ChevronLeftIcon, SendIcon } from "./icons";
import { useSeaproof } from "./SeaproofProvider";

const statusUpdateText: Record<PublicStatus, string> = {
  received: "Your report was reopened.",
  underReview: "The team is reviewing your report.",
  inProgress: "The team is working on your report.",
  done: "The team marked your report as resolved.",
  closed: "The team closed your report.",
};

function attachmentRow(file: ReporterAttachment) {
  return (
    <li className="seaproof-message seaproof-from-you" key={file.id}>
      <a href={file.url} target="_blank" rel="noreferrer">
        <img
          src={file.url}
          alt={file.kind === "recording" ? "Screen recording" : "Screenshot"}
          loading="lazy"
          style={{ maxWidth: "100%", maxHeight: 160 }}
        />
      </a>
    </li>
  );
}

/** The user's own feedback, and the conversation with the team on each. */
export function MyFeedbackView({ items, onChanged }: { items: OwnFeedback[]; onChanged: () => void }) {
  const { client } = useSeaproof();
  const [openId, setOpenId] = useState<string | null>(null);

  if (openId) {
    return <Conversation id={openId} onBack={() => (setOpenId(null), onChanged())} />;
  }

  return (
    <div className="seaproof-view">
      <h2 className="seaproof-visually-hidden">Your feedback</h2>
      <ul className="seaproof-list">
        {items.map((item) => (
          <li key={item.id}>
            <button type="button" onClick={() => setOpenId(item.id)}>
              <span className="seaproof-row-title">
                {client.hasUnreadReply(item) && <span className="seaproof-dot" role="img" aria-label="New reply" />}
                {item.title}
              </span>
              <span className="seaproof-muted">
                <span className="seaproof-badge" data-status={item.status}>
                  {statusLabels[item.status]}
                </span>
                {item.replies > 0 && ` · ${item.replies === 1 ? "1 reply" : `${item.replies} replies`}`}
              </span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}

function Conversation({ id, onBack }: { id: string; onBack: () => void }) {
  const { client } = useSeaproof();
  const [detail, setDetail] = useState<OwnFeedbackDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState("");
  const [sending, setSending] = useState(false);

  useEffect(() => {
    let active = true;
    client
      .myFeedbackItem(id)
      .then((d) => active && setDetail(d))
      .catch((e: unknown) => active && setError(e instanceof Error ? e.message : "Could not load it."));
    return () => {
      active = false;
    };
  }, [client, id]);

  async function send(event: FormEvent) {
    event.preventDefault();
    if (!detail || !message.trim()) return;
    setSending(true);
    try {
      const sent = await client.sendMessage(id, message.trim());
      setDetail({ ...detail, messages: [...detail.messages, sent] });
      setMessage("");
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Sending failed.");
    } finally {
      setSending(false);
    }
  }

  const attachments = detail?.attachments ?? [];
  const initial = attachments.filter((file) => !file.messageId && file.createdAt === detail?.createdAt);
  const timeline = [
    ...(detail?.messages ?? []).map((message) => ({
      createdAt: message.createdAt,
      row: (
        <Fragment key={message.id}>
          {attachments.filter((file) => file.messageId === message.id).map(attachmentRow)}
          <li className={`seaproof-message seaproof-from-${message.from}`}>
            <span className="seaproof-sender">{message.from === "team" ? "Team" : "You"}</span>
            <span className="seaproof-bubble">{message.body}</span>
          </li>
        </Fragment>
      ),
    })),
    ...(detail?.statusUpdates ?? []).map((update) => ({
      createdAt: update.createdAt,
      row: (
        <li className="seaproof-message seaproof-from-team" key={update.id}>
          <span className="seaproof-sender">Team</span>
          <span className="seaproof-bubble">{statusUpdateText[update.status]}</span>
        </li>
      ),
    })),
    ...attachments.filter((file) => !file.messageId && file.createdAt !== detail?.createdAt).map((file) => ({
      createdAt: file.createdAt,
      row: attachmentRow(file),
    })),
  ].sort((left, right) => Date.parse(left.createdAt) - Date.parse(right.createdAt));

  return (
    <form className="seaproof-view" onSubmit={send} style={{ paddingBottom: 16 }}>
      <button type="button" className="seaproof-link" style={{ alignSelf: "flex-start" }} onClick={onBack}>
        <ChevronLeftIcon />
        Your feedback
      </button>
      {detail ? (
        <>
          <h2 style={{ marginTop: 4 }}>{detail.title}</h2>
          <span className="seaproof-badge" data-status={detail.status}>
            {statusLabels[detail.status]}
          </span>
          <ol className="seaproof-messages">
            {initial.map(attachmentRow)}
            <li className="seaproof-message seaproof-from-you">
              <span className="seaproof-bubble">{detail.description}</span>
            </li>
            {timeline.map(({ row }) => row)}
          </ol>
          <div className="seaproof-reply">
            <label className="seaproof-visually-hidden" htmlFor={`seaproof-reply-${id}`}>
              Reply
            </label>
            <textarea
              id={`seaproof-reply-${id}`}
              rows={1}
              maxLength={5000}
              placeholder="Write a reply"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
            />
            <button
              type="submit"
              className="seaproof-button seaproof-primary seaproof-round"
              aria-label={sending ? "Sending…" : "Send"}
              disabled={sending || !message.trim()}
            >
              <SendIcon />
            </button>
          </div>
        </>
      ) : (
        !error && <p className="seaproof-muted">Loading…</p>
      )}
      {error && (
        <p className="seaproof-error" role="alert">
          {error}
        </p>
      )}
    </form>
  );
}
