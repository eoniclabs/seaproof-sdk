# Seaproof rules for Cursor, GitHub Copilot and other editors

The same guidance as the Claude Code plugin's `add-seaproof` skill, as files other coding
agents read. Copy the one that fits your editor into your app's repository:

| Editor | File | Copy to |
| --- | --- | --- |
| Cursor | [`seaproof.mdc`](seaproof.mdc) | `.cursor/rules/seaproof.mdc` |
| GitHub Copilot | [`copilot-instructions.md`](copilot-instructions.md) | append to `.github/copilot-instructions.md` |
| Others (Codex, Gemini CLI, Windsurf, …) | [`copilot-instructions.md`](copilot-instructions.md) | append to `AGENTS.md` |

Agents that speak MCP can also connect to `https://api.seaproof.io/mcp` to create the project
and API key for you; see [AI agents](../../docs/ai-agents.md). For Claude Code, install the
[plugin](../claude-code/README.md) instead.

`copilot-instructions.md` is `seaproof.mdc` without the Cursor front matter; change both
together.
