export interface ScreenRecording {
  file: Blob;
  fileName: string;
  durationMs: number;
}

export interface RecorderOptions {
  /** Stops by itself after this long. Default 60 seconds. */
  maxDurationMs?: number;
  /** Frames per second asked of the browser. Default 15; UI bugs rarely need more. */
  frameRate?: number;
  /** Called when recording stops for any reason, including the browser's own "Stop sharing". */
  onStop?: (recording: ScreenRecording) => void;
}

// Best first: VP9 keeps text sharp at low bitrates; Safari only records MP4.
const mimeTypes = ["video/webm;codecs=vp9", "video/webm;codecs=vp8", "video/webm", "video/mp4"];

/** Whether this browser can record the screen. False on most mobile browsers. */
export function canRecordScreen(): boolean {
  return (
    typeof navigator !== "undefined" &&
    typeof navigator.mediaDevices?.getDisplayMedia === "function" &&
    typeof MediaRecorder !== "undefined"
  );
}

/**
 * Records the screen, window or tab the user picks in the browser's own dialog. Nothing is
 * captured without that choice, and the browser shows that sharing is on.
 *
 * Unlike screenshots, a recording cannot leave out `data-seaproof-mask` elements: it shows
 * whatever is on the shared surface.
 */
export class ScreenRecorder {
  private stream: MediaStream | undefined;
  private recorder: MediaRecorder | undefined;
  private chunks: Blob[] = [];
  private startedAt = 0;
  private timer: ReturnType<typeof setTimeout> | undefined;
  private stopped: Promise<ScreenRecording> | undefined;

  constructor(private readonly options: RecorderOptions = {}) {}

  get isRecording(): boolean {
    return this.recorder?.state === "recording";
  }

  /** Asks the user what to share and starts recording. Rejects if they cancel. */
  async start(): Promise<void> {
    if (!canRecordScreen()) throw new Error("Seaproof: this browser cannot record the screen.");
    if (this.recorder) throw new Error("Seaproof: a recording is already running.");

    const frameRate = this.options.frameRate ?? 15;
    // preferCurrentTab and selfBrowserSurface are hints Chromium understands; others ignore them.
    const stream = await navigator.mediaDevices.getDisplayMedia({
      video: { frameRate },
      audio: false,
      preferCurrentTab: true,
      selfBrowserSurface: "include",
    } as DisplayMediaStreamOptions);
    const mimeType = mimeTypes.find((t) => MediaRecorder.isTypeSupported(t));
    const recorder = new MediaRecorder(stream, { mimeType, videoBitsPerSecond: 2_500_000 });
    this.stream = stream;
    this.recorder = recorder;
    this.chunks = [];
    this.startedAt = performance.now();

    this.stopped = new Promise((resolve) => {
      recorder.ondataavailable = (e) => e.data.size > 0 && this.chunks.push(e.data);
      recorder.onstop = () => {
        const type = recorder.mimeType || mimeType || "video/webm";
        const recording: ScreenRecording = {
          file: new Blob(this.chunks, { type: type.split(";")[0] }),
          fileName: type.includes("mp4") ? "recording.mp4" : "recording.webm",
          durationMs: Math.round(performance.now() - this.startedAt),
        };
        this.cleanUp();
        this.options.onStop?.(recording);
        resolve(recording);
      };
    });

    // The browser's "Stop sharing" button ends the track, not the recorder.
    for (const track of stream.getVideoTracks()) track.addEventListener("ended", () => this.stopRecorder());
    this.timer = setTimeout(() => this.stopRecorder(), this.options.maxDurationMs ?? 60_000);
    recorder.start(1000);
  }

  /** Stops and returns the recording. */
  stop(): Promise<ScreenRecording> {
    const stopped = this.stopped;
    if (!stopped) return Promise.reject(new Error("Seaproof: no recording is running."));
    this.stopRecorder();
    return stopped;
  }

  /** Milliseconds since the recording started. */
  elapsedMs(): number {
    return this.recorder ? Math.round(performance.now() - this.startedAt) : 0;
  }

  private stopRecorder() {
    if (this.recorder && this.recorder.state !== "inactive") this.recorder.stop();
  }

  private cleanUp() {
    clearTimeout(this.timer);
    for (const track of this.stream?.getTracks() ?? []) track.stop();
    this.stream = undefined;
    this.recorder = undefined;
    this.stopped = undefined;
  }
}
