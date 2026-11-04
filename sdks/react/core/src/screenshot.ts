import { toBlob } from "html-to-image";

/** Whether a node is left out of screenshots: the widget itself, masked elements and password fields. */
export function excludedFromScreenshot(node: Node): boolean {
  if (!(node instanceof HTMLElement)) return false;
  if (node.dataset.seaproofIgnore !== undefined || node.dataset.seaproofMask !== undefined) return true;
  return node instanceof HTMLInputElement && node.type === "password";
}

/**
 * Captures the page (or one element) as a PNG. Mark the feedback UI with `data-seaproof-ignore`
 * and anything personal with `data-seaproof-mask`; both are left out, so their content never
 * leaves the browser. Password fields are always left out.
 */
export async function captureScreenshot(element: HTMLElement = document.body): Promise<Blob> {
  const blob = await toBlob(element, {
    cacheBust: true,
    pixelRatio: Math.min(window.devicePixelRatio || 1, 2),
    filter: (node) => !excludedFromScreenshot(node),
  });
  if (!blob) {
    throw new Error("Seaproof: the screenshot could not be captured.");
  }
  return blob;
}
