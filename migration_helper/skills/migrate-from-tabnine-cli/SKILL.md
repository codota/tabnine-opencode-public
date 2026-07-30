---
name: migrate-from-tabnine-cli
description: Wizard that migrates Tabnine CLI (a Gemini CLI fork) configuration into opencode. Use ONLY when the user asks to migrate, import, copy, or move Tabnine CLI (or Gemini CLI) skills, agents, subagents, MCP servers, slash commands, or extensions into opencode, or mentions moving from `~/.tabnine/agent`, `.tabnine/agent`, `.gemini`, `~/.claude/skills`, or similar dirs. Walks the user through discovery, per-item selection, target-scope choice (global vs project), and field translation so opencode's strict schema accepts the results.
---

# Migrate from Tabnine CLI to opencode

You are running an interactive migration wizard. The user has Tabnine CLI (or Gemini CLI) configuration on disk and wants it available in opencode. Your job is to discover what they have, ask exactly what to move where, translate incompatible fields, and install the results without breaking opencode's strict config validation.

## Core rules

1. **Never migrate blindly.** Always list what you found and ask the user to pick, per category, before writing anything.
2. **Never invent MCP servers, skills, or agents that aren't on disk.** Only migrate what discovery actually finds.
3. **Never overwrite an existing opencode file without asking.** If a target file already exists, offer skip / overwrite / rename.
4. **Never touch the source files.** This is a copy-and-translate flow, not a move. The user should be able to keep using Tabnine CLI after.
5. **Validate translations against opencode's schema before writing.** If unsure about a field's shape, load the `customize-opencode` skill or fetch `https://opencode.ai/config.json`.
6. **Remind the user to restart opencode at the end.** opencode does not hot-reload config.

## Phase 1 — Discover

Before asking anything, scan the source locations and build an inventory. Report the counts back to the user before the first question.

Source locations to check (in this order, all optional):

| Source | Path |
| --- | --- |
| User settings (MCPs live here) | `~/.tabnine/agent/settings.json` — read the `mcpServers` object |
| Per-server enablement | `~/.tabnine/agent/mcp-server-enablement.json` — `{ name: { enabled: false } }` means user disabled it |
| User skills | `~/.tabnine/agent/skills/*/SKILL.md` |
| User agents/subagents | `~/.tabnine/agent/agents/*.md` |
| User slash commands | `~/.tabnine/agent/commands/**/*.toml` |
| User extensions | `~/.tabnine/agent/extensions/*/tabnine-extension.json` (may bundle MCPs, skills, agents, commands) |
| Agent-alias skills | `~/.agents/skills/*/SKILL.md` |
| Workspace equivalents | `<cwd>/.tabnine/agent/{skills,agents,commands,extensions}/…`, `<cwd>/.agents/skills/…` |
| Legacy Gemini paths (if the user hasn't switched to Tabnine mode) | Same layout under `.gemini/` and `~/.gemini/` |
| Legacy Claude Code skills | `~/.claude/skills/*/SKILL.md` (opencode already auto-scans this location — see note in Phase 4) |

Use the Read/Glob tools to check each path. If a path doesn't exist, silently skip it — don't error.

For each SKILL.md and each agent `.md`, read only the frontmatter (top of file up to the second `---`) to get `name` and `description`. Don't slurp full bodies during discovery.

After discovery, print a compact inventory like:

```
Found in ~/.tabnine/agent:
  MCPs (2):     AtlassianMCP [enabled], mixpanelMCP [enabled]
  Skills (8):   create-dashboard, deep-research, docs-validation, ...
  Agents (1):   jira-issue-manager
  Commands (0)
  Extensions (0)

Found in ~/.agents/skills:
  Skills (0)

Found in <cwd>/.tabnine/agent: (nothing)
```

Then ask what the user wants to migrate — one category at a time.

## Phase 2 — Ask per category

Use the `question` tool. Order:

1. **Target scope for this session** — global (`~/.config/opencode/`) or project (`./.opencode/` in the current worktree). Ask once at the start of the session. It can be overridden per-category if the user wants.
2. **MCP servers** — multi-select from the discovered list. Warn on any name conflict with an existing `mcp.<name>` in the target `opencode.json`.
3. **Skills** — multi-select. Warn on any target-folder collision.
4. **Agents** — multi-select. For each selected agent, ask a follow-up: `subagent` (default) or `primary` mode. Explain the difference in one sentence.
5. **Commands** — multi-select if any were found.
6. **Extensions** — for each extension found, list what it bundles (MCPs / skills / agents / commands) and ask whether to unpack each component into the target. Do not migrate the extension manifest itself; opencode has no equivalent.

Never present a "migrate all" shortcut without also showing the individual list. The user asked for a wizard — respect that.

## Phase 3 — Translate and write

Per opencode's schema (see `references/mapping.md` next to this SKILL.md for the full field-by-field table). Highlights:

### MCP servers

Tabnine stores `mcpServers: { name: { url?, httpUrl?, command?, args?, env?, headers?, type? } }` in `settings.json`.

Translate to opencode `mcp: { name: { type, url|command, headers?, env?, enabled } }`:

- If the source has a `url` or `httpUrl` field → `type: "remote"`, `url: <that value>`.
- If the source has a `command` field → `type: "local"`, `command: [<command>, ...args]` (opencode requires an array).
- Preserve `headers` and `env` verbatim.
- Set `enabled: false` if the enablement file marks this server disabled; otherwise `enabled: true` (opencode's default).
- Never copy `mcp-oauth-tokens.json`. OAuth tokens will not carry over; the user will re-authenticate on first use. Tell them this after writing.

Merge into `opencode.json`'s `mcp` object rather than replacing it. Preserve `$schema`, `plugin`, and any other keys already present. If the file doesn't exist, create it with `"$schema": "https://opencode.ai/config.json"`.

### Skills

Copy the entire skill folder (SKILL.md and all sibling files) to `<target>/skills/<name>/`. Frontmatter is compatible verbatim — both systems require `name` and `description`. Do not edit the SKILL.md.

If the skill body references Gemini-specific tools (`gemini`, `gemini -p`, `tui-tester`, etc.), do **not** silently rewrite them. Instead, after copying, note the affected skills to the user with one line each so they can fix them later. Rewriting prompts changes semantics.

### Agents

Read the source `.md`, split frontmatter from body, translate frontmatter, keep body verbatim.

Field mapping (drop anything not listed):

| Tabnine frontmatter | opencode frontmatter | Notes |
| --- | --- | --- |
| `name` | `name` | Keep. |
| `description` | `description` | Keep. |
| `display_name` | — | Drop. opencode has no equivalent. |
| `model` | `model` | Keep only if it's already `provider/model-id`. Values like `inherit`, `claude-4-opus`, `Claude 4.8 Opus` must be dropped (subagents inherit by default; primaries fall back to global `model`). |
| `temperature` | `temperature` | Keep. |
| `max_turns` | `steps` | Rename. Keep integer value. |
| `timeout_mins` | — | Drop. opencode has no per-agent timeout. Mention this to the user for that agent. |
| `tools` | — | Drop. opencode uses per-tool `permission` instead. Suggest an equivalent permission block only if the user asks — do not guess. |
| `mcp_servers` | — | Drop. opencode agents cannot declare private MCPs. Offer to move the definitions into top-level `mcp` in `opencode.json`. |
| — | `mode` | Add. Use the value the user chose in Phase 2 (`subagent` or `primary`). |

Write to `<target>/agent/<name>.md` (opencode also accepts `agents/`, but the singular form is canonical in the schema examples — pick one and stick with it; if the target already has a plural folder, use that).

### Commands

Tabnine command TOMLs look like:

```toml
description = "..."
prompt = """
Multi-line prompt with {{args}} or $ARGUMENTS references
"""
```

Translate to opencode markdown:

```markdown
---
description: "…"
---

<body: the prompt content, verbatim>
```

Replace Tabnine's `{{args}}` placeholder with opencode's `$ARGUMENTS`. Leave `$ARGUMENTS`, `$1`, `$2` alone if already present.

Write to `<target>/command/<name>.md`. Nested subfolders in the source (`commands/foo/bar.toml`) become filename-mangled names or nested folders — mirror the source structure.

### Extensions

Do not migrate `tabnine-extension.json` as a unit. For each component the user opted into, apply the rules above to the extension's `mcpServers`, `skills/`, `agents/`, `commands/` entries. Prepend the extension name to the migrated item's `name` field if a collision exists (`<ext>-<original-name>`), and mention this to the user.

## Phase 4 — Post-write summary and warnings

After all writes succeed, print a summary:

- What was written (grouped by category, with target paths).
- Any items that were **skipped** due to collisions or user opt-out.
- Any agents where `tools`, `mcp_servers`, `timeout_mins`, or `model` fields were dropped, with a one-liner suggesting where the user should look next.
- Any skills whose bodies reference Gemini-specific tools, flagged for manual review.
- OAuth reminder for any migrated remote MCP servers (Atlassian, Mixpanel, GitHub, etc.): tokens do not carry over.
- **Restart reminder**: "Quit and restart opencode for these changes to take effect. Running sessions keep using the already-loaded config."

Note about Claude Code skills at `~/.claude/skills`: opencode auto-scans this path already. Do NOT copy skills from there into `~/.config/opencode/skills/` unless the user explicitly asks — you'd end up with duplicates (opencode will load both and warn). If discovery finds Claude Code skills, tell the user they're already visible to opencode and skip them by default.

## When things go wrong

- **`ConfigInvalidError` on startup after migration**: the user's `opencode.json` has a rejected field. Recover with `OPENCODE_DISABLE_PROJECT_CONFIG=1 opencode` (project) or by manually editing the global file. Point them at the escape hatches in the `customize-opencode` skill.
- **Duplicate skill name warning at load time**: two skills with the same `name` exist in scanned paths. Rename one or delete the older copy.
- **MCP server appears but returns auth errors**: normal on first use — re-authenticate via the MCP's OAuth flow. Do not attempt to copy tokens from `~/.tabnine/agent/mcp-oauth-tokens.json`.
- **User wants to reverse the migration**: the wizard doesn't delete Tabnine sources, so reversing means deleting the newly created files under `<target>/{mcp entries, skills/*, agent/*.md, command/*.md}`. Offer to list them if asked.

## Reference material

See `references/source-map.md` for the exhaustive list of Tabnine CLI config paths (with the code-verified precedence rules), and `references/mapping.md` for the complete field translation table with edge cases.

Load the `customize-opencode` skill before writing anything if you need to verify an opencode field shape.
