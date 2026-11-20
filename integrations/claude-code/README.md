# Seaproof plugin for Claude Code

Adds Seaproof to Claude Code: the Seaproof MCP server and two skills.

- **`add-seaproof`**: adds in-app bug reporting and user feedback to a React, Next.js or
  Flutter app. It creates the project and an API key over MCP, stores the key outside source
  control, installs and wires in the SDK with `get_sdk_setup`, passes the build's commit, masks
  personal data and adds an AGENTS.md section. It offers to forward bugs to GitHub or Azure DevOps
  and to set up a scheduled triage job with a service agent.
- **`triage-seaproof`**: goes through new reports. It finds duplicates, sets severity and status,
  writes notes with the likely cause, and forwards real bugs.

## Install

```text
/plugin marketplace add eoniclabs/seaproof-sdk
/plugin install seaproof@seaproof
```

Then run `/mcp`, choose **seaproof → Authenticate** and sign in to Seaproof. Tick
**Set up projects** if Claude should create projects and API keys (owners and admins only).

Without the plugin you can add just the MCP server:

```sh
claude mcp add --transport http seaproof https://api.seaproof.io/mcp
```

## Use

- "Add Seaproof to this app so testers can report bugs."
- "Triage the new Seaproof reports for the Shop app."

## Cursor, Copilot and other agents

The same instructions are in [editor rules](../editor-rules/README.md) for Cursor and GitHub
Copilot, and in the [AGENTS.md section](../../docs/guides/agents-md.md).
