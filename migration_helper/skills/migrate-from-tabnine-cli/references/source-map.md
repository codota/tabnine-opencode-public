# Tabnine CLI configuration map

Where Tabnine CLI reads each category of configuration from, and how those pieces combine.

## Contents

- Configuration directory
- MCP servers (settings tiers, extensions, agent-declared, built-ins, enablement, filters)
- Skills (discovery order, filename requirements, gating)
- Agents (discovery order, local frontmatter, remote frontmatter, overrides)
- Commands (discovery order, placeholders)
- Post-migration notes

## Configuration directory

Tabnine CLI stores configuration under `.tabnine/agent/`. Two roots are read:

- User: `~/.tabnine/agent/`
- Workspace: `<cwd>/.tabnine/agent/`

Development builds may resolve to `.tabnine-dev/agent/` (or the value of `TABNINE_DEV_CONFIG_DIR`) when `TABNINE_NODE_ENV=development` is set. This is not common on end-user machines; check it only when discovery finds no expected files at the standard paths.

## MCP servers

MCP servers come from four sources and only these four. There is no `.mcp.json`, no `mcp_servers.json`, no `.tabnine/mcp_servers.json`.

### Source 1: `mcpServers` key in settings.json

Settings are read from four tiers and deep-merged:

| Tier | Path |
| --- | --- |
| System | `/Library/Application Support/TabnineCli/settings.json` (macOS), `C:\ProgramData\tabnine-cli\settings.json` (Windows), `/etc/tabnine-cli/settings.json` (Linux). Overridable via `TABNINE_CLI_SYSTEM_SETTINGS_PATH`. |
| System defaults | Same directory as System, filename `system-defaults.json`. Env: `TABNINE_CLI_SYSTEM_DEFAULTS_PATH`. |
| User | `~/.tabnine/agent/settings.json` |
| Workspace | `<cwd>/.tabnine/agent/settings.json` |

Read the `mcpServers` object from each. Merge precedence: schema defaults → system defaults → user → workspace → **system last, which wins over everything** — on managed machines an admin's system settings override the user's. The wizard should read at minimum User and Workspace; if a system file exists, mention that its entries take precedence in Tabnine and may be admin-managed (probably not the user's to migrate).

Shape of each entry:

```json
{
  "url":     "https://…",         // remote SSE/HTTP
  "httpUrl": "https://…",         // alternate remote key some servers use
  "command": "npx",               // local — a single string, not an array
  "args":    ["-y", "some-mcp"],  // local — array of strings
  "env":     { "KEY": "VAL" },
  "cwd":     "/path",
  "headers": { "Authorization": "…" },
  "type":    "sse" | "http",
  "timeout": 30000,
  "trust":   true,
  "description":  "…",
  "includeTools": ["tool_a"],
  "excludeTools": ["tool_b"],
  "authProviderType": "…",
  "oauth": { … }
}
```

### Source 2: Extensions

Extensions live at `~/.tabnine/agent/extensions/<name>/` and `<cwd>/.tabnine/agent/extensions/<name>/`. Manifest filename: `tabnine-extension.json`.

Manifest schema: `{ name, version, mcpServers?, contextFileName?, excludeTools?, settings?, themes?, plan? }`. Install metadata lives in a separate sibling file (`.tabnine-extension-install.json`), not in the manifest. Extensions can also ship `<ext>/skills/`, `<ext>/agents/`, `<ext>/commands/` directories that the loaders pick up.

Per-extension enable/disable state lives in `~/.tabnine/agent/extensions/extension-enablement.json` — skip disabled extensions by default when unpacking.

### Source 3: Agent-declared MCP servers (`mcp_servers` frontmatter)

Local agents can embed `mcp_servers:` in their YAML frontmatter. These are scoped to that agent only. opencode has no equivalent — surface them to the user and offer to hoist them into top-level `mcp`.

### Source 4: Tabnine built-in MCP servers

Tabnine CLI ships two built-in MCP servers:

- `tabnine-context` → `{tabnineHost}/indexer/mcp`
- `tabnine-coaching` → `{tabnineHost}/coaching/api/mcp`

These are already the same servers opencode's Tabnine plugin registers. **Do not migrate them** — they would conflict with the plugin.

### Per-server enablement

`~/.tabnine/agent/mcp-server-enablement.json`:

```json
{
  "server-name": { "enabled": false }
}
```

Absence of a key means enabled. This is user disables, not admin policy. Apply directly to opencode's `mcp.<name>.enabled`.

Gotchas: keys are normalized to lowercase/trimmed, so match server names case-insensitively; extension-bundled servers appear as `ext:<name>` (plain `<name>` is also accepted); stale keys with no matching server can linger after a server is deleted — ignore them.

### Additional filters (rarely present, worth checking)

Settings can also carry `mcp.allowed` (allowlist) and `mcp.excluded` (blocklist) arrays, and `admin.mcp.enabled` (kill switch). If any of these are set, respect them when building the migration list: do not migrate servers the user has explicitly excluded, and warn if `admin.mcp.enabled: false` is set (Tabnine had MCPs disabled entirely — the user probably still wants to migrate the definitions, but should know).

## Skills

Discovery order (later overrides earlier on name conflict):

1. Built-in skills bundled with Tabnine CLI — **do not migrate**, opencode has its own built-ins.
2. Extension skills: `<extension>/skills/*/SKILL.md`.
3. User skills: `~/.tabnine/agent/skills/*/SKILL.md`.
4. User agent-alias: `~/.agents/skills/*/SKILL.md` (a plain `.agents` folder — not `.claude`).
5. Workspace skills: `<cwd>/.tabnine/agent/skills/*/SKILL.md` (trusted folders only).
6. Workspace agent-alias: `<cwd>/.agents/skills/*/SKILL.md` (trusted only).

Filename requirement: `SKILL.md` must be uppercase, at the root of the skill directory or one level deep. Only `name` (required) and `description` (required) are checked in frontmatter — same requirements as opencode, so bodies copy verbatim.

Skill names have **no format regex** in Tabnine (only filesystem-hostile characters `: \ / < > * ? " |` are sanitized to `-`), so underscores, uppercase, and spaces can appear. opencode's code accepts these too, but its documented contract is `^[a-z0-9]+(-[a-z0-9]+)*$` — see the normalization step in the skill.

Settings that gate skills:

- `skills.enabled` (bool, default true) — kill switch, requires restart.
- `skills.disabled` (string[]) — names to skip at runtime.

There is **no** `skills.paths` or `skills.urls` setting in Tabnine CLI. Skills live only in the six directories above.

## Agents

Discovery order (first-registered wins for duplicate names, unlike skills):

1. Built-in agents shipped with Tabnine CLI. **Do not migrate.**
2. Project agents: `<cwd>/.tabnine/agent/agents/*.md` (trusted folders + per-agent acknowledgement).
3. User agents: `~/.tabnine/agent/agents/*.md`.
4. Extension agents: `<extension>/agents/*.md`.

The directory scan is **non-recursive** and only picks up top-level `*.md`. Files starting with `_` are ignored.

### Local agent frontmatter

Strict — unknown keys are rejected. Keys are snake_case in YAML.

```yaml
kind: local            # optional, defaults to 'local'
name: string           # required, /^[a-z0-9-_]+$/
description: string    # required
display_name: string   # optional
tools: [string, …]     # optional, tool-name allowlist (wildcards allowed)
mcp_servers:           # optional, private MCPs for this agent
  name:
    command: …
    args: …
    env: …
    url: …
    http_url: …
    headers: …
    type: sse | http
    timeout: …
    trust: …
    description: …
    include_tools: …
    exclude_tools: …
    auth: { type: google-credentials | oauth, … }
model: string          # optional, default 'inherit'
temperature: number    # optional, default 1
max_turns: int         # optional, default 30
timeout_mins: int      # optional, default 10
```

Body (post-frontmatter) is the agent's system prompt.

### Remote (A2A) agent frontmatter

```yaml
kind: remote
name: string
description: string    # optional (falls back to Agent Card)
display_name: string   # optional
auth:                  # optional
  type: apiKey | http | google-credentials | oauth
  …
agent_card_url: url    # exactly one of these two required
agent_card_json: string
```

Array frontmatter is also accepted (multiple remote agents in one file). Discovery implication: if the first frontmatter block of an agent `.md` parses as a YAML array, treat the whole file as a remote-agent bundle immediately — don't try to read `name`/`description` off it. opencode has no direct equivalent for A2A agents — skip these with a warning, or convert to a subagent that calls the remote endpoint via a tool if the user asks.

### Agent overrides in settings

`agents.overrides` lets the user override any registered agent's `enabled` / `modelConfig` / `runConfig` / `tools` / `mcpServers`. Read these when translating so the effective config is what gets migrated, not just what is in the `.md`.

## Commands

Format: TOML with `prompt` (required) and `description` (optional).

Discovery order (later can conflict with earlier):

1. User: `~/.tabnine/agent/commands/`
2. Workspace: `<cwd>/.tabnine/agent/commands/`
3. Extensions: `<extension>/commands/`

Files are TOML. Nested folders become namespaced names (colon separator, e.g. `commands/foo/bar.toml` → `foo:bar`). Placeholders inside `prompt`:

- `{{args}}` — Tabnine's shorthand for all args
- `!{shell command}` — shell injection
- `@{file/path}` — file injection

Skill-as-command loader also exposes each skill as a slash command that activates the skill — that is not a "command" for migration purposes.

## Post-migration notes

- opencode's Tabnine plugin already registers `tabnine-context` and `tabnine-coaching` MCP servers. Do not migrate those.
- opencode's Tabnine plugin already provides Tabnine authentication, so `~/.tabnine/tabnine_creds.json` and `~/.tabnine/agent/tabnine-credentials.json` should not be touched.
- OAuth tokens in `~/.tabnine/agent/mcp-oauth-tokens.json` are Tabnine-CLI-specific and will not carry over to opencode. The user re-authenticates each MCP on first use.
- Context/memory files (`TABNINE.md` at the project root and `~/.tabnine/agent/TABNINE.md` globally, plus any custom `context.fileName` names) are handled by the separate `migrate-tabnine-context` skill (`/migrate-context`), not this wizard. If discovery notices them, point the user there.
