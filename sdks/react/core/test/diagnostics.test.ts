import { afterEach, describe, expect, it, vi } from "vitest";
import { createSeaproof, Diagnostics, installCapture, redactUrl } from "../src";

const apiKey = "sp_" + "a".repeat(43);
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

describe("diagnostics", () => {
  let uninstall = () => {};
  afterEach(() => uninstall());

  it("redacts query values but keeps keys", () => {
    expect(redactUrl("https://shop.test/search?q=kim@example.com&token=abc")).toBe("https://shop.test/search?q=*&token=*");
    expect(redactUrl("https://shop.test/cart")).toBe("https://shop.test/cart");
  });

  it("keeps the newest entries", () => {
    const d = new Diagnostics(2);
    d.add("log", "one");
    d.add("log", "two");
    d.add("log", "three");
    expect(d.list().map((e) => e.message)).toEqual(["two", "three"]);
  });

  it("records console output, fetch calls and uncaught errors, and restores them", async () => {
    const realFetch = vi.fn(async () => new Response("{}", { status: 404 }));
    window.fetch = realFetch as unknown as typeof fetch;
    const originalLog = console.log;
    const d = new Diagnostics();
    uninstall = installCapture(d, { ignoreUrl: (u) => u.startsWith("https://api.seaproof.test") });

    console.log("loaded", { items: 2 });
    await fetch("https://shop.test/api/cart?session=secret", { method: "post" });
    await fetch("https://api.seaproof.test/api/v1/sdk/whoami");
    window.dispatchEvent(new ErrorEvent("error", { message: "boom", error: new Error("boom") }));

    const entries = d.list();
    expect(entries.map((e) => e.kind)).toEqual(["console", "network", "error"]);
    expect(entries[0]!.message).toBe('loaded {"items":2}');
    expect(entries[1]).toMatchObject({ method: "POST", url: "https://shop.test/api/cart?session=*", status: 404 });
    expect(entries[2]!.message).toBe("boom");

    uninstall();
    uninstall = () => {};
    expect(console.log).toBe(originalLog);
    expect(window.fetch).toBe(realFetch);
  });

  it("attaches diagnostics for testers and reports crashes on its own", async () => {
    const bodies: Record<string, unknown>[] = [];
    const sdkFetch = vi.fn(async (url: string, init: RequestInit) => {
      if (url.endsWith("/whoami")) return json(200, { projectId: "p1", projectName: "Shop", environment: "test" });
      if (url.endsWith("/api/v1/sdk/feedback")) {
        const body = JSON.parse(init.body as string) as { attachments: unknown[] };
        bodies.push(body);
        return json(201, { id: "f1", number: bodies.length, uploads: body.attachments.map((_, i) => ({ attachmentId: `a${i}`, method: "PUT", url: `https://storage.test/${i}`, headers: {} })) });
      }
      return new Response(null, { status: 200 });
    });
    const client = createSeaproof({ apiKey, endpoint: "https://api.test", fetch: sdkFetch as unknown as typeof fetch, reportCrashes: true });
    uninstall = () => client.dispose();
    expect(client.isTesterMode).toBe(false);
    await client.start();
    expect(client.isTesterMode).toBe(true);

    client.log("opened cart");
    await client.submit({ description: "Broken" });
    expect(bodies[0]!.attachments).toEqual([{ kind: "log", fileName: "diagnostics.ndjson", contentType: "application/x-ndjson", sizeBytes: expect.any(Number) }]);

    for (const m of ["x", "x", "y"]) window.dispatchEvent(new ErrorEvent("error", { message: m, error: new Error(m) }));
    await vi.waitFor(() => expect(bodies).toHaveLength(3));
    expect(bodies[1]).toMatchObject({ type: "bug", title: "Crash: x", context: { custom: { "seaproof.source": "crash" } } });
  });
});
