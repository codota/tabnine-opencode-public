# Migration helper: Tabnine CLI to opencode

Copies your Tabnine CLI (or Gemini CLI) configuration into an opencode configuration directory. Runs as interactive wizards inside opencode itself: they scan your disk, show what they found, ask what to migrate, translate fields that differ between the two systems, and never overwrite an existing file without asking.

Nothing is deleted from your Tabnine CLI installation. This is a copy-and-translate flow. You can keep using Tabnine CLI after.

Two skills are included:

- **`migrate-from-tabnine-cli`** (`/migrate`) — MCP servers, skills, subagents, slash commands, and extension contents. Run once per target scope (global or project).
- **`migrate-tabnine-context`** (`/migrate-context`) — context/memory files (`TABNINE.md`, `GEMINI.md`, or custom `context.fileName` files) into opencode's `AGENTS.md`. Re-runnable in every repository you work in.

## What gets migrated

MCP servers, skills, subagents, slash commands, the contents of Tabnine CLI extensions, and context files (`TABNINE.md` → `AGENTS.md`, via the second skill). Fields that have no opencode equivalent are dropped with a note. See `skills/migrate-from-tabnine-cli/references/mapping.md` for the complete field-by-field translation table.

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

Either entry point activates the same skill. The wizard scans for Tabnine CLI configuration, prints a compact inventory, and then asks you category by category (MCP servers, skills, subagents, commands, extensions) which items to migrate and where to write them.

To migrate your `TABNINE.md` context files into `AGENTS.md`, run `/migrate-context` (or ask "migrate my tabnine context files"). That skill is scoped per repository — re-run it in each project whose context files you want to bring over.

## Uninstall

Remove the paths the installer created:

```bash
rm -rf ~/.config/opencode/skills/migrate-from-tabnine-cli ~/.config/opencode/skills/migrate-tabnine-context
rm ~/.config/opencode/commands/migrate.md ~/.config/opencode/commands/migrate-context.md
```

For a project install, replace `~/.config/opencode` with `.opencode`. Restart opencode after.

## Troubleshooting

The most common issue is forgetting to restart. opencode loads skills and commands at startup. If `/migrate` is not recognized or the wizard behaviour is stale, quit opencode fully and start it again.

If opencode fails to start after the migration with a `ConfigInvalidError`, one of the migrated fields has been rejected. If you migrated into a project (`.opencode/`), start opencode with project config disabled so you can fix it:

```bash
OPENCODE_DISABLE_PROJECT_CONFIG=1 opencode
```

This does not bypass the global `~/.config/opencode/` config — for a global install, edit (or restore the timestamped backup of) the offending file directly, using the field-by-field rules in `skills/migrate-from-tabnine-cli/references/mapping.md` as a reference.

A `duplicate skill name` warning (written to opencode's log, not shown in the UI) means two skills share the same `name` field under paths opencode scans (`~/.config/opencode/skills/`, `~/.claude/skills/`, `~/.agents/skills/`, the directory named by `OPENCODE_CONFIG_DIR` if it is set, and the equivalent workspace paths). opencode keeps the last copy it scans and silently shadows the other, so remove or rename one of them. The log line names both paths.

If your launcher sets `OPENCODE_CONFIG_DIR` (the Tabnine opencode wrapper points it at `~/.tabnine/opencode/config`), note that it *adds* a config root rather than replacing the default one. `opencode debug paths` still reports `~/.config/opencode` as the config root, and skills, agents, and `opencode.json` are loaded from both directories. Installing into `~/.config/opencode/` works either way; just don't install the same items into both roots.

## License

Licensed under the MIT License. See `LICENSE`.
