import { cleanup, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { FeedbackLauncher } from "../src/FeedbackLauncher";

const config = { position: "bottom-right", label: "Report a bug", orientation: "vertical", avoidObstructions: true } as const;
const onOpen = () => {};

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  Reflect.deleteProperty(document.documentElement, "clientWidth");
  Reflect.deleteProperty(document.documentElement, "clientHeight");
});

describe("the configured feedback button", () => {
  it("uses the project label, orientation and placement", () => {
    render(<FeedbackLauncher config={{ ...config, avoidObstructions: false }} tester={false} unread={false} onOpen={onOpen} />);

    const button = screen.getByRole("button", { name: "Report a bug" });
    expect(button.dataset.orientation).toBe("vertical");
    expect(button.dataset.position).toBe("bottom-right");
  });

  it("moves away from a marked control and returns when the spot is clear", async () => {
    Object.defineProperty(document.documentElement, "clientWidth", { configurable: true, value: 800 });
    Object.defineProperty(document.documentElement, "clientHeight", { configurable: true, value: 600 });
    vi.spyOn(HTMLElement.prototype, "getBoundingClientRect").mockImplementation(function (this: HTMLElement) {
      return this.hasAttribute("data-seaproof-avoid") ? new DOMRect(690, 480, 110, 120) : new DOMRect(0, 0, 44, 128);
    });

    const launcher = <FeedbackLauncher config={config} tester={false} unread={false} onOpen={onOpen} />;
    const { rerender } = render(<>{launcher}</>);
    const button = screen.getByRole("button", { name: "Report a bug" });
    expect(button.dataset.position).toBe("bottom-right");

    rerender(<>{launcher}<div data-seaproof-avoid="" style={{ visibility: "visible" }}>Help</div></>);
    await waitFor(() => expect(button.dataset.position).toBe("middle-right"));

    rerender(<>{launcher}</>);
    await waitFor(() => expect(button.dataset.position).toBe("bottom-right"));
  });
});
