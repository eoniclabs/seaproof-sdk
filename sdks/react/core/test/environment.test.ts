import { describe, expect, it } from "vitest";
import { createSeaproof, modeOf } from "../src/client";

const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

describe("environment mode", () => {
  it("reads mode, and environment from APIs before named environments", () => {
    expect(modeOf({ environment: "test", mode: "test" })).toBe("test");
    expect(modeOf({ environment: "production", mode: "production" })).toBe("production");
    expect(modeOf({ environment: "staging" as never })).toBe("test");
    expect(modeOf({ environment: "production" })).toBe("production");
  });

  it("follows the key's environment and knows its name", async () => {
    const fetch = async () =>
      json(200, { projectId: "p1", projectName: "Shop", environment: "test", mode: "test", environmentName: "UAT", environmentId: "e1" });
    const client = createSeaproof({ apiKey: "sp_" + "a".repeat(43), endpoint: "https://api.test", fetch: fetch as unknown as typeof globalThis.fetch });
    expect(client.isTesterMode).toBe(false);
    await client.start();
    expect(client.isTesterMode).toBe(true);
    expect(client.environment).toBe("test");
    expect(client.environmentName).toBe("UAT");
    client.dispose();
  });
});
