import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent, type ReactNode } from "react";
import { BoxIcon, HideIcon, PenIcon, PointerIcon, UndoIcon } from "./icons";

export type MarkTool = "box" | "arrow" | "pen" | "hide";

type Point = { x: number; y: number };
type Mark = { tool: MarkTool; points: Point[] };

const toolLabels: Record<MarkTool, string> = { box: "Circle", arrow: "Arrow", pen: "Draw", hide: "Hide" };
const toolIcons: Record<MarkTool, () => ReactNode> = {
  box: () => <BoxIcon />,
  arrow: () => <PointerIcon />,
  pen: () => <PenIcon />,
  hide: () => <HideIcon />,
};

const SIGNAL = "#e8590c";
const HIDDEN = "#0a1f2e";

/**
 * Marks up a screenshot: circle what matters, point at it, draw, or hide what is private.
 * Marks are kept in the image's own pixels, so the result has the screenshot's full size.
 * In production, hiding comes first: end users are more likely to have something private on screen.
 */
export function Annotator({
  image,
  isTesterMode,
  onDone,
  onCancel,
}: {
  image: Blob;
  isTesterMode: boolean;
  onDone: (marked: Blob, hidden: number) => void;
  onCancel: () => void;
}) {
  const tools: MarkTool[] = isTesterMode ? ["box", "arrow", "pen", "hide"] : ["hide", "box", "arrow", "pen"];
  const [tool, setTool] = useState<MarkTool>(tools[0]!);
  const [marks, setMarks] = useState<Mark[]>([]);
  const [bitmap, setBitmap] = useState<HTMLImageElement | null>(null);
  const [saving, setSaving] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const drawing = useRef<Mark | null>(null);

  useEffect(() => {
    const url = URL.createObjectURL(image);
    const img = new Image();
    img.onload = () => setBitmap(img);
    img.src = url;
    return () => URL.revokeObjectURL(url);
  }, [image]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !bitmap) return;
    canvas.width = bitmap.naturalWidth;
    canvas.height = bitmap.naturalHeight;
    render(canvas, bitmap, drawing.current ? [...marks, drawing.current] : marks);
  }, [bitmap, marks]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.stopPropagation();
        onCancel();
      }
    };
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
  }, [onCancel]);

  function pointFrom(e: ReactPointerEvent<HTMLCanvasElement>): Point {
    const rect = e.currentTarget.getBoundingClientRect();
    const canvas = e.currentTarget;
    return { x: ((e.clientX - rect.left) / rect.width) * canvas.width, y: ((e.clientY - rect.top) / rect.height) * canvas.height };
  }

  function redraw() {
    if (canvasRef.current && bitmap) render(canvasRef.current, bitmap, drawing.current ? [...marks, drawing.current] : marks);
  }

  function onPointerDown(e: ReactPointerEvent<HTMLCanvasElement>) {
    e.currentTarget.setPointerCapture(e.pointerId);
    drawing.current = { tool, points: [pointFrom(e)] };
  }

  function onPointerMove(e: ReactPointerEvent<HTMLCanvasElement>) {
    const mark = drawing.current;
    if (!mark) return;
    const point = pointFrom(e);
    mark.points = mark.tool === "pen" ? [...mark.points, point] : [mark.points[0]!, point];
    redraw();
  }

  function onPointerUp() {
    const mark = drawing.current;
    drawing.current = null;
    if (mark && mark.points.length > 1) setMarks((m) => [...m, mark]);
  }

  function done() {
    const canvas = canvasRef.current;
    if (!canvas || !bitmap) return;
    setSaving(true);
    render(canvas, bitmap, marks);
    canvas.toBlob((blob) => {
      setSaving(false);
      if (blob) onDone(blob, marks.filter((m) => m.tool === "hide").length);
    }, "image/png");
  }

  return (
    <div className="seaproof-annotator" role="dialog" aria-modal="true" aria-label="Mark up the screenshot">
      <div className="seaproof-annotator-bar">
        <button type="button" className="seaproof-button seaproof-on-dark" onClick={onCancel}>
          Cancel
        </button>
        <span className="seaproof-annotator-title">Show us what you mean</span>
        <button type="button" className="seaproof-button seaproof-primary" disabled={!bitmap || saving} onClick={done}>
          Done
        </button>
      </div>
      <div className="seaproof-annotator-stage">
        <canvas
          ref={canvasRef}
          className="seaproof-annotator-canvas"
          data-tool={tool}
          aria-label="Screenshot. Drag to mark it up."
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
        />
      </div>
      <div className="seaproof-annotator-tools" role="toolbar" aria-label="Tools">
        {tools.map((t) => (
          <button key={t} type="button" aria-pressed={tool === t} onClick={() => setTool(t)}>
            {toolIcons[t]()}
            {toolLabels[t]}
          </button>
        ))}
        <button type="button" disabled={marks.length === 0} onClick={() => setMarks((m) => m.slice(0, -1))}>
          <UndoIcon />
          Undo
        </button>
      </div>
    </div>
  );
}

function render(canvas: HTMLCanvasElement, bitmap: HTMLImageElement, marks: Mark[]) {
  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(bitmap, 0, 0);
  // Lines scale with the screenshot, so they read the same on any screen.
  const width = Math.max(3, Math.round(Math.min(canvas.width, canvas.height) / 200));
  for (const mark of marks) {
    const [a, b] = [mark.points[0]!, mark.points.at(-1)!];
    ctx.lineWidth = width;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.strokeStyle = SIGNAL;
    switch (mark.tool) {
      case "hide":
        ctx.fillStyle = HIDDEN;
        ctx.fillRect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y));
        break;
      case "box":
        ctx.beginPath();
        ctx.roundRect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y), width * 2);
        ctx.stroke();
        break;
      case "arrow": {
        const angle = Math.atan2(b.y - a.y, b.x - a.x);
        const head = width * 5;
        ctx.beginPath();
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(b.x, b.y);
        ctx.moveTo(b.x - head * Math.cos(angle - Math.PI / 6), b.y - head * Math.sin(angle - Math.PI / 6));
        ctx.lineTo(b.x, b.y);
        ctx.lineTo(b.x - head * Math.cos(angle + Math.PI / 6), b.y - head * Math.sin(angle + Math.PI / 6));
        ctx.stroke();
        break;
      }
      case "pen":
        ctx.beginPath();
        mark.points.forEach((p, i) => (i === 0 ? ctx.moveTo(p.x, p.y) : ctx.lineTo(p.x, p.y)));
        ctx.stroke();
        break;
    }
  }
}
