import { Diagnostics, type OwnFeedback, type PublicIdea, type SeaproofClient } from "@seaproof/core";
import { act, cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { FeedbackWidget, SeaproofProvider, useSeaproof } from "../src";

afterEach(cleanup);

function fakeClient(submit: SeaproofClient["submit"], isTesterMode = true, extras: Partial<SeaproofClient> = {}): SeaproofClient {
  return {
    submit,
    isTesterMode,
    environment: isTesterMode ? "test" : "production",
    environmentName: isTesterMode ? "QA" : "Prod",
    diagnostics: new Diagnostics(),
    whoAmI: async () => ({ projectId: "p1", projectName: "Shop", environment: isTesterMode ? "test" : "production" }),
    start: async () => {},
    log: () => {},
    subscribe: () => () => {},
    dispose: () => {},
    myFeedback: async () => [],
    myFeedbackItem: async () => {
      throw new Error("not found");
    },
    sendMessage: async () => {
      throw new Error("not found");
    },
    ideas: async () => [],
    vote: async () => {},
    unvote: async () => {},
    hasUnreadReply: () => false,
    branding: undefined,
    identify: () => {},
    logo: async () => undefined,
    assistSettings: async () => ({ suggestions: false, followUpQuestions: false }),
    suggest: async () => [],
    review: async () => ({ questions: [], limited: false }),
    addAttachments: async () => {},
    ...extras,
  };
}

function setup(props: Parameters<typeof FeedbackWidget>[0] = {}, extras: Partial<SeaproofClient> = {}) {
  const submit = vi.fn<SeaproofClient["submit"]>(async () => ({ id: "f1", number: 42 }));
  render(
    <SeaproofProvider apiKey="sp_test" client={fakeClient(submit, true, extras)}>
      <FeedbackWidget {...props} />
    </SeaproofProvider>,
  );
  return { submit };
}

/** Writes in the composer and presses Enter, as a user would. */
function write(label: string | RegExp, text: string) {
  const box = screen.getByLabelText(label);
  fireEvent.change(box, { target: { value: text } });
  fireEvent.keyDown(box, { key: "Enter" });
}

function OpenButton() {
  const { open } = useSeaproof();
  return (
    <button type="button" onClick={open}>
      Suggest an idea
    </button>
  );
}

describe("FeedbackWidget", () => {
  it("uses the project's colour and logo from the admin", async () => {
    const createObjectURL = vi.fn(() => "blob:logo");
    const revokeObjectURL = vi.fn();
    Object.assign(URL, { createObjectURL, revokeObjectURL });
    const logo = vi.fn(async () => new Blob(["png"], { type: "image/png" }));
    render(
      <SeaproofProvider apiKey="sp_test" client={fakeClient(vi.fn(), true, { branding: { primaryColor: "#ffcc00", logo: "abc" }, logo })}>
        <FeedbackWidget />
      </SeaproofProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    const root = document.querySelector<HTMLElement>("[data-seaproof-ignore]")!;
    expect(root.style.getPropertyValue("--seaproof-brand-primary")).toBe("#ffcc00");
    // A light colour gets dark text.
    expect(root.style.getPropertyValue("--seaproof-brand-on-primary")).toBe("#111111");
    await waitFor(() => expect(document.querySelector("img.seaproof-logo")?.getAttribute("src")).toBe("blob:logo"));
    expect(logo).toHaveBeenCalledOnce();
  });

  it("saves the report with the first message, with the type and the screenshot taken on opening", async () => {
    const shot = new Blob(["png"], { type: "image/png" });
    const onSubmitted = vi.fn();
    const { submit } = setup({ screenshot: async () => shot, reporter: { name: "Tess" }, onSubmitted });
    URL.createObjectURL = () => "blob:shot";
    URL.revokeObjectURL = () => {};

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    expect(screen.getByText(/What did you find\?/)).toBeTruthy();
    expect(await screen.findByText("Screenshot")).toBeTruthy();
    fireEvent.click(screen.getByRole("radio", { name: "Idea" }));
    write("What would you like?", "  Dark mode please  ");

    expect(await screen.findByText(/the team has it as #42/)).toBeTruthy();
    expect(submit).toHaveBeenCalledWith({
      type: "idea",
      description: "Dark mode please",
      reporter: { name: "Tess" },
      attachments: [{ kind: "screenshot", file: shot, fileName: "screenshot.png" }],
      linkedTo: undefined,
    });
    expect(onSubmitted).toHaveBeenCalledWith({ id: "f1", number: 42 });
    expect(screen.getByText("Dark mode please")).toBeTruthy();

    fireEvent.click(screen.getByRole("button", { name: "Done" }));
    expect(screen.getByRole("heading", { name: "Thanks!" })).toBeTruthy();
    expect(screen.getByText("#42")).toBeTruthy();
  });

  it("sends later messages and files to the saved report", async () => {
    const sendMessage = vi.fn(async (_id: string, body: string) => ({ id: "m1", from: "you" as const, body, createdAt: "" }));
    const { submit } = setup({ screenshot: false }, { sendMessage });

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    write("What happened?", "The total is wrong");
    expect(await screen.findByText(/saved as #42/)).toBeTruthy();

    write("Add to your report", "It says 1240, step 1 said 990");
    expect(await screen.findByText("Added to #42.")).toBeTruthy();
    expect(sendMessage).toHaveBeenCalledWith("f1", "It says 1240, step 1 said 990");
    expect(submit).toHaveBeenCalledOnce();
  });

  it("can send without the screenshot", async () => {
    URL.createObjectURL = () => "blob:shot";
    URL.revokeObjectURL = () => {};
    const { submit } = setup({ screenshot: async () => new Blob(["png"], { type: "image/png" }) });

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    fireEvent.click(await screen.findByRole("button", { name: "Remove the screenshot" }));
    write("What happened?", "Typo on start page");

    await waitFor(() => expect(submit).toHaveBeenCalled());
    expect(submit.mock.calls[0]![0].attachments).toEqual([]);
  });

  it("shows the API's message when saving fails and keeps the text", async () => {
    const submit = vi.fn(async () => {
      throw new Error("A description of 1-10000 characters is required.");
    });
    render(
      <SeaproofProvider apiKey="sp_test" client={fakeClient(submit)}>
        <FeedbackWidget screenshot={false} />
      </SeaproofProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    write("What happened?", "x");

    expect((await screen.findByRole("alert")).textContent).toContain("1-10000 characters");
    expect((screen.getByLabelText("What happened?") as HTMLTextAreaElement).value).toBe("x");
    expect(screen.queryByText(/saved as/)).toBeNull();
  });

  it("hides the launcher in production; the app opens the widget itself", async () => {
    const submit = vi.fn<SeaproofClient["submit"]>(async () => ({ id: "f1", number: 1 }));
    render(
      <SeaproofProvider apiKey="sp_test" client={fakeClient(submit, false)}>
        <OpenButton />
        <FeedbackWidget screenshot={false} />
      </SeaproofProvider>,
    );

    expect(screen.queryByRole("button", { name: "Feedback" })).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "Suggest an idea" }));
    expect((screen.getByRole("radio", { name: "Feedback" }) as HTMLInputElement).checked).toBe(true);
    // Production puts ideas and feedback before bug reports.
    expect(screen.getAllByRole("radio").map((r) => r.getAttribute("value"))).toEqual(["idea", "feedback", "bug", "question"]);
  });

  it("explains what is missing instead of sending an empty report", async () => {
    const { submit } = setup({ screenshot: false });
    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    fireEvent.click(screen.getByRole("button", { name: "Send" }));

    expect(await screen.findByText(/Please write a few words/)).toBeTruthy();
    expect(screen.getByLabelText("What happened?").getAttribute("aria-invalid")).toBe("true");
    expect(submit).not.toHaveBeenCalled();
  });

  it("marks the launcher as a test build and can follow a dark colour scheme", () => {
    setup({ screenshot: false, colorScheme: "dark" });
    expect(screen.getByRole("button", { name: "Feedback" }).textContent).toContain("TEST");
    expect(document.querySelector(".seaproof-root")?.getAttribute("data-seaproof-theme")).toBe("dark");
  });

  it("closes on Escape, keeping an unsent draft but ending a saved conversation", async () => {
    setup({ screenshot: false });
    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    fireEvent.change(screen.getByLabelText("What happened?"), { target: { value: "Half a thought" } });

    fireEvent.keyDown(window, { key: "Escape" });
    expect(screen.queryByRole("dialog")).toBeNull();

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    expect((screen.getByLabelText("What happened?") as HTMLTextAreaElement).value).toBe("Half a thought");
    fireEvent.keyDown(screen.getByLabelText("What happened?"), { key: "Enter" });
    expect(await screen.findByText(/saved as #42/)).toBeTruthy();

    fireEvent.keyDown(window, { key: "Escape" });
    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    expect(screen.queryByText(/saved as #42/)).toBeNull();
    expect((screen.getByLabelText("What happened?") as HTMLTextAreaElement).value).toBe("");
  });

  it("shows testers which environment they are in", () => {
    setup({ screenshot: false });
    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    expect(document.querySelector(".seaproof-test-strip")?.textContent).toBe("Test modeQA");
  });

  it("opens the screenshot for marking up from the composer", async () => {
    URL.createObjectURL = () => "blob:shot";
    URL.revokeObjectURL = () => {};
    setup({ screenshot: async () => new Blob(["png"], { type: "image/png" }) });
    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));

    fireEvent.click(await screen.findByRole("button", { name: "Mark up the screenshot" }));
    expect(screen.getByRole("dialog", { name: "Mark up the screenshot" })).toBeTruthy();
    expect(screen.getAllByRole("button", { pressed: true }).map((b) => b.textContent)).toEqual(["Circle"]);

    fireEvent.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.getByRole("dialog", { name: "Send feedback" })).toBeTruthy();
  });

  it("shows no tabs until there is something besides the form", async () => {
    setup({ screenshot: false });
    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    await waitFor(() => expect(screen.getByRole("dialog")).toBeTruthy());
    expect(screen.queryByRole("tablist")).toBeNull();
  });

  it("lets the user vote on published ideas, and take the vote back", async () => {
    const idea: PublicIdea = {
      id: "i1",
      title: "Dark mode",
      summary: "A dark theme",
      status: "inProgress",
      votes: 4,
      voted: false,
      createdAt: "2026-10-21T10:00:00Z",
    };
    const vote = vi.fn(async () => {});
    const unvote = vi.fn(async () => {});
    render(
      <SeaproofProvider apiKey="sp_test" client={fakeClient(vi.fn(), false, { ideas: async () => [idea], vote, unvote })}>
        <OpenButton />
        <FeedbackWidget screenshot={false} />
      </SeaproofProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "Suggest an idea" }));
    fireEvent.click(await screen.findByRole("tab", { name: "Ideas" }));
    expect(screen.getByText("A dark theme")).toBeTruthy();
    expect(screen.getByText("In progress")).toBeTruthy();

    fireEvent.click(screen.getByRole("button", { name: "Vote for Dark mode, 4 votes" }));
    expect(await screen.findByRole("button", { name: "Remove vote for Dark mode, 5 votes" })).toBeTruthy();
    expect(vote).toHaveBeenCalledWith("i1");

    fireEvent.click(screen.getByRole("button", { name: "Remove vote for Dark mode, 5 votes" }));
    expect(await screen.findByRole("button", { name: "Vote for Dark mode, 4 votes" })).toBeTruthy();
    expect(unvote).toHaveBeenCalledWith("i1");
  });

  it("shows the team's reply to the user's own feedback and sends an answer", async () => {
    const item: OwnFeedback = {
      id: "f1",
      number: 3,
      type: "bug",
      title: "Cart is empty",
      status: "inProgress",
      replies: 1,
      createdAt: "2026-10-20T10:00:00Z",
      lastReplyAt: "2026-10-21T10:00:00Z",
    };
    const sendMessage = vi.fn(async (_id: string, body: string) => ({
      id: "m2",
      from: "you" as const,
      body,
      createdAt: "2026-10-21T11:00:00Z",
    }));
    const client = fakeClient(vi.fn(), false, {
      myFeedback: async () => [item],
      hasUnreadReply: () => true,
      myFeedbackItem: async () => ({
        ...item,
        description: "Cart is empty after login",
        messages: [{ id: "m1", from: "team", body: "Fixed in 2.1, can you update?", createdAt: "2026-10-21T10:00:00Z" }],
      }),
      sendMessage,
    });
    render(
      <SeaproofProvider apiKey="sp_test" client={client}>
        <OpenButton />
        <FeedbackWidget screenshot={false} />
      </SeaproofProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "Suggest an idea" }));
    const tab = await screen.findByRole("tab", { name: /Your feedback/ });
    expect(screen.getAllByLabelText("New reply").length).toBeGreaterThan(0);
    fireEvent.click(tab);
    fireEvent.click(screen.getByRole("button", { name: /Cart is empty/ }));

    expect(await screen.findByText("Fixed in 2.1, can you update?")).toBeTruthy();
    fireEvent.change(screen.getByLabelText("Reply"), { target: { value: "Works now, thanks!" } });
    fireEvent.click(screen.getByRole("button", { name: "Send" }));

    expect(await screen.findByText("Works now, thanks!")).toBeTruthy();
    expect(sendMessage).toHaveBeenCalledWith("f1", "Works now, thanks!");
  });
});

describe("screen recording", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("hides the dialog while recording, then attaches the video to the first message", async () => {
    const track = Object.assign(new EventTarget(), { stop: vi.fn() });
    const stream = { getVideoTracks: () => [track], getTracks: () => [track] };
    class FakeRecorder {
      static isTypeSupported = () => true;
      state = "inactive";
      mimeType = "video/webm;codecs=vp9";
      ondataavailable: ((e: { data: Blob }) => void) | null = null;
      onstop: (() => void) | null = null;
      start() {
        this.state = "recording";
      }
      stop() {
        this.state = "inactive";
        this.ondataavailable?.({ data: new Blob(["video"], { type: "video/webm" }) });
        setTimeout(() => this.onstop?.());
      }
    }
    vi.stubGlobal("MediaRecorder", FakeRecorder);
    Object.defineProperty(navigator, "mediaDevices", { value: { getDisplayMedia: async () => stream }, configurable: true });
    URL.createObjectURL = () => "blob:recording";
    URL.revokeObjectURL = () => {};

    const { submit } = setup({ screenshot: false });
    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    fireEvent.click(screen.getByRole("button", { name: "Record the screen" }));

    const bar = await screen.findByRole("status");
    expect(bar.textContent).toContain("Recording");
    expect(screen.queryByRole("dialog")).toBeNull();

    fireEvent.click(screen.getByRole("button", { name: "Stop" }));
    expect(await screen.findByText(/Screen recording, 0:0\d/)).toBeTruthy();
    expect(track.stop).toHaveBeenCalled();

    write("What happened?", "Menu flickers");
    await waitFor(() => expect(submit).toHaveBeenCalled());
    const attachment = submit.mock.calls[0]![0].attachments![0]!;
    expect(attachment.kind).toBe("recording");
    expect(attachment.fileName).toBe("recording.webm");
    expect(attachment.file.type).toBe("video/webm");
  });

  it("is not offered in production unless the app asks for it", async () => {
    vi.stubGlobal("MediaRecorder", class {});
    Object.defineProperty(navigator, "mediaDevices", { value: { getDisplayMedia: async () => ({}) }, configurable: true });
    render(
      <SeaproofProvider apiKey="sp_test" client={fakeClient(vi.fn(), false)}>
        <OpenButton />
        <FeedbackWidget screenshot={false} />
      </SeaproofProvider>,
    );
    fireEvent.click(screen.getByRole("button", { name: "Suggest an idea" }));
    expect(screen.queryByRole("button", { name: "Record the screen" })).toBeNull();
  });
  it("suggests known problems while the user writes, and saves a report linked to one", async () => {
    const submit = vi.fn<SeaproofClient["submit"]>(async () => ({ id: "f1", number: 7 }));
    const suggest = vi.fn<SeaproofClient["suggest"]>(async () => [
      { id: "k1", type: "bug", title: "Signing in can crash the app", summary: "We are on it.", status: "inProgress", votes: 0 },
      { id: "i1", type: "idea", title: "Dark mode", summary: null, status: "received", votes: 4 },
    ]);
    const vote = vi.fn(async () => {});
    render(
      <SeaproofProvider
        apiKey="sp_test"
        client={fakeClient(submit, true, { assistSettings: async () => ({ suggestions: true, followUpQuestions: false }), suggest, vote })}
      >
        <FeedbackWidget screenshot={false} />
      </SeaproofProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    await new Promise((r) => setTimeout(r, 0));
    fireEvent.change(screen.getByLabelText("What happened?"), { target: { value: "Crash" } });
    fireEvent.change(screen.getByLabelText("What happened?"), { target: { value: "The app crashes when I sign in" } });

    expect(await screen.findByText("Signing in can crash the app")).toBeTruthy();
    expect(suggest).toHaveBeenCalledOnce();
    expect(suggest).toHaveBeenCalledWith("The app crashes when I sign in", "bug");
    expect(screen.getByText("In progress")).toBeTruthy();

    fireEvent.click(screen.getByRole("button", { name: "Vote for Dark mode" }));
    await waitFor(() => expect(vote).toHaveBeenCalledWith("i1"));

    fireEvent.click(screen.getByRole("button", { name: "Same for me" }));
    expect(await screen.findByText(/linked to the problem the team already knows about \(#7\)/)).toBeTruthy();
    expect(submit.mock.calls[0]![0]).toMatchObject({ description: "The app crashes when I sign in", linkedTo: "k1" });
    expect(screen.queryByText("Signing in can crash the app")).toBeNull();
  });

  it("saves first, then asks Assist's questions one at a time and adds the answers", async () => {
    const submit = vi.fn<SeaproofClient["submit"]>(async () => ({ id: "f1", number: 8 }));
    const questions = [
      "What did you expect to happen?",
      "Which page were you on?",
      "How did you get there?",
      "What did the button do instead?",
      "Does it happen every time?",
      "Did you see an error message?",
    ];
    const questionReceipts = questions.map((_, i) => `receipt-${i}`);
    const review = vi.fn<SeaproofClient["review"]>(async () => ({ questions, questionReceipts, limited: false }));
    const recordAssistQuestion = vi.fn(async (_id: string, _receipt: string) => true);
    const sendMessage = vi.fn(async (_id: string, body: string) => ({ id: "m1", from: "you" as const, body, createdAt: "" }));
    render(
      <SeaproofProvider
        apiKey="sp_test"
        client={fakeClient(submit, true, {
          assistSettings: async () => ({ suggestions: false, followUpQuestions: true }),
          review,
          recordAssistQuestion,
          sendMessage,
        })}
      >
        <FeedbackWidget screenshot={false} />
      </SeaproofProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    await new Promise((r) => setTimeout(r, 0));
    write("What happened?", "The button does nothing");

    expect(await screen.findByText("Thanks, it is saved as #8. What did you expect to happen?")).toBeTruthy();
    expect(submit).toHaveBeenCalledOnce();
    expect(review).toHaveBeenCalledWith("bug", "The button does nothing", expect.stringMatching(/^[0-9a-f]{8}-[0-9a-f]{4}-4/), "f1");
    expect(recordAssistQuestion.mock.calls).toEqual([["f1", questionReceipts[0]]]);

    const answers = ["To go to checkout", "The cart", "I added a product", "Nothing", "Yes"];
    for (const [index, answer] of answers.entries()) {
      write("Add to your report", answer);
      if (index + 1 < answers.length) {
        expect(await screen.findByText(questions[index + 1]!)).toBeTruthy();
        expect(screen.queryByText(questions[index + 2]!)).toBeNull();
      }
    }
    expect(await screen.findByText("Added to #8.")).toBeTruthy();
    expect(screen.queryByText(questions[5]!)).toBeNull();
    expect(sendMessage.mock.calls.map((c) => c[1])).toEqual(answers);
    expect(recordAssistQuestion.mock.calls).toEqual(questionReceipts.slice(0, 5).map((receipt) => ["f1", receipt]));
    for (let index = 0; index < answers.length - 1; index++) {
      expect(sendMessage.mock.invocationCallOrder[index]!).toBeLessThan(recordAssistQuestion.mock.invocationCallOrder[index + 1]!);
    }
    expect(review).toHaveBeenCalledOnce();
  });

  it("ignores an Assist review that finishes after the reporter closes the conversation", async () => {
    type Result = Awaited<ReturnType<SeaproofClient["review"]>>;
    let finishReview!: (result: Result) => void;
    const pendingReview = new Promise<Result>((resolve) => { finishReview = resolve; });
    const review = vi.fn(() => pendingReview);
    const recordAssistQuestion = vi.fn(async () => true);
    setup({ screenshot: false }, {
      assistSettings: async () => ({ suggestions: false, followUpQuestions: true }),
      review,
      recordAssistQuestion,
    });

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    await act(async () => {});
    write("What happened?", "The first report");
    await waitFor(() => expect(review).toHaveBeenCalledOnce());

    fireEvent.click(screen.getByRole("button", { name: "Close" }));
    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    await act(async () => finishReview({
      questions: ["Where did that happen?"],
      questionReceipts: ["receipt"],
      limited: false,
    }));

    expect(screen.queryByText(/Where did that happen/)).toBeNull();
    expect(recordAssistQuestion).not.toHaveBeenCalled();
    expect((screen.getByRole("textbox", { name: "What happened?" }) as HTMLTextAreaElement).disabled).toBe(false);
  });

  it("still saves the report when Assist has nothing to ask or the quota is used up", async () => {
    const review = vi.fn<SeaproofClient["review"]>(async () => ({ questions: [], limited: true }));
    const { submit } = setup({ screenshot: false }, { assistSettings: async () => ({ suggestions: false, followUpQuestions: true }), review });

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    await new Promise((r) => setTimeout(r, 0));
    write("What happened?", "The button does nothing");

    expect(await screen.findByText("Thanks, it is saved as #42. Anything to add? Otherwise you are done.")).toBeTruthy();
    expect(submit).toHaveBeenCalledOnce();
  });

  it("keeps a saved report when the app's onSubmitted throws, so it is never sent twice", async () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const { submit } = setup({
      screenshot: false,
      onSubmitted: () => {
        throw new Error("app bug");
      },
    });

    fireEvent.click(screen.getByRole("button", { name: "Feedback" }));
    write("What happened?", "The button does nothing");

    expect(await screen.findByText("Thanks, it is saved as #42. Anything to add? Otherwise you are done.")).toBeTruthy();
    expect(screen.getByLabelText("Add to your report")).toBeTruthy();
    write("Add to your report", "More");
    await waitFor(() => expect(warn).toHaveBeenCalled());
    expect(submit).toHaveBeenCalledOnce();
    warn.mockRestore();
  });
});
