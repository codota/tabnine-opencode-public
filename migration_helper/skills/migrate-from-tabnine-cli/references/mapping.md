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
| `httpUrl` | `url` | Same as `url`. Set `type: "remote"`. |
| `command` (string) + `args` (array) | `command` (array) | Combine into a single array: `[command, ...args]`. Set `type: "local"`. |
| `env` | `env` | Copy verbatim. Both accept `{env:VAR}` interpolation. |
| `headers` | `headers` | Copy verbatim. Both accept `{env:VAR}` interpolation. |
| `type: "sse" \| "http"` | — | Not needed. opencode uses `type: "remote"` for both; the client negotiates transport. |
| `cwd` | — | Not supported by opencode's MCP config. Warn. |
| `timeout` | — | Not per-server in opencode. There's an `experimental.mcp_timeout` for all servers. |
| `trust` | — | opencode uses permissions instead. Drop; the user grants tool access at runtime. |
| `description` | — | Drop (opencode ignores it). |
| `includeTools` / `excludeTools` | — | Not supported. Drop; opencode surfaces all tools from an MCP. |
| `authProviderType` | — | Not supported. Drop. |
| `oauth` (Tabnine's built-in OAuth flow) | — | Drop. opencode expects the MCP itself to handle OAuth on first connect. |

Per-server enablement (`~/.tabnine/agent/mcp-server-enablement.json`):

```
{ name: { enabled: false } }   →   mcp[name].enabled: false
```

Absent name → `enabled: true` (opencode default; you can omit the field).

### Example translation

Source (`~/.tabnine/agent/settings.json`):

```json
{
  "mcpServers": {
    "AtlassianMCP": { "url": "https://mcp.atlassian.com/v1/mcp" },
    "playwright":   { "command": "npx", "args": ["-y", "@playwright/mcp"] }
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
      "enabled": false
    }
  }
}
```

## Skills

Direct copy. Both systems use `SKILL.md` with the same required frontmatter fields (`name`, `description`).

Do not rewrite:

- Skill bodies. If a skill references Gemini binaries, that's a semantic change and the user should decide.
- The `name` field. It must stay unique across all scanned paths; opencode logs a warning on collision.

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
| `tools` | — | Drop. opencode uses `permission` (per-tool allow/ask/deny). If the user wants an equivalent, ask before generating a permission block; don't guess. |
| `mcp_servers` | — | Drop from the agent frontmatter. Ask the user if these should be hoisted into top-level `mcp` in `opencode.json` (they'll then be visible to all agents, not just this one). |
| `model: inherit` | — | Drop. Subagents inherit from parent by default; primaries fall back to global `model`. |
| `model: <provider>/<id>` | `model` | Keep if the value is already `provider/model-id` format. |
| `model: <plain name>` (e.g. `claude-4-opus`, `Claude 4.8 Opus`) | — | Drop. opencode requires the provider prefix; a plain name will fail validation. |
| `temperature` | `temperature` | Keep. |
| `max_turns` | `steps` | Rename. Preserve integer value. |
| `timeout_mins` | — | Drop. No opencode equivalent. Note this to the user. |
| — | `mode` | Add. Value from the wizard's Phase-2 per-agent prompt (`subagent` or `primary`). |

Body → agent prompt, no changes.

### Remote (A2A) agents

opencode has no built-in A2A remote agent kind. Two options:

1. **Skip** with a warning. Simplest.
2. If the remote agent is really important, offer to create a subagent whose body calls the remote via `webfetch` or a bespoke MCP. This is a manual step — do not auto-generate.

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

Target (`~/.config/opencode/agent/jira-issue-manager.md`), with the user picking `subagent` mode:

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

### Namespacing

Tabnine command namespaces (from nested folders) use `:` (e.g. `foo:bar`). opencode uses folder structure directly (`command/foo/bar.md` → `/foo/bar`) or filename-mangling. Either preserve the folder structure or flatten with a hyphen — ask the user.

## Extensions

opencode has no extension bundle format. Unpack:

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
