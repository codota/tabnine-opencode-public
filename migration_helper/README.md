# Migration helper: Tabnine CLI to opencode

Copies your Tabnine CLI configuration into an opencode configuration directory. These are interactive wizards that run inside opencode: each one scans your disk, shows what it found, and asks what you want to migrate.

Every write is shown to you for approval before it happens, and no existing file is replaced without your consent and a timestamped backup.

Nothing is deleted from your Tabnine CLI installation. This is a copy-and-translate flow. You can keep using Tabnine CLI after.

Two skills are included:

- **`migrate-from-tabnine-cli`** (`/migrate`) — MCP servers, skills, subagents, slash commands, and extension contents. Run once per target scope (global or project).
- **`migrate-tabnine-context`** (`/migrate-context`) — context/memory files (`TABNINE.md`, or custom `context.fileName` files) into opencode's `AGENTS.md`. Re-runnable in every repository you work in.

## What gets migrated

MCP servers, skills, subagents, slash commands, the contents of Tabnine CLI extensions, and context files (`TABNINE.md` → `AGENTS.md`, via the second skill). Fields with no opencode equivalent are dropped and listed in the summary. See `skills/migrate-from-tabnine-cli/references/mapping.md` for the complete field-by-field translation table.

Two translations change values rather than copying them, and the wizard reports both when it runs.

Agent tool restrictions are preserved. A Tabnine agent that limits itself to a list of tools becomes an opencode agent with an equivalent `permission` block, so a restricted agent stays restricted after migration. The two systems name their tools differently and a few names cover more ground in opencode than in Tabnine CLI, so the wizard shows you the resulting permissions and flags any tool that gains access it did not have before.

MCP server timeouts are written explicitly. Tabnine CLI allows an MCP request 10 minutes by default and opencode allows 5 seconds, so the wizard records the original 10-minute value instead of letting a migrated server inherit a much shorter one.

### Tabnine's built-in MCP servers

Two MCP servers ship inside Tabnine CLI: `tabnine-context` (Remote Codebase Search) and `tabnine-coaching` (Coaching Guidelines). opencode's Tabnine plugin registers both automatically, so the wizard never copies them into `opencode.json`. If either was disabled in Tabnine, the wizard tells you how to keep it disabled in opencode — by setting `enableRemoteCodeSearch: false` or `enableCoaching: false` in the plugin's options, or by setting `TABNINE_ENABLE_REMOTE_CODE_SEARCH=0` / `TABNINE_ENABLE_COACHING=0` in your environment.

### Tabnine sign-in does not carry over

opencode's Tabnine plugin uses its own credential storage, so your Tabnine CLI sign-in cannot be reused. After running the migration, sign in to opencode's Tabnine plugin the way you would on a fresh install. The wizard never copies credential files.

## What does NOT get migrated

OAuth tokens (`~/.tabnine/agent/mcp-oauth-tokens.json`), Tabnine credentials, and Tabnine-specific admin policy fields — you will re-authenticate each remote MCP server on first use. Also out of scope: hooks, themes, keybindings, and general settings (model selection, approval mode); configure those directly in opencode.

## Prerequisites

An installed and working opencode. The wizard is a skill that loads inside opencode; the installer below only copies files into place.

The installer script requires `bash` and standard coreutils (`cp`, `mv`, `mkdir`, `cmp`, `diff`, `find`, `date`), which are present on macOS and Linux. Windows users should follow the manual copy instructions below.

## Install with the script

Clone the repo and run the installer:

```bash
git clone https://github.com/codota/tabnine-opencode-public
cd tabnine-opencode-public/migration_helper
./install.sh
```

By default this installs globally into `~/.config/opencode/`. To install into the current project instead:

```bash
./install.sh --project
```

To overwrite existing files without diff prompts:

```bash
./install.sh --overwrite
```

When a target file already exists and differs from the incoming copy, the installer prints a unified diff and asks whether to skip, overwrite, or rename the existing file with a timestamped `.bak-YYYYMMDD-HHMMSS` suffix before installing the new one.

## Install manually

Manual copy is a fully supported alternative. It is the recommended path on Windows and works on macOS and Linux equally well.

For a global install on macOS or Linux:

```bash
mkdir -p ~/.config/opencode/skills ~/.config/opencode/commands
cp -r migration_helper/skills/migrate-from-tabnine-cli migration_helper/skills/migrate-tabnine-context ~/.config/opencode/skills/
cp migration_helper/commands/migrate.md migration_helper/commands/migrate-context.md ~/.config/opencode/commands/
```

For a project install on macOS or Linux:

```bash
mkdir -p .opencode/skills .opencode/commands
cp -r migration_helper/skills/migrate-from-tabnine-cli migration_helper/skills/migrate-tabnine-context .opencode/skills/
cp migration_helper/commands/migrate.md migration_helper/commands/migrate-context.md .opencode/commands/
```

For a global install on Windows (PowerShell):

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\skills", "$env:USERPROFILE\.config\opencode\commands" | Out-Null
Copy-Item -Recurse migration_helper\skills\migrate-from-tabnine-cli, migration_helper\skills\migrate-tabnine-context "$env:USERPROFILE\.config\opencode\skills\"
Copy-Item migration_helper\commands\migrate.md, migration_helper\commands\migrate-context.md "$env:USERPROFILE\.config\opencode\commands\"
```

If any of the target files already exist, back them up first. The installer script does this automatically; the manual commands above do not.

## Usage after install

Quit and restart opencode so it picks up the new skills and slash commands. opencode does not hot-reload its configuration.

Once restarted, run the config wizard in either of two ways:

Run the slash command directly:

```
/migrate
```

Or ask opencode in natural language:

```
migrate my tabnine cli config to opencode
```

Either entry point activates the same skill. The wizard runs in four steps:

1. **Discover** — scans for Tabnine CLI configuration and prints an inventory of what it found.
2. **Ask** — one question per category: target scope, MCP servers, skills, subagents, commands, and extensions.
3. **Plan** — shows exactly what it intends to do before doing any of it: the target directory, every file it will create, overwrite, or back up, the MCP servers it will connect, and any change to an agent's permissions. Nothing has been written yet, and it waits for your approval.
4. **Write** — carries out the approved plan, then reports what was written and anything that differed from the plan.

Selecting categories in step 2 does not authorize any write; only your approval in step 3 does. To preview a migration without performing one, ask for the plan and stop there.

Credentials are handled carefully throughout. The wizard prints the names of environment variables and request headers but never their values, and if an MCP server has a password or token written directly into its configuration, it offers to replace it with an `{env:VAR}` reference rather than copying the secret into `opencode.json`.

To migrate your `TABNINE.md` context files into `AGENTS.md`, run `/migrate-context` (or ask "migrate my tabnine context files"). That skill is scoped per repository, so re-run it in each project whose context files you want to bring over. It follows the same plan-then-approve flow, and because a merge appends to an `AGENTS.md` you already rely on, it backs up the existing file first.

Context in a subdirectory is worth a moment's attention. Both tools read your global context file and every context file from the current directory up to the project root. They differ further down: Tabnine CLI picks up a subdirectory's context whenever the agent works in that subtree, while opencode reads context from the session's directory upward only. A file migrated to `packages/api/AGENTS.md` therefore applies when you start opencode inside `packages/api`, but not from the repository root. The wizard points this out for each such file and offers to fold its content into the project-root `AGENTS.md` instead, which makes it always apply at the cost of widening its scope to the whole repository.

## Uninstall

Remove the paths the installer created:

```bash
rm -rf ~/.config/opencode/skills/migrate-from-tabnine-cli ~/.config/opencode/skills/migrate-tabnine-context
rm ~/.config/opencode/commands/migrate.md ~/.config/opencode/commands/migrate-context.md
```

For a project install, replace `~/.config/opencode` with `.opencode`. Restart opencode after.

## Troubleshooting

The most common issue is forgetting to restart. opencode loads skills and commands at startup. If `/migrate` is not recognized or the wizard behaviour is stale, quit opencode fully and start it again.

To confirm that opencode picked up a migration, ask the wizard to check it for you, or inspect the loaded configuration directly. These commands list the active config directory, every skill opencode has loaded with the file it came from, and the available agents:

```bash
opencode debug paths
opencode debug skill
opencode agent list
```

Each command reads the configuration from disk, so it reflects a migration immediately. If a migrated item appears here but an open session still behaves as it did before, restart that session.

If opencode fails to start after the migration with a `ConfigInvalidError`, one of the migrated fields has been rejected. If you migrated into a project (`.opencode/`), start opencode with project config disabled so you can fix it:

```bash
OPENCODE_DISABLE_PROJECT_CONFIG=1 opencode
```

This does not bypass the global `~/.config/opencode/` config — for a global install, edit (or restore the timestamped backup of) the offending file directly, using the field-by-field rules in `skills/migrate-from-tabnine-cli/references/mapping.md` as a reference.

A `duplicate skill name` warning (written to opencode's log, not shown in the UI) means two skills share the same `name` field under paths opencode scans (`~/.config/opencode/skills/`, `~/.claude/skills/`, `~/.agents/skills/`, the directory named by `OPENCODE_CONFIG_DIR` if it is set, and the equivalent workspace paths). opencode keeps the last copy it scans and silently shadows the other, so remove or rename one of them. The log line names both paths.

If your launcher sets `OPENCODE_CONFIG_DIR`, as the Tabnine opencode wrapper does, that directory is read in addition to `~/.config/opencode` rather than instead of it. opencode loads skills, agents, and `opencode.json` from both. Installing into `~/.config/opencode` therefore works either way, but avoid installing the same item into both directories, since one copy will shadow the other.

## Reference documents

Inside `skills/migrate-from-tabnine-cli/references/`:

- `mapping.md` — the field-by-field translation tables, including the agent tool-name map and the MCP field rules. Consult this when checking or hand-fixing a migrated value.
- `source-map.md` — every Tabnine CLI configuration path, and which one takes precedence when the same setting appears in more than one.
- `verification-and-recovery.md` — the post-migration verification commands and the recovery steps for a failed or partial migration.

## License

Licensed under the MIT License. See `LICENSE`.
