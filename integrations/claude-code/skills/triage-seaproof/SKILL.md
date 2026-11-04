---
name: triage-seaproof
description: Triage new bug reports, feedback and ideas in Seaproof through its MCP server - find duplicates, set severity and status, write team notes and forward real bugs. Use when the user asks to go through, triage, sum up or clean up Seaproof reports, or to look at what testers or users reported.
---

# Triage Seaproof reports

Use the Seaproof MCP tools. If they are not connected, ask the user to run `/mcp` and
authenticate **seaproof**.

1. `list_projects`, and pick the project the user means (ask if it is unclear).
2. `count_feedback` for an overview, then `search_feedback` with `status: "new"`.
3. For each item, `get_feedback`. It includes screenshots and the app's diagnostics (errors,
   failed requests) and the build `commit`.
4. `find_similar_feedback` with the item's id. A clear duplicate: add a note pointing to the
   original and set it to `discarded` (several at once with `bulk_update_feedback`).
5. Real bugs: set `severity` (critical = data loss, crash on a main path or security; high =
   a main flow broken; medium = a workaround exists; low = cosmetic) and status `triaged`. Write
   the likely cause as a team note with `add_note`. If the report has a `commit` and this
   repository is the app, look at that code before guessing the cause.
6. Forward bugs the user wants in the tracker with `forward_feedback` (see `list_integrations`).
7. Ideas and feedback: group them, and set them to `triaged`.
8. Finish with a short summary: what was new, duplicates found, bugs by severity, anything that
   needs a person.

Never use `reply_to_reporter` or `publish_idea` unless the user asked for it: both reach the
app's users. Never change more than the user asked for.
