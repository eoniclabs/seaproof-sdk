import type { PublicStatus } from "@seaproof/core";

export const statusLabels: Record<PublicStatus, string> = {
  received: "Received",
  underReview: "Under review",
  inProgress: "In progress",
  done: "Done",
  closed: "Closed",
};
