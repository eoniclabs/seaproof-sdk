import { describe, expect, it } from "vitest";
import { excludedFromScreenshot } from "../src";

describe("excludedFromScreenshot", () => {
  it("leaves out the widget, masked elements and password fields", () => {
    const widget = document.createElement("div");
    widget.dataset.seaproofIgnore = "";
    const masked = document.createElement("span");
    masked.dataset.seaproofMask = "";
    const password = document.createElement("input");
    password.type = "password";
    const text = document.createElement("input");

    expect(excludedFromScreenshot(widget)).toBe(true);
    expect(excludedFromScreenshot(masked)).toBe(true);
    expect(excludedFromScreenshot(password)).toBe(true);
    expect(excludedFromScreenshot(text)).toBe(false);
    expect(excludedFromScreenshot(document.createTextNode("x"))).toBe(false);
  });
});
