import { describe, expect, it, vi } from "vitest";
import { createSeaproof, type KeyValueStorage } from "../src";

const apiKey = "sp_" + "a".repeat(43);

function memory(): KeyValueStorage & { data: Map<string, string> } {
  const data = new Map<string, string>();
  return { data, getItem: (k) => data.get(k) ?? null, setItem: (k, v) => void data.set(k, v) };
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

describe("reporter identity", () => {
  it("sends the same random reporter key on every call, kept across page loads", async () => {
    const storage = memory();
    const keys: string[] = [];
    const fetch = vi.fn(async (_url: string, init: RequestInit) => {
      keys.push((init.headers as Record<string, string>)["X-Seaproof-Reporter"]!);
      return json(200, []);
    }) as unknown as typeof globalThis.fetch;

    await createSeaproof({ apiKey, fetch, storage, diagnostics: false }).myFeedback();
    await createSeaproof({ apiKey, fetch, storage, diagnostics: false }).ideas();
    await createSeaproof({ apiKey, fetch, storage: memory(), diagnostics: false }).ideas();

    expect(keys[0]).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(keys[1]).toBe(keys[0]);
    expect(keys[2]).not.toBe(keys[0]);
  });

  it("marks a reply unread until the conversation is opened", async () => {
    const reply = { id: "m1", from: "team", body: "Fixed in 2.1", createdAt: "2026-10-21T10:00:00Z" };
    const fetch = vi.fn(async (url: string) =>
      url.endsWith("/me/feedback")
        ? json(200, [{ id: "f1", number: 1, type: "bug", title: "Crash", status: "done", replies: 1, createdAt: "2026-10-20T10:00:00Z", lastReplyAt: reply.createdAt }])
        : json(200, { id: "f1", number: 1, type: "bug", title: "Crash", description: "Crash", status: "done", createdAt: "2026-10-20T10:00:00Z", messages: [reply] }),
    ) as unknown as typeof globalThis.fetch;
    const client = createSeaproof({ apiKey, fetch, storage: memory(), diagnostics: false });

    const [item] = await client.myFeedback();
    expect(client.hasUnreadReply(item!)).toBe(true);
    await client.myFeedbackItem("f1");
    expect(client.hasUnreadReply(item!)).toBe(false);
    expect(client.hasUnreadReply({ ...item!, lastReplyAt: "2026-10-22T10:00:00Z" })).toBe(true);
  });

  it("votes with PUT and takes the vote back with DELETE", async () => {
    const calls: string[] = [];
    const fetch = vi.fn(async (url: string, init: RequestInit) => {
      calls.push(`${init.method} ${url}`);
      return new Response(null, { status: 204 });
    }) as unknown as typeof globalThis.fetch;
    const client = createSeaproof({ apiKey, endpoint: "https://api.test", fetch, storage: memory(), diagnostics: false });

    await client.vote("i1");
    await client.unvote("i1");

    expect(calls).toEqual(["PUT https://api.test/api/v1/sdk/ideas/i1/vote", "DELETE https://api.test/api/v1/sdk/ideas/i1/vote"]);
  });
});
