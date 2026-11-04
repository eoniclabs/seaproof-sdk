import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { canRecordScreen, ScreenRecorder } from "../src/recorder";

class FakeTrack extends EventTarget {
  stopped = false;
  stop() {
    this.stopped = true;
  }
}

class FakeRecorder {
  static instances: FakeRecorder[] = [];
  static isTypeSupported = (type: string) => type === "video/webm;codecs=vp8";
  state: "inactive" | "recording" = "inactive";
  ondataavailable: ((e: { data: Blob }) => void) | null = null;
  onstop: (() => void) | null = null;
  constructor(
    readonly stream: unknown,
    readonly options: { mimeType?: string },
  ) {
    FakeRecorder.instances.push(this);
  }
  get mimeType() {
    return this.options.mimeType ?? "";
  }
  start() {
    this.state = "recording";
  }
  stop() {
    this.state = "inactive";
    this.ondataavailable?.({ data: new Blob(["frame"], { type: "video/webm" }) });
    queueMicrotask(() => this.onstop?.());
  }
}

let track: FakeTrack;
let getDisplayMedia: ReturnType<typeof vi.fn>;

beforeEach(() => {
  track = new FakeTrack();
  getDisplayMedia = vi.fn(async () => ({ getVideoTracks: () => [track], getTracks: () => [track] }));
  vi.stubGlobal("MediaRecorder", FakeRecorder);
  Object.defineProperty(navigator, "mediaDevices", { value: { getDisplayMedia }, configurable: true });
  FakeRecorder.instances = [];
});

afterEach(() => {
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe("ScreenRecorder", () => {
  it("records what the user shares and stops sharing afterwards", async () => {
    expect(canRecordScreen()).toBe(true);
    const recorder = new ScreenRecorder();

    await recorder.start();
    expect(recorder.isRecording).toBe(true);
    expect(getDisplayMedia).toHaveBeenCalledWith(expect.objectContaining({ audio: false }));
    const recording = await recorder.stop();

    expect(recording.fileName).toBe("recording.webm");
    expect(recording.file.type).toBe("video/webm");
    expect(recording.file.size).toBeGreaterThan(0);
    expect(track.stopped).toBe(true);
    expect(recorder.isRecording).toBe(false);
  });

  it("stops when the user ends sharing in the browser, or at the time limit", async () => {
    const onStop = vi.fn();
    const recorder = new ScreenRecorder({ onStop });
    await recorder.start();
    track.dispatchEvent(new Event("ended"));
    await vi.waitFor(() => expect(onStop).toHaveBeenCalledTimes(1));

    vi.useFakeTimers();
    const limited = new ScreenRecorder({ maxDurationMs: 5_000, onStop });
    await limited.start();
    vi.advanceTimersByTime(5_000);
    await vi.waitFor(() => expect(onStop).toHaveBeenCalledTimes(2));
  });

  it("rejects when the user cancels the browser's picker", async () => {
    getDisplayMedia.mockRejectedValueOnce(new DOMException("denied", "NotAllowedError"));
    const recorder = new ScreenRecorder();
    await expect(recorder.start()).rejects.toThrow("denied");
    expect(recorder.isRecording).toBe(false);
  });
});
