import type { Suggestion } from "@seaproof/core";
import { BugIcon, ChevronUpIcon, IdeaIcon } from "./icons";
import { statusLabels } from "./labels";

/**
 * Known problems and public ideas like the draft, shown while the user writes. A known problem
 * can be linked ("same problem"), an idea voted for; either way the user can still send.
 */
export function SuggestionList({
  suggestions,
  voted,
  onLink,
  onVote,
}: {
  suggestions: Suggestion[];
  voted: ReadonlySet<string>;
  onLink: (suggestion: Suggestion) => void;
  onVote: (suggestion: Suggestion) => void;
}) {
  if (suggestions.length === 0) return null;
  const ideasOnly = suggestions.every((s) => s.type === "idea");
  return (
    <section className="seaproof-suggestions" aria-live="polite" aria-label="Similar reports">
      <p className="seaproof-suggestions-title">{ideasOnly ? "Similar ideas" : "The team may already know about this"}</p>
      <ul>
        {suggestions.map((s) => (
          <li key={s.id} className="seaproof-suggestion" data-type={s.type}>
            {s.type === "idea" ? <IdeaIcon size={18} /> : <BugIcon size={18} />}
            <span className="seaproof-suggestion-text">
              <span className="seaproof-suggestion-title">{s.title}</span>
              {s.summary && <span className="seaproof-muted">{s.summary}</span>}
              {s.status !== "received" && (
                <span className="seaproof-badge" data-status={s.status}>
                  {statusLabels[s.status]}
                </span>
              )}
            </span>
            {s.type === "idea" ? (
              <button
                type="button"
                className="seaproof-vote seaproof-vote-small"
                aria-pressed={voted.has(s.id)}
                aria-label={`${voted.has(s.id) ? "Remove vote for" : "Vote for"} ${s.title}`}
                onClick={() => onVote(s)}
              >
                <ChevronUpIcon />
                {s.votes + (voted.has(s.id) ? 1 : 0)}
              </button>
            ) : (
              <button type="button" className="seaproof-link" onClick={() => onLink(s)}>
                Same for me
              </button>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}
