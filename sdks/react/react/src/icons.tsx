import type { FeedbackType } from "@seaproof/core";
import type { ReactNode } from "react";

/** Line icons in the Lucide style: 24 px grid, 1.75 px stroke, round ends. Decorative only. */
function Icon({ size = 20, strokeWidth = 1.75, children }: { size?: number; strokeWidth?: number; children: ReactNode }) {
  return (
    <svg
      className="seaproof-icon"
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {children}
    </svg>
  );
}

export const BugIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <path d="m8 2 1.88 1.88" />
    <path d="M14.12 3.88 16 2" />
    <path d="M9 7.13v-1a3 3 0 1 1 6 0v1" />
    <path d="M12 20c-3.3 0-6-2.7-6-6v-3a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v3c0 3.3-2.7 6-6 6" />
    <path d="M12 20v-9" />
    <path d="M6.53 9C4.6 8.8 3 7.1 3 5" />
    <path d="M6 13H2" />
    <path d="M3 21c0-2.1 1.7-3.9 3.8-4" />
    <path d="M20.97 5c0 2.1-1.6 3.8-3.5 4" />
    <path d="M22 13h-4" />
    <path d="M17.2 17c2.1.1 3.8 1.9 3.8 4" />
  </Icon>
);

export const MessageIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
  </Icon>
);

export const IdeaIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5" />
    <path d="M9 18h6" />
    <path d="M10 22h4" />
  </Icon>
);

export const QuestionIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <circle cx="12" cy="12" r="10" />
    <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
    <path d="M12 17h.01" />
  </Icon>
);

export const CloseIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="M18 6 6 18" />
    <path d="m6 6 12 12" />
  </Icon>
);

export const CheckIcon = ({ size = 16 }: { size?: number }) => (
  <Icon size={size} strokeWidth={3}>
    <path d="M20 6 9 17l-5-5" />
  </Icon>
);

export const ChevronUpIcon = ({ size = 16 }: { size?: number }) => (
  <Icon size={size} strokeWidth={2.25}>
    <path d="m18 15-6-6-6 6" />
  </Icon>
);

export const ChevronLeftIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="m15 18-6-6 6-6" />
  </Icon>
);

export const VideoIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="m22 8-6 4 6 4V8Z" />
    <rect width="14" height="12" x="2" y="6" rx="2" />
  </Icon>
);

export const CameraIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z" />
    <circle cx="12" cy="13" r="3" />
  </Icon>
);

export const SendIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="m22 2-7 20-4-9-9-4Z" />
    <path d="M22 2 11 13" />
  </Icon>
);

export const ArrowUpIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size} strokeWidth={2}>
    <path d="M12 19V5" />
    <path d="m5 12 7-7 7 7" />
  </Icon>
);

export const SparkleIcon = ({ size = 16 }: { size?: number }) => (
  <Icon size={size}>
    <path d="m12 3 1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z" />
  </Icon>
);

export const BoxIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <rect x="3" y="5" width="18" height="14" rx="2" />
  </Icon>
);

export const PointerIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="M5 19 19 5" />
    <path d="M19 5h-7" />
    <path d="M19 5v7" />
  </Icon>
);

export const PenIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="M12 20h9" />
    <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" />
  </Icon>
);

export const HideIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="M9.9 4.2A10 10 0 0 1 22 12a10 10 0 0 1-1.7 2.9" />
    <path d="M6.6 6.6A10 10 0 0 0 2 12s3.5 7 10 7a9.7 9.7 0 0 0 5.4-1.6" />
    <path d="m2 2 20 20" />
  </Icon>
);

export const UndoIcon = ({ size = 18 }: { size?: number }) => (
  <Icon size={size}>
    <path d="M9 14 4 9l5-5" />
    <path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11" />
  </Icon>
);

export const StopIcon = () => (
  <svg className="seaproof-icon" viewBox="0 0 24 24" width={12} height={12} fill="currentColor" aria-hidden="true" focusable="false">
    <rect x="5" y="5" width="14" height="14" rx="2" />
  </svg>
);

/** The Plimsoll mark: a ring with the waterline through it. Shown when feedback has been sent. */
export const SeaproofMark = ({ size = 64 }: { size?: number }) => (
  <svg className="seaproof-mark" viewBox="0 0 32 32" width={size} height={size} aria-hidden="true" focusable="false">
    <path className="seaproof-mark-water" d="M5.5 16a10.5 10.5 0 0 0 21 0z" />
    <circle cx="16" cy="16" r="10.5" fill="none" stroke="currentColor" strokeWidth="2.4" />
    <rect className="seaproof-mark-line" x="1" y="14.6" width="30" height="2.8" rx="1.4" />
  </svg>
);

export const typeIcons: Record<FeedbackType, () => ReactNode> = {
  bug: () => <BugIcon />,
  feedback: () => <MessageIcon />,
  idea: () => <IdeaIcon />,
  question: () => <QuestionIcon />,
};
