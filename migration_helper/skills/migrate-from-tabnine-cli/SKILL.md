---
name: migrate-from-tabnine-cli
description: Wizard that migrates Tabnine CLI (a Gemini CLI fork) configuration into opencode. Use ONLY when the user asks to migrate, import, copy, or move Tabnine CLI (or Gemini CLI) skills, agents, subagents, MCP servers, slash commands, or extensions into opencode, or mentions moving from `~/.tabnine/agent`, `.tabnine/agent`, `.gemini`, or similar dirs. Not for migrating code, repos, or data; not for Claude Code skills (opencode reads `~/.claude/skills` natively); not for copying config between machines; not for context/memory files (TABNINE.md) — that's the migrate-tabnine-context skill.
---

# Migrate from Tabnine CLI to opencode

You are running an interactive migration wizard. The user has Tabnine CLI (or Gemini CLI) configuration on disk and wants it available in opencode. Your job is to discover what they have, ask exactly what to move where, translate incompatible fields, and install the results without breaking opencode's strict config validation.

## Core rules

1. **Never migrate blindly.** Always list what you found and ask the user to pick, per category, before writing anything.
2. **Never invent MCP servers, skills, or agents that aren't on disk.** Only migrate what discovery actually finds.
3. **Never overwrite an existing opencode file without asking.** If a target file already exists, offer skip / overwrite / rename.
4. **Never touch the source files.** This is a copy-and-translate flow, not a move. The user should be able to keep using Tabnine CLI after.
5. **Validate translations against opencode's schema before writing.** If unsure about a field's shape, fetch `https://opencode.ai/config.json`; the built-in `customize-opencode` skill (bundled with opencode) is a faster shortcut when available.
6. **Remind the user to restart opencode at the end.** opencode does not hot-reload config.
7. **Stop writing once the wizard finishes.** After the Phase 4 summary, the migration is over. If a later question or a doc you read suggests a different layout, say so and ask — never move, rename, or rewrite an already-migrated file on your own initiative. A follow-up question is not authorization to change the filesystem.
8. **Separate verified facts from judgment calls.** Say "the docs show X, the skill says Y, I picked Y because Z" rather than asserting one as settled. If a claim in this skill contradicts what you observe, report the conflict instead of silently correcting either side.

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

For each SKILL.md and each agent `.md`, read only the frontmatter (top of file up to the second `---`) to get `name` and `description`. Don't slurp full bodies during discovery. Exception: if an agent file's frontmatter parses as a YAML **array**, it's a remote-agent (A2A) bundle — record the whole file as "remote agents: skipped (no opencode equivalent)" and don't look for `name`/`description` in it.

If discovery also notices Tabnine context files (`TABNINE.md` in the project or `~/.tabnine/agent/`), don't inventory them here — mention once that the separate `/migrate-context` command handles those.

After discovery, print a compact inventory like:

```
Found in ~/.tabnine/agent:
  MCPs (3):     github-mcp [enabled], playwright [disabled], tabnine-context (built-in, skipped)
  Skills (2):   release-notes, code-review-checklist
  Agents (1):   issue-triager
  Commands (0)
  Extensions (0)

Found in ~/.agents/skills:
  Skills (0)

Found in <cwd>/.tabnine/agent: (nothing)
```

Show the built-in `tabnine-context` / `tabnine-coaching` servers greyed-out as `(built-in, skipped)` — never as selectable items — so the user isn't confused when they don't appear in the multi-select.

Then ask what the user wants to migrate — one category at a time.

## Phase 2 — Ask per category

Use the `question` tool. Order:

1. **Target scope for this session** — global (`~/.config/opencode/`) or project (`./.opencode/` in the current worktree). Ask once at the start of the session. If the user later says something like "put this one in the project instead", re-scope only that category and keep the session default for the rest.
2. **MCP servers** — multi-select from the discovered list. Warn on any name conflict with an existing `mcp.<name>` in the target `opencode.json`.
3. **Skills** — multi-select. Warn on any target-folder collision.
4. **Agents** — multi-select. For each selected agent, ask a follow-up: `subagent` (default) or `primary` mode, using exactly this explanation: "primary agents are user-facing entry points the user can switch to and chat with directly; subagents are only invoked by another agent as a delegated task." (opencode also has `mode: all` — don't offer it; suggest it only if the user asks for both behaviors.)
5. **Commands** — multi-select if any were found.
6. **Extensions** — for each **enabled** extension found (skip ones disabled in `extension-enablement.json`), list what it bundles (MCPs / skills / agents / commands) and ask whether to unpack each component into the target. Do not migrate the extension manifest itself; opencode has no equivalent.

Never present a "migrate all" shortcut without also showing the individual list. After printing the inventory, the very next message must be the target-scope question followed by the MCP multi-select — not a yes/no "shall I migrate everything?" confirmation. The user asked for a wizard — respect that.

## Phase 3 — Translate and write

Per opencode's schema (see `references/mapping.md` next to this SKILL.md for the full field-by-field table). Highlights:

### MCP servers

Tabnine stores `mcpServers: { name: { url?, httpUrl?, command?, args?, env?, cwd?, timeout?, headers?, type? } }` in `settings.json`.

Translate to opencode `mcp: { name: { type, url|command, headers?, environment?, cwd?, timeout?, enabled } }`:

- If the source has a `url` or `httpUrl` field → `type: "remote"`, `url: <that value>`.
- If the source has a `command` field → `type: "local"`, `command: [<command>, ...args]` (opencode requires an array).
- Rename `env` → `environment` — **opencode's key is `environment`; an `env` key is silently ignored and the server starts without its variables.** Preserve `headers`, `cwd`, and `timeout` under their own names.
- Rewrite `$VAR` / `${VAR}` placeholders inside values to opencode's `{env:VAR}` syntax — unconditionally, wherever they appear, including inside larger strings (`"Bearer $TOKEN"` → `"Bearer {env:TOKEN}"`) and in `headers` as much as `environment` (see `references/mapping.md`).
- Set `enabled: false` if the enablement file marks this server disabled; otherwise `enabled: true` (opencode's default). Ignore enablement entries with no matching server.
- Never copy `mcp-oauth-tokens.json`. OAuth tokens will not carry over; the user will re-authenticate on first use. Tell them this after writing.

If the target `opencode.json` exists, copy it to `opencode.json.bak-<YYYYMMDD-HHMMSS>` first, then merge into its `mcp` object rather than replacing it. Preserve `$schema`, `plugin`, and any other keys already present. If the file doesn't exist, create it with `"$schema": "https://opencode.ai/config.json"` (no backup needed).

### Skills

Copy the entire skill folder (SKILL.md and all sibling files) to `<target>/skills/<name>/`. Frontmatter is compatible verbatim — both systems require `name` and `description`. Do not edit the SKILL.md, with one exception below.

Name normalization (the exception): opencode's documented name format is `^[a-z0-9]+(-[a-z0-9]+)*$` (lowercase, hyphen-separated). Tabnine allows underscores, uppercase, and spaces in skill and agent names. Current opencode builds load nonconforming names anyway, but they're outside the documented contract and may break in a future version. If a selected skill or agent has a nonconforming `name`, offer to normalize it (lowercase, `_` and spaces → `-`) in both the `name` field and the target folder/file name — with the user's confirmation, never silently.

After copying each selected skill, grep its body (and sibling files) for Gemini-specific tokens: `gemini -p`, `gemini `, `tui-tester`, `GEMINI.md`, `.gemini/`. Do **not** rewrite anything — rewriting prompts changes semantics. Record each hit and report the affected skills in the Phase 4 summary, one line each, so the user can fix them later.

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

Write to `<target>/agents/<name>.md`. opencode's loader globs `{agent,agents}/**/*.md`, so both spellings are loaded and neither is more correct than the other. Prefer the plural `agents/`: it's the form the agents documentation uses in every example and the form `opencode agent create` writes, so a user who later cross-checks the docs won't find a mismatch. If the target already has a singular `agent/` folder, write there instead and leave it alone — do not consolidate or move existing files to match this preference.

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

Rewrite all three Tabnine placeholder syntaxes in the prompt body — not just `{{args}}`:

- `{{args}}` → `$ARGUMENTS`
- `!{shell command}` → `` !`shell command` `` (backticks, no braces)
- `@{file/path}` → `@file/path` (drop the braces)

Leave `$ARGUMENTS`, `$1`, `$2` alone if already present. If the prompt has no placeholder at all, copy it as-is — both systems auto-append the user's arguments; do not insert `$ARGUMENTS`.

Write to `<target>/command/<name>.md`, mirroring nested source folders: `commands/foo/bar.toml` → `<target>/command/foo/bar.md`. The invocation changes from Tabnine's `/foo:bar` to opencode's `/foo/bar` — mention this in the summary.

### Extensions

Do not migrate `tabnine-extension.json` as a unit. For each component the user opted into, apply the rules above to the extension's `mcpServers`, `skills/`, `agents/`, `commands/` entries. Prepend the extension name to the migrated item's `name` field if a collision exists (`<ext>-<original-name>`), and mention this to the user.

## Phase 4 — Post-write summary and warnings

After all writes succeed, print a summary:

- What was written (grouped by category, with target paths), including the `opencode.json.bak-*` backup path if one was made.
- Any items that were **skipped** due to collisions or user opt-out, and any names or invocations that changed (normalized names, `/foo:bar` → `/foo/bar`).
- Any agents where `tools`, `mcp_servers`, `timeout_mins`, or `model` fields were dropped, with a one-liner suggesting where the user should look next. For a dropped `model`, point at `opencode models` / the provider list so the user can set a `provider/model-id` value themselves.
- Any skills whose bodies reference Gemini-specific tools, flagged for manual review.
- OAuth reminder for any migrated remote MCP servers (Atlassian, Mixpanel, GitHub, etc.): tokens do not carry over.
- If Tabnine context files exist (`TABNINE.md` in the project or `~/.tabnine/agent/`): "Your TABNINE.md context files weren't part of this migration — run `/migrate-context` to move them into AGENTS.md."
- **Restart reminder**: "Quit and restart opencode for these changes to take effect. Running sessions keep using the already-loaded config."

Note about Claude Code skills at `~/.claude/skills`: opencode auto-scans this path already. Do NOT copy skills from there into `~/.config/opencode/skills/` unless the user explicitly asks — you'd end up with two copies of the same name, and opencode resolves duplicates by a coin-flip (the "winner" is non-deterministic and the warning is only written to logs). If discovery finds Claude Code skills, tell the user they're already visible to opencode and skip them by default.

## When things go wrong

- **`ConfigInvalidError` on startup after migration**: the user's `opencode.json` has a rejected field. Recover with `OPENCODE_DISABLE_PROJECT_CONFIG=1 opencode` (project) or by manually editing the global file. Point them at the escape hatches in the `customize-opencode` skill.
- **A migrated skill behaves inconsistently or seems to "flip" between versions**: two skills with the same `name` exist in scanned paths — opencode only logs a warning and which copy wins is non-deterministic. Rename one or delete the older copy.
- **`ConfigInvalidError` after the MCP merge specifically**: restore the `opencode.json.bak-<timestamp>` backup written before the merge, then retry.
- **MCP server appears but returns auth errors**: normal on first use — re-authenticate via the MCP's OAuth flow. Do not attempt to copy tokens from `~/.tabnine/agent/mcp-oauth-tokens.json`.
- **User wants to reverse the migration**: the wizard doesn't delete Tabnine sources, so reversing means deleting the newly created files under `<target>/{mcp entries, skills/*, agents/*.md, command/*.md}`. Offer to list them if asked.

## Reference material

See `references/source-map.md` for the exhaustive list of Tabnine CLI config paths (with the code-verified precedence rules), and `references/mapping.md` for the complete field translation table with edge cases.

If you need to verify an opencode field shape before writing, fetch `https://opencode.ai/config.json` or load the built-in `customize-opencode` skill.
