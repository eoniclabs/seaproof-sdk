import type { FeedbackType } from "@seaproof/core";

/** A shortcut offered under the assistant's last message. */
export type QuickReply = "mark" | "record" | "done";

/** What the assistant says, and the shortcuts it offers. */
export interface AssistantTurn {
  text: string;
  quickReplies: QuickReply[];
}

export interface ScriptOptions {
  isTesterMode: boolean;
  canMark: boolean;
  canRecord: boolean;
}

/**
 * The conversation without AI: fixed lines that depend on the type and on what the user did.
 * The report is saved with the first message, so every later step only adds to it; Seaproof
 * Assist can replace these lines with its own without changing that.
 */
export const script = {
  greeting({ isTesterMode }: ScriptOptions): AssistantTurn {
    return {
      text: isTesterMode
        ? "What did you find? Describe it and send. A screenshot and the app's logs come along."
        : "Hi! What would you like to tell us?",
      quickReplies: [],
    };
  },

  saved(type: FeedbackType, number: number, options: ScriptOptions): AssistantTurn {
    const show = showOptions(options);
    switch (type) {
      case "bug":
        return {
          text: show.length
            ? `Thanks, it is saved as #${number}. Do you want to show us where it happens?`
            : `Thanks, it is saved as #${number}. Anything to add? Otherwise you are done.`,
          quickReplies: [...show, "done"],
        };
      case "idea":
        return { text: `Thanks for the idea, the team has it as #${number}. What would it help you do?`, quickReplies: ["done"] };
      case "question":
        return { text: `Thanks! The team answers here, and you find it under Your feedback (#${number}).`, quickReplies: ["done"] };
      default:
        return { text: `Thanks for telling us, it is saved as #${number}. Anything to add?`, quickReplies: [...show, "done"] };
    }
  },

  /** Seaproof Assist asks what the report is missing, after it is saved. */
  question(type: FeedbackType, number: number, question: string, first: boolean, options: ScriptOptions): AssistantTurn {
    return {
      text: first ? `Thanks, it is saved as #${number}. ${question}` : question,
      quickReplies: [...(type === "bug" || type === "feedback" ? showOptions(options) : []), "done"],
    };
  },

  added(number: number, what: "message" | "screenshot" | "recording"): AssistantTurn {
    const text =
      what === "screenshot"
        ? `The screenshot is attached to #${number}.`
        : what === "recording"
          ? `The recording is attached to #${number}.`
          : `Added to #${number}.`;
    return { text, quickReplies: ["done"] };
  },
};

function showOptions({ canMark, canRecord }: ScriptOptions): QuickReply[] {
  return [...(canMark ? (["mark"] as const) : []), ...(canRecord ? (["record"] as const) : [])];
}

export const quickReplyLabels: Record<QuickReply, string> = {
  mark: "Mark on the screen",
  record: "Record the screen",
  done: "Done",
};
