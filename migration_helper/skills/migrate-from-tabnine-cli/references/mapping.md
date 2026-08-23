# Field translation reference

Complete mapping from Tabnine CLI to opencode. When in doubt about opencode's shape, load the `customize-opencode` skill or fetch `https://opencode.ai/config.json`.

## Contents

- MCP servers (field-by-field table, per-server enablement, example translation)
- Skills (direct copy rules)
- Agents (allowed opencode frontmatter, local-agent field mapping, remote A2A handling, example translation)
- Commands (example translation, placeholder mapping, namespacing)
- Extensions (unpacking rules)
- Fields that are always dropped

## MCP servers

Tabnine settings.json → opencode `opencode.json`:

```
mcpServers[name] { … }         →   mcp[name] { type, …, enabled }
```

Field-by-field:

| Tabnine key | opencode key | Rule |
| --- | --- | --- |
| `url` | `url` | Set `type: "remote"`. |
| `httpUrl` | `url` | Same as `url` (deprecated Tabnine alias). Set `type: "remote"`. |
| `command` (string) + `args` (array) | `command` (array) | Combine into a single array: `[command, ...args]`. Set `type: "local"`. |
| `env` | `environment` | **Rename — opencode's key is `environment`, not `env`.** An `env` key is silently ignored and the server starts without its variables. Values: see the env-var interpolation rule below. |
| `headers` | `headers` | Copy, applying the env-var interpolation rule below. Remote servers only. |
| `type: "sse" \| "http"` | — | Not needed. opencode uses `type: "remote"` for both; the client negotiates transport. |
| `cwd` | `cwd` | Copy verbatim. Local servers only. |
| `timeout` | `timeout` | Copy verbatim. Both are milliseconds; opencode's default is 5000 if absent. |
| `trust` | — | opencode uses permissions instead. Drop; the user grants tool access at runtime. |
| `description` | — | Drop (opencode ignores it). |
| `includeTools` / `excludeTools` | — | Not supported. Drop; opencode surfaces all tools from an MCP. |
| `authProviderType` | — | Not supported. Drop. |
| `oauth` (Tabnine's built-in OAuth flow) | — | Drop. opencode expects the MCP itself to handle OAuth on first connect. |

### Env-var interpolation in values

The two systems use different placeholder syntax inside string values:

- Tabnine CLI expands `$VAR` and `${VAR}` when it loads settings.
- opencode expands `{env:VAR}` (and `{file:path}`) when it loads `opencode.json`. A literal `$VAR` is passed through untouched.

When a migrated value (in `environment`, `headers`, `url`, or `command`) contains `$VAR` or `${VAR}`, rewrite it to `{env:VAR}`. Example: `"Authorization": "Bearer $MCP_TOKEN"` → `"Authorization": "Bearer {env:MCP_TOKEN}"`. Values that contain no `$` placeholders copy verbatim.

This rule is unconditional: it applies to every `$NAME`/`${NAME}` substring anywhere inside a value — including inside larger strings like `"Bearer $TOKEN"`, and equally in `headers` and `environment`. Do not reason that a particular `$NAME` "looks like a literal" and keep it — Tabnine expanded it at load time, so a kept `$NAME` reaches the server as a dead literal in opencode. The only exception is a value the user explicitly confirms is a literal dollar string.

Per-server enablement (`~/.tabnine/agent/mcp-server-enablement.json`):

```
{ name: { enabled: false } }   →   mcp[name].enabled: false
```

Absent name → `enabled: true` (opencode default; you can omit the field).

Edge cases:

- Tabnine normalizes enablement keys to lowercase and trims whitespace — match case-insensitively against server names.
- Extension-bundled servers appear under an `ext:<name>` key (plain `<name>` also accepted for back-compat).
- Stale entries happen (a key with no matching server in `mcpServers`, e.g. a server the user deleted). Ignore them — never invent a server to match an enablement entry.

### Example translation

Source (`~/.tabnine/agent/settings.json`):

```json
{
  "mcpServers": {
    "AtlassianMCP": { "url": "https://mcp.atlassian.com/v1/mcp" },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp"],
      "env": { "PW_TOKEN": "$PLAYWRIGHT_TOKEN" },
      "cwd": "/Users/me/proj",
      "timeout": 30000
    }
  }
}
```

Enablement (`~/.tabnine/agent/mcp-server-enablement.json`):

```json
{ "playwright": { "enabled": false } }
```

Target (`~/.config/opencode/opencode.json`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "AtlassianMCP": {
      "type": "remote",
      "url": "https://mcp.atlassian.com/v1/mcp",
      "enabled": true
    },
    "playwright": {
      "type": "local",
      "command": ["npx", "-y", "@playwright/mcp"],
      "environment": { "PW_TOKEN": "{env:PLAYWRIGHT_TOKEN}" },
      "cwd": "/Users/me/proj",
      "timeout": 30000,
      "enabled": false
    }
  }
}
```

## Skills

Direct copy. Both systems use `SKILL.md` with the same required frontmatter fields (`name`, `description`).

Do not rewrite:

- Skill bodies. If a skill references Gemini binaries, that's a semantic change and the user should decide.
- The `name` field. It must stay unique across all scanned paths. On collision opencode logs `duplicate skill name` with both locations (to the log only, never the UI) and the last copy scanned wins. Deterministic, but scan-order dependent and invisible to the user, so the shadowed copy simply never runs. Avoid creating one.

Optional frontmatter fields opencode also accepts (see `customize-opencode`): `license`, `compatibility`, `metadata`. Preserve if present, remove none.

Location: `<target>/skills/<name>/SKILL.md`. Copy the whole directory including any sibling scripts, examples, `references/`, etc.

## Agents

Split frontmatter and body. Translate frontmatter. Body copies verbatim.

### Allowed opencode frontmatter fields

`name, model, variant, description, mode, hidden, color, steps, options, permission, disable, temperature, top_p`. Unknown fields are silently routed into `options` where they have no effect — so drop them explicitly.

### Local-agent field mapping

| Tabnine (snake_case) | opencode | Rule |
| --- | --- | --- |
| `kind: local` | — | Drop. It's the default. |
| `name` | `name` | Keep. Both use lowercase-hyphen slug. |
| `description` | `description` | Keep. |
| `display_name` | — | Drop. |
| `tools` | `permission` | **Translate. Do not drop.** Tabnine `tools` is a YAML list of *allowed* tool names, so dropping it grants the agent everything, including `bash`, `write`, and `edit`. See "Tool allowlist translation" below. |
| `mcp_servers` | — | Drop from the agent frontmatter. Ask the user if these should be hoisted into top-level `mcp` in `opencode.json` (they'll then be visible to all agents, not just this one). Note the frontmatter variant uses snake_case keys (`http_url`, `include_tools`, `exclude_tools`) — translate them like their camelCase settings.json equivalents. |
| `model: inherit` | — | Drop. Subagents inherit from parent by default; primaries fall back to global `model`. |
| `model: <provider>/<id>` | `model` | Keep if the value is already `provider/model-id` format. |
| `model: <plain name>` (e.g. `claude-4-opus`, `Claude 4.8 Opus`) | — | Drop. opencode requires the provider prefix; a plain name will fail validation. |
| `temperature` | `temperature` | Keep. |
| `max_turns` | `steps` | Rename. Preserve integer value. |
| `timeout_mins` | — | Drop. No opencode equivalent. Note this to the user. |
| — | `mode` | Add. Value from the wizard's Phase-2 per-agent prompt (`subagent` or `primary`). |

Body → agent prompt, no changes.

### Tool allowlist translation

Tabnine restricts an agent with a list of allowed tool names:

```yaml
tools:
  - read_file
  - run_shell_command
```

opencode expresses the same intent with `permission` (preferred) or the deprecated `tools` map. Both accept `*` as a wildcard, and the **last matching rule wins**, so put `*` first and the allowlist after:

```yaml
permission:
  "*": deny
  read: allow
  bash: allow
```

Tool names are not the same in the two systems. Map them:

| Tabnine tool | opencode permission key |
| --- | --- |
| `read_file`, `read_many_files` | `read` |
| `write_file` | `edit` (gates `write`, `edit`, `apply_patch`) |
| `replace` | `edit` |
| `run_shell_command` | `bash` |
| `glob` | `glob` |
| `search_file_content` | `grep` |
| `list_directory` | `list` |
| `web_fetch` | `webfetch` |
| `google_web_search` | `websearch` |
| `save_memory` | — (no equivalent; note it to the user) |
| `list_background_processes`, `read_background_output` | — (no equivalent; both are covered by `bash` in opencode) |

Rules:

- `write_file` and `replace` both map to `edit`, so an agent allowed only `replace` still gets write access under opencode. Say so explicitly — it is a widening of privilege that the mapping cannot avoid.
- An MCP-provided tool in the Tabnine list has no opencode built-in equivalent. Match it as a wildcard against the server name (`"mymcp_*": "allow"`) and tell the user which entries you translated this way.
- If a listed tool has no mapping at all, do **not** silently drop it. List the unmapped names in the summary so the user can decide.
- Never invent a permission the source did not grant. Deny-by-default plus the mapped allowlist is the whole translation.


### Remote (A2A) agents

opencode has no built-in A2A remote agent kind. Two options:

1. **Skip with a warning — this is the default.** Report the file as "remote agent: skipped (no opencode equivalent)" and move on.
2. Only if the user explicitly asks: offer to hand-write a subagent whose body calls the remote via `webfetch` or a bespoke MCP. Never auto-generate this.

### Example translation

Source (`~/.tabnine/agent/agents/jira-issue-manager.md`):

```markdown
---
name: jira-issue-manager
model: inherit
max_turns: 15
timeout_mins: 5
description: Manage Jira issues …
---

You are a Jira and Confluence management specialist. …
```

Target (`~/.config/opencode/agents/jira-issue-manager.md`), with the user picking `subagent` mode:

```markdown
---
name: jira-issue-manager
mode: subagent
steps: 15
description: Manage Jira issues …
---

You are a Jira and Confluence management specialist. …
```

Dropped: `model: inherit` (no-op), `timeout_mins: 5` (no equivalent).

### Target folder name

opencode's agent loader globs `{agent,agents}/**/*.md`, so `agent/` and `agents/` are both valid and nested subfolders are scanned too. Write new agents to the plural `agents/`, matching the agents documentation and `opencode agent create`. If the target already uses the singular `agent/`, add to it rather than migrating the existing files across.

## Commands

Tabnine TOML → opencode Markdown-with-frontmatter.

### Example translation

Source (`~/.tabnine/agent/commands/deploy.toml`):

```toml
description = "Deploy to staging"
prompt = """
Deploy branch {{args}} to staging.
Run tests first with !{npm test}.
Check @{README.md} for the runbook.
"""
```

Target (`~/.config/opencode/command/deploy.md`):

```markdown
---
description: Deploy to staging
---

Deploy branch $ARGUMENTS to staging.
Run tests first with !`npm test`.
Check @README.md for the runbook.
```

### Placeholder mapping

| Tabnine | opencode | Notes |
| --- | --- | --- |
| `{{args}}` | `$ARGUMENTS` | Both mean "everything the user typed after the command". |
| — | `$1`, `$2`, … | opencode adds positional args. Tabnine has no direct equivalent; if the source uses split-args logic in `prompt`, leave a TODO comment for the user. |
| `!{shell command}` | ``!`shell command` `` | Both allow shell injection. opencode uses backtick syntax. |
| `@{file/path}` | `@file/path` | Both allow file injection. opencode drops the braces. |
| (no placeholder at all) | (no placeholder at all) | Copy as-is. Both systems automatically append the user's arguments when the prompt contains no placeholder — do not insert `$ARGUMENTS`. |

### Namespacing

Tabnine derives namespaced command names from nested folders using `:` (`commands/foo/bar.toml` → `foo:bar`). opencode derives them from folder structure using `/` (`command/foo/bar.md` → `/foo/bar`). Mirror the source folder structure — `commands/foo/bar.toml` becomes `<target>/command/foo/bar.md` — so `foo:bar` in Tabnine is `/foo/bar` in opencode. Mention the renamed invocation in the summary. Do not flatten names.

## Extensions

opencode has no extension bundle format. Before unpacking, check `~/.tabnine/agent/extensions/extension-enablement.json` — skip extensions the user has disabled there (offer them only if the user asks). Then unpack:

- Each `mcpServers` entry → treat as a top-level MCP (rules above). If the extension name should be preserved, prefix: `<ext>-<original-name>`.
- Each `skills/*/SKILL.md` → treat as a normal skill.
- Each `agents/*.md` → treat as a normal agent.
- Each `commands/*.toml` → treat as a normal command.

The `contextFileName` field (extension-provided AGENTS.md-like context) can be migrated as-is into the target's `instructions` array in `opencode.json`, if the user wants: `"instructions": [ ..., "/path/to/extension/context.md" ]`.

## Fields that are always dropped

Regardless of category, these Tabnine fields have no opencode counterpart and should never be preserved:

- Any `governanceExempt` markers (Tabnine-only enterprise policy).
- Admin policy fields (`admin.mcp.enabled`, `admin.skills.enabled`, `admin.mcp.config`) — these are runtime admin controls, not portable config.
- Trust markers (`trust: true` on MCPs, trusted-folder logic). opencode uses `permission` instead.
- Acknowledgement hashes (`~/.tabnine/agent/acknowledgments/agents.json`). opencode doesn't require per-agent acknowledgement.
- Tabnine credentials, IDs, and OAuth token stores.
