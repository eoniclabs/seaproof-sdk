import type { LauncherPosition, SeaproofLauncherSettings } from "@seaproof/core";
import { useEffect, useRef, useState } from "react";
import { MessageIcon } from "./icons";

const positions: LauncherPosition[] = ["top-left", "middle-left", "bottom-left", "top-right", "middle-right", "bottom-right"];
const margin = 20;
const clearance = 8;

type Bounds = Pick<DOMRect, "left" | "top" | "right" | "bottom">;

function choosePlacement(
  preferred: LauncherPosition, width: number, height: number, buttonWidth: number, buttonHeight: number, obstructions: Bounds[],
): LauncherPosition {
  function bounds(position: LauncherPosition): Bounds {
    const left = position.endsWith("left") ? margin : width - buttonWidth - margin;
    const top = position.startsWith("top") ? margin
      : position.startsWith("middle") ? (height - buttonHeight) / 2
      : height - buttonHeight - margin;
    return { left, top, right: left + buttonWidth, bottom: top + buttonHeight };
  }

  const origin = bounds(preferred);
  let best = preferred;
  let bestOverlap = Infinity;
  let bestDistance = Infinity;
  for (const position of positions) {
    const candidate = bounds(position);
    const overlap = obstructions.reduce((total, obstacle) => {
      const right = Math.min(candidate.right, obstacle.right + clearance);
      const left = Math.max(candidate.left, obstacle.left - clearance);
      const bottom = Math.min(candidate.bottom, obstacle.bottom + clearance);
      const top = Math.max(candidate.top, obstacle.top - clearance);
      return total + Math.max(0, right - left) * Math.max(0, bottom - top);
    }, 0);
    const distance = (candidate.left - origin.left) ** 2 + (candidate.top - origin.top) ** 2;
    if (overlap < bestOverlap || (overlap === bestOverlap && distance < bestDistance)) {
      best = position;
      bestOverlap = overlap;
      bestDistance = distance;
    }
  }
  return best;
}

export function FeedbackLauncher({
  label, config, tester, unread, onOpen,
}: {
  label?: string;
  config?: SeaproofLauncherSettings | null;
  tester: boolean;
  unread: boolean;
  onOpen: () => void;
}) {
  const ref = useRef<HTMLButtonElement>(null);
  const text = label ?? config?.label ?? "Feedback";
  const preferred = config?.position ?? "bottom-right";
  const avoidObstructions = config?.avoidObstructions === true;
  const [placement, setPlacement] = useState(preferred);

  useEffect(() => {
    if (!avoidObstructions || !ref.current) return;
    const button = ref.current;
    let frame = 0;
    let observed = new Set<Element>();
    const resize = typeof ResizeObserver === "undefined" ? undefined : new ResizeObserver(schedule);
    resize?.observe(button);
    const observer = new MutationObserver(schedule);
    observer.observe(document.body, { subtree: true, childList: true, attributes: true, attributeFilter: ["data-seaproof-avoid", "hidden", "class", "style"] });

    function update() {
      frame = 0;
      const elements = new Set(document.querySelectorAll("[data-seaproof-avoid]"));
      for (const element of observed) if (!elements.has(element)) resize?.unobserve(element);
      for (const element of elements) if (!observed.has(element)) resize?.observe(element);
      observed = elements;
      const obstructions = [...elements].flatMap((element) => {
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        return rect.width && rect.height && style.visibility === "visible" && style.opacity !== "0" ? [rect] : [];
      });
      const { width, height } = button.getBoundingClientRect();
      setPlacement(choosePlacement(preferred, document.documentElement.clientWidth, document.documentElement.clientHeight, width, height, obstructions));
    }

    function schedule() {
      if (!frame) frame = requestAnimationFrame(update);
    }

    window.addEventListener("resize", schedule);
    window.addEventListener("scroll", schedule, true);
    document.addEventListener("transitionend", schedule);
    update();
    return () => {
      resize?.disconnect();
      observer.disconnect();
      window.removeEventListener("resize", schedule);
      window.removeEventListener("scroll", schedule, true);
      document.removeEventListener("transitionend", schedule);
      if (frame) cancelAnimationFrame(frame);
    };
  }, [avoidObstructions, preferred]);

  return (
    <button
      ref={ref}
      type="button"
      className="seaproof-launcher"
      aria-label={text}
      data-position={avoidObstructions ? placement : preferred}
      data-orientation={config?.orientation}
      onClick={onOpen}
    >
      <MessageIcon />
      <span className="seaproof-launcher-label">{text}</span>
      {tester && <span className="seaproof-launcher-tag">TEST</span>}
      {unread && <span className="seaproof-launcher-dot" />}
    </button>
  );
}
