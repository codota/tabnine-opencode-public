---
description: Migrate Tabnine CLI configuration into opencode.
---

Load the migrate-from-tabnine-cli skill and run the interactive migration wizard.

Scan the user's disk for Tabnine CLI configuration (MCP servers, skills, agents, slash commands, extensions), show a compact inventory, and ask per-category what to migrate. Then print the write plan — resolved absolute paths, the MCP endpoints being wired, and any permission changes — and get explicit approval before writing anything. Never overwrite an existing opencode file without asking, and back it up first when the user approves an overwrite. Remind the user to restart opencode when done.

If the user only wants to see what would happen, stop after the write plan.
