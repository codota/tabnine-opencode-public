# Migration helper: Tabnine CLI to opencode

Copies your Tabnine CLI (or Gemini CLI) configuration into an opencode configuration directory. Runs as an interactive wizard inside opencode itself: it scans your disk, shows what it found, asks per-category what to migrate, translates fields that differ between the two systems, and never overwrites an existing file without asking.

Nothing is deleted from your Tabnine CLI installation. This is a copy-and-translate flow. You can keep using Tabnine CLI after.

## What gets migrated

MCP servers, skills, subagents, slash commands, and the contents of Tabnine CLI extensions. Fields that have no opencode equivalent are dropped with a note. See `skills/migrate-from-tabnine-cli/references/mapping.md` for the complete field-by-field translation table.

## What does NOT get migrated

OAuth tokens (`~/.tabnine/agent/mcp-oauth-tokens.json`), Tabnine credentials, and Tabnine-specific admin policy fields. You will re-authenticate each remote MCP server on first use.

## Prerequisites

An installed and working opencode. The wizard is a skill that loads inside opencode; the installer below only copies files into place.

The installer script requires `bash`, `cp`, `diff`, and `mv`, which are standard on macOS and Linux. Windows users should follow the manual copy instructions below.

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
cp -r migration_helper/skills/migrate-from-tabnine-cli ~/.config/opencode/skills/
cp migration_helper/commands/migrate.md ~/.config/opencode/commands/migrate.md
```

For a project install on macOS or Linux:

```bash
mkdir -p .opencode/skills .opencode/commands
cp -r migration_helper/skills/migrate-from-tabnine-cli .opencode/skills/
cp migration_helper/commands/migrate.md .opencode/commands/migrate.md
```

For a global install on Windows (PowerShell):

```powershell
Copy-Item -Recurse migration_helper\skills\migrate-from-tabnine-cli "$env:USERPROFILE\.config\opencode\skills\"
Copy-Item migration_helper\commands\migrate.md "$env:USERPROFILE\.config\opencode\commands\migrate.md"
```

If any of the target files already exist, back them up first. The installer script does this automatically; the manual commands above do not.

## Usage after install

Quit and restart opencode so it picks up the new skill and slash command. opencode does not hot-reload its configuration.

Once restarted, run the wizard in either of two ways:

Run the slash command directly:

```
/migrate
```

Or ask opencode in natural language:

```
migrate my tabnine cli config to opencode
```

Either entry point activates the same skill. The wizard scans for Tabnine CLI configuration, prints a compact inventory, and then asks you category by category (MCP servers, skills, subagents, commands, extensions) which items to migrate and where to write them.

## Uninstall

Remove the two paths the installer created:

```bash
rm -rf ~/.config/opencode/skills/migrate-from-tabnine-cli
rm ~/.config/opencode/commands/migrate.md
```

For a project install, replace `~/.config/opencode` with `.opencode`. Restart opencode after.

## Troubleshooting

The most common issue is forgetting to restart. Opencode loads skills and commands at startup. If `/migrate` is not recognized or the wizard behaviour is stale, quit opencode fully and start it again.

If opencode fails to start after the migration with a `ConfigInvalidError`, one of the migrated fields has been rejected. Recover with either of these:

```bash
OPENCODE_DISABLE_PROJECT_CONFIG=1 opencode
```

Or edit the offending file directly, using the field-by-field rules in `skills/migrate-from-tabnine-cli/references/mapping.md` as a reference.

A `duplicate skill name` warning at load time means two skills with the same `name` field exist under paths opencode scans (`~/.config/opencode/skills/`, `~/.claude/skills/`, and the equivalent workspace paths). Rename one or delete the older copy.

## License

Licensed under the MIT License. See `LICENSE`.
