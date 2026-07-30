# Tabnine CLI source map

Verified against the Tabnine CLI source. All paths resolve `GEMINI_DIR = .tabnine/agent` in Tabnine mode (default) or `.gemini` in original Gemini mode.

## Contents

- Config directory resolution
- MCP servers (settings tiers, extensions, agent-declared, built-ins, enablement, filters)
- Skills (discovery order, filename glob, frontmatter, gating settings)
- Agents (discovery order, local frontmatter, remote A2A frontmatter, overrides)
- Commands (loader, discovery order, placeholders)
- Post-migration reminders

## Config directory resolution

`packages/core/src/utils/paths.ts:14-20` sets the config directory based on build/env:

- Default (Tabnine mode): `.tabnine/agent`
- `ORIG_GEMINI` build flag: `.gemini`
- `TABNINE_NODE_ENV=development`: `.tabnine-dev/agent` (or the value of `TABNINE_DEV_CONFIG_DIR`)
- Home dir can be overridden with `GEMINI_CLI_HOME`

Assume Tabnine mode unless the user says otherwise. If they mention "Gemini CLI" specifically, also check `~/.gemini/` and `<cwd>/.gemini/` with the same subdirectory layout.

## MCP servers

MCP servers come from four sources and only these four. There is no `.mcp.json`, no `mcp_servers.json`, no `.tabnine/mcp_servers.json`.

### Source 1: `mcpServers` key in settings.json

Settings are loaded from four tiers, deep-merged (`packages/cli/src/config/settings.ts:781-950`):

| Tier | Path |
| --- | --- |
| System | `/Library/Application Support/TabnineCli/settings.json` (macOS), `C:\ProgramData\tabnine-cli\settings.json` (Windows), `/etc/tabnine-cli/settings.json` (Linux). Overridable via `TABNINE_CLI_SYSTEM_SETTINGS_PATH`. |
| System defaults | Same directory as System, filename `system-defaults.json`. Env: `TABNINE_CLI_SYSTEM_DEFAULTS_PATH`. |
| User | `~/.tabnine/agent/settings.json` |
| Workspace | `<cwd>/.tabnine/agent/settings.json` |

Read the `mcpServers` object from each; workspace wins. The wizard should read at minimum User and Workspace.

Shape of each entry (`packages/cli/src/config/settingsSchema.ts:161-174`, values from Gemini upstream `MCPServerConfig`):

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

Extensions live at `~/.tabnine/agent/extensions/<name>/` and `<cwd>/.tabnine/agent/extensions/<name>/`. Manifest filename: `tabnine-extension.json` in Tabnine mode, `gemini-extension.json` in Gemini mode (`packages/core/src/config/storage.ts:446-456`).

Manifest schema (`packages/cli/src/config/extension.ts:24-49`): `{ name, version, mcpServers?, contextFileName?, excludeTools?, installMetadata? }`. Extensions can also ship `<ext>/skills/`, `<ext>/agents/`, `<ext>/commands/` directories that the extension loader picks up (`packages/cli/src/config/extension-manager.ts:837-994`).

### Source 3: Agent-declared MCP servers (`mcp_servers` frontmatter)

Local agents can embed `mcp_servers:` in their YAML frontmatter (`packages/core/src/agents/agentLoader.ts:54-90`). These are scoped to that agent only. opencode has no equivalent — surface them to the user and offer to hoist them into top-level `mcp`.

### Source 4: Tabnine built-in MCP servers (code-registered)

`packages/core/src/tabnine/mcp/builtin-mcp-servers.ts` registers:

- `tabnine-context` → `{tabnineHost}/indexer/mcp`
- `tabnine-coaching` → `{tabnineHost}/coaching/api/mcp`

These are already the same servers opencode's Tabnine plugin registers. **Do not migrate them** — they'd conflict with the plugin.

### Per-server enablement

`~/.tabnine/agent/mcp-server-enablement.json` (`packages/cli/src/config/mcp/mcpServerEnablement.ts`):

```json
{
  "server-name": { "enabled": false }
}
```

Absence of a key means enabled. This is user disables, not admin policy. Apply directly to opencode's `mcp.<name>.enabled`.

### Additional filters (rarely present, worth checking)

Settings can also carry `mcp.allowed` (allowlist) and `mcp.excluded` (blocklist) arrays (`settingsSchema.ts:1916-1955`), and `admin.mcp.enabled` (kill switch). If any of these are set, respect them when building the migration list: don't migrate servers the user has explicitly excluded, and warn if `admin.mcp.enabled: false` is set (Tabnine had MCPs disabled entirely — the user probably still wants to migrate the definitions, but should know).

## Skills

Loader: `packages/core/src/skills/skillLoader.ts`. Discovery order in `packages/core/src/skills/skillManager.ts:54-99` (later overrides earlier on name conflict):

1. Built-in skills bundled in `packages/core/src/skills/builtin/*` — **do not migrate**, opencode has its own built-ins.
2. Extension skills: `<extension>/skills/*/SKILL.md`.
3. User skills: `~/.tabnine/agent/skills/*/SKILL.md`.
4. User agent-alias: `~/.agents/skills/*/SKILL.md` (a plain `.agents` folder — not `.claude`).
5. Workspace skills: `<cwd>/.tabnine/agent/skills/*/SKILL.md` (trusted folders only).
6. Workspace agent-alias: `<cwd>/.agents/skills/*/SKILL.md` (trusted only).

Filename glob (`skillLoader.ts:127`): `['SKILL.md', '*/SKILL.md']` — SKILL.md must be uppercase, at the root or one level deep in the skills dir.

Frontmatter validation: only `name` (required) and `description` (required) are checked (`skillLoader.ts:34-192`). Same requirements as opencode, so bodies copy verbatim.

Settings that gate skills:

- `skills.enabled` (bool, default true) — kill switch, requires restart.
- `skills.disabled` (string[]) — names to skip at runtime.

There is **no** `skills.paths` or `skills.urls` setting in Tabnine CLI. Skills live only in the six directories above.

## Agents

Loader: `packages/core/src/agents/agentLoader.ts`. Registry: `packages/core/src/agents/registry.ts:173-295`.

Discovery order (first-registered wins for duplicate names, unlike skills):

1. Built-in agents (registered in code) — `CodebaseInvestigatorAgent`, `GeneralistAgent`, `remote-codebase-investigator` (Tabnine), `BrowserAgentDefinition`, etc. **Do not migrate.**
2. Project agents: `<cwd>/.tabnine/agent/agents/*.md` (trusted folders + per-agent acknowledgement).
3. User agents: `~/.tabnine/agent/agents/*.md`.
4. Extension agents: `<extension>/agents/*.md`.

Directory scan (`agentLoader.ts:640-697`) is **non-recursive** and only picks up top-level `*.md`. Files starting with `_` are ignored.

### Local agent frontmatter (Zod schema at `agentLoader.ts:92-116`)

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

### Remote (A2A) agent frontmatter (`agentLoader.ts:208-243`)

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

Array frontmatter is also accepted (multiple remote agents in one file). opencode has no direct equivalent for A2A agents — skip these with a warning, or convert to a subagent that calls the remote endpoint via a tool if the user asks.

### Agent overrides in settings

`agents.overrides` (`settingsSchema.ts:1305-1437`) lets the user override any registered agent's `enabled` / `modelConfig` / `runConfig` / `tools` / `mcpServers`. Read these when translating so the effective config is what gets migrated, not just what's in the `.md`.

## Commands

Loader: `packages/cli/src/services/FileCommandLoader.ts:209-248`. Format: TOML with `prompt` (required) and `description` (optional).

Discovery order (later can conflict with earlier):

1. User: `~/.tabnine/agent/commands/`
2. Workspace: `<cwd>/.tabnine/agent/commands/`
3. Extensions: `<extension>/commands/`

Files are TOML. Nested folders become namespaced names (colon separator, e.g. `commands/foo/bar.toml` → `foo:bar`). Placeholders inside `prompt`:

- `{{args}}` — Tabnine's shorthand for all args
- `!{shell command}` — shell injection
- `@{file/path}` — file injection

Skill-as-command loader (`packages/cli/src/services/SkillCommandLoader.ts`) also exposes each skill as a slash command that activates the skill — that's not a "command" for migration purposes.

## Post-migration reminders

- opencode's Tabnine plugin already registers `tabnine-context` and `tabnine-coaching` MCP servers. Do not migrate those.
- opencode's Tabnine plugin already provides Tabnine authentication, so `~/.tabnine/tabnine_creds.json` and `~/.tabnine/agent/tabnine-credentials.json` should not be touched.
- OAuth tokens in `~/.tabnine/agent/mcp-oauth-tokens.json` are Tabnine-CLI-specific and will not carry over to opencode. The user re-authenticates each MCP on first use.
