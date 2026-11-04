# Listing Seaproof in MCP directories

Agents find MCP servers through directories. These are the listings for Seaproof's remote server,
`https://api.seaproof.io/mcp`. Each needs production to be live first.

## Official MCP Registry (issue #43)

[`server.json`](server.json) describes the server. The name `io.seaproof/seaproof` is proven by a
DNS record on seaproof.io:

```sh
brew install mcp-publisher            # or download it from the registry's releases
mcp-publisher login dns --domain seaproof.io --private-key <ed25519 key in hex>
mcp-publisher publish integrations/mcp-registry/server.json
```

`login dns` prints the TXT record to add to seaproof.io first. Keep the private key in
Bitwarden Secrets Manager. Raise `version` in `server.json` for each new listing.

## Claude, ChatGPT, Cursor and VS Code (issues #44 and #45)

Each directory asks for much the same, so the answers are here to copy:

| Field | Value |
| --- | --- |
| Name | Seaproof |
| Server URL | `https://api.seaproof.io/mcp` (Streamable HTTP) |
| Authentication | OAuth 2.1 with dynamic client registration and PKCE; sign-up during connection (Google, GitHub, Microsoft or email) |
| Short description | Bug reports from testers and feedback from users of Flutter and React apps, ready for your agent to triage and fix. |
| Long description | Seaproof collects bug reports from testers (shake or a button, with a screenshot and the app's logs) and feedback, questions and ideas from end users. Connect it to search and read reports with screenshots and diagnostics, find duplicates, set severity and status, write team notes, forward bugs to GitHub or Azure DevOps, answer reporters and publish ideas. A coding agent can also add Seaproof to an app from start to finish. |
| Example prompts | "Add Seaproof to this app." · "What new bugs came in this week? Group them by screen." · "Read #142, find the cause in this repository and forward it to GitHub." |
| Docs | https://seaproof.io/docs/ai-agents.md |
| Privacy policy | Required by every directory; not published yet (https://seaproof.io/privacy is planned) |
| Support | support@seaproof.io |
| Logo | `apps/web/public/favicon.svg` |

Every tool carries MCP annotations (read-only, destructive, idempotent, open-world), which the
directories check. The Cursor directory and community lists (such as mcp.so and Smithery) take a
pull request or a form with the same fields.
