---
description: Migrate Tabnine CLI context files (TABNINE.md) into opencode's AGENTS.md.
---

Load the migrate-tabnine-context skill and run it.

Discover the user's Tabnine CLI context/memory files (TABNINE.md, GEMINI.md, or custom context.fileName files) in this repository and globally, and show what was found. Then print the write plan — absolute destinations, whether each file is created or merged, and the backup path for anything that already exists — and get explicit approval before writing. Never modify an existing AGENTS.md without asking and backing it up first, and never modify the source files.

If the user only wants to see what would happen, stop after the write plan.
