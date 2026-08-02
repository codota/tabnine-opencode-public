---
name: migrate-tabnine-context
description: Migrates Tabnine CLI context/memory files (TABNINE.md, GEMINI.md, or custom context.fileName files) into opencode's AGENTS.md. Use ONLY when the user asks to migrate, import, or copy Tabnine CLI (or Gemini CLI) context files, memory files, TABNINE.md, or GEMINI.md into opencode or AGENTS.md. Re-runnable per repository. Not for MCP servers, skills, agents, or slash commands — that's the migrate-from-tabnine-cli skill.
---

# Migrate Tabnine CLI context files to opencode

You are migrating the user's Tabnine CLI context/memory files into opencode's `AGENTS.md` format. This skill is scoped per repository so it can be re-run in each project the user works on. The global file is offered too, but only needs migrating once.

## Core rules

1. **Never touch the source files.** Copy only. The user can keep using Tabnine CLI after.
2. **Never overwrite an existing `AGENTS.md` silently.** If the target exists, offer merge or skip.
3. **Never rewrite content.** Context files are instructions the user wrote; changing their wording changes behavior. Copy verbatim (a merge header line is the only text you add).
4. **Show what you found and ask before writing.**

## Phase 1 — Discover

1. Determine the context filename(s). Default is `TABNINE.md` (`GEMINI.md` if the user is on plain Gemini CLI). Check `context.fileName` in `~/.tabnine/agent/settings.json` and `<cwd>/.tabnine/agent/settings.json` — it may be a single string or an array of names (e.g. `["AGENTS.md", "TABNINE.md"]`).
2. Find source files:
   - **Project**: `<cwd>/<name>` for each configured name, plus subdirectory matches (`**/<name>`, skipping `node_modules`, `.git`, and other vendored dirs). Tabnine reads these hierarchically; opencode reads `AGENTS.md` per directory, so subdirectory files map to a sibling `AGENTS.md` in the same directory.
   - **Global**: `~/.tabnine/agent/TABNINE.md` (or the Gemini equivalent). Target: `~/.config/opencode/AGENTS.md`. Offer this only if it hasn't been migrated already — if the target exists and already contains the source content, report "already migrated" and skip.
3. If a configured name is already `AGENTS.md`, opencode reads it natively — report it as "no migration needed".

Print what was found (path, size, target) and ask which files to migrate. If nothing was found, say so and stop.

## Phase 2 — Write

For each selected source file, target is `AGENTS.md` in the same directory (project) or `~/.config/opencode/AGENTS.md` (global):

- **Target missing** → copy the content as-is.
- **Target exists** → ask: merge or skip. On merge, append to the existing `AGENTS.md`:

  ```markdown

  <!-- Migrated from TABNINE.md on YYYY-MM-DD -->

  <source file content, verbatim>
  ```

- If the source uses Tabnine's import syntax (`@./relative/path.md` lines), copy it unchanged and flag the file in the summary — opencode does not process Tabnine imports, so the user may want to inline or restructure those sections.

## Phase 3 — Summary

- List what was written, merged, and skipped, with paths.
- List any files flagged for import-syntax review.
- Remind the user: sources were not modified; re-run this skill in other repositories as needed.
- Restart reminder: "Restart opencode (or start a new session) to pick up the new AGENTS.md."
