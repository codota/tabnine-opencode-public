# Verification and recovery

## Verification (optional, only when the user asks)

Skip this entirely unless the user asks for it.

These commands each start a fresh process and read config from disk, so they report the migrated state immediately — a restart is not needed for them to be accurate. The restart is needed for the user's own *running* session, which keeps the config it loaded at launch. So a green result here plus a still-broken session means "restart", not "migration failed".

Three commands settle whether opencode actually loaded the migration. Run them from the project directory, and export `OPENCODE_CONFIG_DIR` first if the user's launcher sets it, so you reproduce their real environment:

```
opencode debug paths    # confirms which directory is the global config root
opencode debug skill    # JSON: every loaded skill with its resolved location
opencode agent list     # loaded agents and their mode
opencode debug agent <name>   # one agent's resolved mode, steps, model, prompt
```

Check that each migrated skill appears with a `location` under the target you wrote to, that its `description` and `content` are non-empty (proves the frontmatter parsed), and that each migrated agent is listed with the mode the user chose. `debug agent` additionally confirms `steps` survived the `max_turns` rename and that no stale `model` is pinned.

Then verify three things on disk, which no command covers:

1. Each migrated skill folder is byte-identical to its Tabnine source (a diff of the folders returns nothing), except where the user approved an edit.
2. Every relative `references/…` or `scripts/…` path mentioned in a migrated body resolves to a file that exists.
3. No skill `name` appears in more than one scanned root.

Report failures as findings and ask before changing anything — Phase 4 already ended the write window (core rule 7).

## When things go wrong

- **`ConfigInvalidError` on startup after migration**: the user's `opencode.json` has a rejected field. Recover with `OPENCODE_DISABLE_PROJECT_CONFIG=1 opencode` (project) or by manually editing the global file. Point them at the escape hatches in the `customize-opencode` skill.
- **A migrated skill behaves inconsistently or seems to "flip" between versions**: two skills with the same `name` exist in scanned paths. opencode logs `duplicate skill name` with both locations and keeps the last one scanned; the earlier copy is shadowed silently. Check the log for the two paths, then rename or delete one.
- **`ConfigInvalidError` after the MCP merge specifically**: restore the `opencode.json.bak-<timestamp>` backup written before the merge, then retry.
- **MCP server appears but returns auth errors**: normal on first use — re-authenticate via the MCP's OAuth flow. Do not attempt to copy tokens from `~/.tabnine/agent/mcp-oauth-tokens.json`.
- **User wants to reverse the migration**: the wizard doesn't delete Tabnine sources, so reversing means deleting the newly created files under `<target>/{mcp entries, skills/*, agents/*.md, command/*.md}`. Offer to list them if asked.
