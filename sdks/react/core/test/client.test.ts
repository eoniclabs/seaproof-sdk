import { describe, expect, it, vi } from "vitest";
import { createSeaproof, SeaproofError } from "../src";

const apiKey = "sp_" + "a".repeat(43);

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function memoryStorage() {
  const values = new Map<string, string>();
  return { getItem: (k: string) => values.get(k) ?? null, setItem: (k: string, v: string) => void values.set(k, v) };
}

describe("createSeaproof", () => {
  it("refuses a key that is not a project key", () => {
    expect(() => createSeaproof({ apiKey: "secret" })).toThrow(/sp_/);
  });

  it("reads the project's launcher independently of its branding", async () => {
    const launcher = { position: "middle-left", label: "Report a bug", orientation: "vertical", avoidObstructions: true };
    const fetch = vi.fn(async () => json(200, {
      projectId: "p1", projectName: "Shop", mode: "test", launcher,
    }));
    const client = createSeaproof({ apiKey, branding: false, fetch: fetch as unknown as typeof globalThis.fetch });

    expect(client.launcher).toBeUndefined();
    await client.start();
    expect(client.launcher).toEqual(launcher);
  });

  it("submits feedback, uploads each file to its presigned URL and marks it uploaded", async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const fetch = vi.fn(async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      if (url.endsWith("/api/v1/sdk/feedback")) {
        return json(201, {
          id: "f1",
          number: 7,
          uploads: [{ attachmentId: "a1", method: "PUT", url: "https://storage.test/put-a1", headers: { "Content-Type": "image/png" } }],
        });
      }
      return new Response(null, { status: url.startsWith("https://storage.test") ? 200 : 204 });
    });

    const client = createSeaproof({
      apiKey,
      endpoint: "https://api.test/",
      appVersion: "1.2.3",
      commit: "9f2c1ab",
      reporter: { name: "Tess" },
      context: () => ({ custom: { flag: "on" } }),
      fetch: fetch as unknown as typeof globalThis.fetch,
    });
    const screenshot = new Blob(["png"], { type: "image/png" });

    const result = await client.submit({ description: "It broke", attachments: [{ kind: "screenshot", file: screenshot }] });

    expect(result).toEqual({ id: "f1", number: 7 });
    expect(calls.map((c) => c.url)).toEqual([
      "https://api.test/api/v1/sdk/feedback",
      "https://storage.test/put-a1",
      "https://api.test/api/v1/sdk/feedback/f1/attachments/a1/uploaded",
    ]);

    const submitted = JSON.parse(calls[0]!.init.body as string);
    expect((calls[0]!.init.headers as Record<string, string>)["X-Seaproof-Key"]).toBe(apiKey);
    expect(submitted.reporter).toEqual({ name: "Tess" });
    expect(submitted.context).toMatchObject({ platform: "web", appVersion: "1.2.3", commit: "9f2c1ab", custom: { flag: "on" } });
    expect(submitted.attachments).toEqual([{ kind: "screenshot", contentType: "image/png", sizeBytes: 3 }]);
    expect(calls[1]!.init.body).toBe(screenshot);
  });

  it("adds files to an item it already sent", async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const fetch = vi.fn(async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      if (url.endsWith("/me/feedback/f1/attachments")) {
        return json(200, { uploads: [{ attachmentId: "a2", method: "PUT", url: "https://storage.test/put-a2", headers: {} }] });
      }
      return new Response(null, { status: url.startsWith("https://storage.test") ? 200 : 204 });
    });
    const client = createSeaproof({ apiKey, endpoint: "https://api.test", fetch: fetch as unknown as typeof globalThis.fetch });
    const marked = new Blob(["png"], { type: "image/png" });

    await client.addAttachments("f1", [{ kind: "screenshot", file: marked, fileName: "marked.png" }]);

    expect(calls.map((c) => c.url)).toEqual([
      "https://api.test/api/v1/sdk/me/feedback/f1/attachments",
      "https://storage.test/put-a2",
      "https://api.test/api/v1/sdk/feedback/f1/attachments/a2/uploaded",
    ]);
    expect(JSON.parse(calls[0]!.init.body as string)).toEqual({
      attachments: [{ kind: "screenshot", fileName: "marked.png", contentType: "image/png", sizeBytes: 3 }],
    });
    expect(calls[1]!.init.body).toBe(marked);
  });

  it("turns Problem Details into a SeaproofError with the API's code", async () => {
    const fetch = vi.fn(async () => json(400, { code: "feedback.description_invalid", detail: "A description is required." }));
    const client = createSeaproof({ apiKey, fetch: fetch as unknown as typeof globalThis.fetch });

    const error = await client.submit({ description: "" }).catch((e: unknown) => e);

    expect(error).toBeInstanceOf(SeaproofError);
    expect(error).toMatchObject({
      status: 400,
      code: "feedback.description_invalid",
      message: "A description is required.",
      helpUrl: "https://seaproof.io/docs/errors#feedback.description_invalid",
    });
  });

  it("tells the developer how to fix a rejected key", async () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetch = vi.fn(async () =>
      json(401, { code: "sdk.key_invalid", title: "This API key is unknown or revoked.", type: "https://seaproof.io/docs/errors#sdk.key_invalid" }),
    );
    const client = createSeaproof({ apiKey, fetch: fetch as unknown as typeof globalThis.fetch });

    await client.start();

    expect(warn).toHaveBeenCalledWith(
      "Seaproof: could not fetch the project for the API key. This API key is unknown or revoked. (sdk.key_invalid). How to fix: https://seaproof.io/docs/errors#sdk.key_invalid",
    );
    warn.mockRestore();
  });

  it("sends a verified user with every call after identify, and keeps the hash out of the report", async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const fetch = vi.fn(async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      return url.endsWith("/api/v1/sdk/feedback") ? json(201, { id: "f1", number: 1, uploads: [] }) : json(200, []);
    });
    const client = createSeaproof({ apiKey, endpoint: "https://api.test", fetch: fetch as unknown as typeof globalThis.fetch, storage: memoryStorage() });
    const headers = (i: number) => calls[i]!.init.headers as Record<string, string>;

    client.identify({ externalId: "kim" });
    await client.myFeedback();
    client.identify({ externalId: "kim@shop.example", name: "Kim", userHash: "abc123" });
    await client.myFeedback();
    await client.submit({ description: "Hi" });
    client.identify(null);
    await client.ideas();

    expect(headers(0)["X-Seaproof-User"]).toBeUndefined();
    expect(headers(1)["X-Seaproof-User"]).toBe("kim%40shop.example");
    expect(headers(1)["X-Seaproof-User-Hash"]).toBe("abc123");
    expect(headers(2)["X-Seaproof-User-Hash"]).toBe("abc123");
    const body = JSON.parse(calls[2]!.init.body as string) as { reporter: Record<string, unknown> };
    expect(body.reporter).toEqual({ externalId: "kim@shop.example", name: "Kim" });
    expect(headers(3)["X-Seaproof-User"]).toBeUndefined();
  });
  it("asks Assist for settings, suggestions and follow-up questions, and degrades quietly when it is off", async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const fetch = vi.fn(async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      if (url.endsWith("/api/v1/sdk/assist")) return json(200, { suggestions: true, followUpQuestions: true });
      if (url.endsWith("/suggestions")) return json(200, [{ id: "k1", type: "bug", title: "Login crash", summary: null, status: "inProgress", votes: 0 }]);
      if (url.endsWith("/review")) return json(404, { code: "assist.not_enabled" });
      return json(201, { id: "f1", number: 1, uploads: [] });
    });
    const client = createSeaproof({ apiKey, endpoint: "https://api.test", fetch: fetch as unknown as typeof globalThis.fetch, storage: memoryStorage() });

    expect(await client.assistSettings()).toEqual({ suggestions: true, followUpQuestions: true });
    expect((await client.suggest("The app crashes at login", "bug")).map((s) => s.id)).toEqual(["k1"]);
    expect(JSON.parse(calls[1]!.init.body as string)).toEqual({ text: "The app crashes at login", type: "bug" });
    expect(await client.review("bug", "Crash")).toEqual({ questions: [], limited: false });

    await client.submit({ type: "bug", description: "Same here", linkedTo: "k1" });
    expect(JSON.parse(calls.at(-1)!.init.body as string).linkedTo).toBe("k1");
  });
});
