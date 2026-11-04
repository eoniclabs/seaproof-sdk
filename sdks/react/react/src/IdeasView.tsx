import type { PublicIdea } from "@seaproof/core";
import { useState } from "react";
import { statusLabels } from "./labels";
import { ChevronUpIcon, IdeaIcon } from "./icons";
import { useSeaproof } from "./SeaproofProvider";

/** The ideas the team published. One vote per browser; voting again takes it back. */
export function IdeasView({ ideas: initial, onSuggest }: { ideas: PublicIdea[]; onSuggest: () => void }) {
  const { client } = useSeaproof();
  const [ideas, setIdeas] = useState(initial);
  const [error, setError] = useState<string | null>(null);

  async function toggle(idea: PublicIdea) {
    const voted = !idea.voted;
    // Optimistic: the count changes at once and is put back if the call fails.
    const update = (v: boolean) =>
      setIdeas((all) =>
        all.map((i) => (i.id === idea.id ? { ...i, voted: v, votes: idea.votes + (v === idea.voted ? 0 : v ? 1 : -1) } : i)),
      );
    update(voted);
    try {
      await (voted ? client.vote(idea.id) : client.unvote(idea.id));
      setError(null);
    } catch (e) {
      update(idea.voted);
      setError(e instanceof Error ? e.message : "Voting failed.");
    }
  }

  return (
    <div className="seaproof-view">
      <h2 className="seaproof-visually-hidden">Ideas</h2>
      <ul className="seaproof-list">
        {ideas.map((idea) => (
          <li key={idea.id} className="seaproof-idea">
            <button
              type="button"
              className="seaproof-vote"
              aria-pressed={idea.voted}
              aria-label={`${idea.voted ? "Remove vote for" : "Vote for"} ${idea.title}, ${idea.votes} votes`}
              onClick={() => void toggle(idea)}
            >
              <ChevronUpIcon />
              {idea.votes}
            </button>
            <div className="seaproof-idea-text">
              <span className="seaproof-row-title">{idea.title}</span>
              {idea.summary && <span className="seaproof-muted">{idea.summary}</span>}
              {idea.status !== "received" && (
                <span className="seaproof-badge" data-status={idea.status}>
                  {statusLabels[idea.status]}
                </span>
              )}
            </div>
          </li>
        ))}
      </ul>
      {error && (
        <p className="seaproof-error" role="alert">
          {error}
        </p>
      )}
      <div className="seaproof-footer">
        <button type="button" className="seaproof-button seaproof-secondary" style={{ width: "100%" }} onClick={onSuggest}>
          <IdeaIcon size={18} />
          Suggest an idea
        </button>
      </div>
    </div>
  );
}
