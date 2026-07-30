#!/usr/bin/env bash
# Install the migrate-from-tabnine-cli skill and /migrate slash command
# into an opencode configuration directory.
#
# Usage:
#   ./install.sh                 # install globally into ~/.config/opencode/
#   ./install.sh --project       # install into ./.opencode/ in the current directory
#   ./install.sh --overwrite     # skip diff prompts, overwrite existing files
#   ./install.sh --help          # show usage
#
# For each file this installer wants to place, one of three things happens:
#   - target is missing         -> file is copied
#   - target is byte-identical  -> file is skipped
#   - target differs            -> a diff is shown and the user is prompted
#                                  to (s)kip, (o)verwrite, or (r)ename the
#                                  existing target before copying

set -euo pipefail

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

TARGET_SCOPE="global"
OVERWRITE=0

usage() {
    cat <<'EOF'
Install the Tabnine CLI -> opencode migration helper.

Usage:
    install.sh [--project] [--overwrite] [--help]

Options:
    --project    Install into ./.opencode/ (project scope) instead of
                 ~/.config/opencode/ (global scope, the default).
    --overwrite  Overwrite existing target files without prompting.
                 Diffs are still printed.
    --help, -h   Show this message and exit.

The installer copies two things:

    skills/migrate-from-tabnine-cli/  -> <target>/skills/migrate-from-tabnine-cli/
    commands/migrate.md               -> <target>/commands/migrate.md

Where <target> is either ~/.config/opencode or ./.opencode.

You can also install manually. See the README for the copy commands.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)   TARGET_SCOPE="project"; shift ;;
        --overwrite) OVERWRITE=1; shift ;;
        --help|-h)   usage; exit 0 ;;
        *)           echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# -----------------------------------------------------------------------------
# Locate source (the directory this script lives in)
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$SCRIPT_DIR/skills/migrate-from-tabnine-cli" ]] || [[ ! -f "$SCRIPT_DIR/commands/migrate.md" ]]; then
    echo "Error: could not find source files next to this script." >&2
    echo "Expected: $SCRIPT_DIR/skills/migrate-from-tabnine-cli/ and $SCRIPT_DIR/commands/migrate.md" >&2
    echo "" >&2
    echo "If you ran this via 'curl | bash', download the repo first:" >&2
    echo "    git clone https://github.com/codota/tabnine-opencode-public" >&2
    echo "    cd tabnine-opencode-public/migration_helper" >&2
    echo "    ./install.sh" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Resolve target
# -----------------------------------------------------------------------------

if [[ "$TARGET_SCOPE" == "global" ]]; then
    TARGET_DIR="$HOME/.config/opencode"
else
    TARGET_DIR="$PWD/.opencode"
fi

echo "Installing into: $TARGET_DIR ($TARGET_SCOPE scope)"
echo ""

mkdir -p "$TARGET_DIR/skills" "$TARGET_DIR/commands"

# -----------------------------------------------------------------------------
# Per-file install helper
# -----------------------------------------------------------------------------
# Args: <source path> <target path>
install_file() {
    local src="$1"
    local dst="$2"

    mkdir -p "$(dirname "$dst")"

    if [[ ! -e "$dst" ]]; then
        cp "$src" "$dst"
        echo "  installed  $dst"
        return
    fi

    if cmp -s "$src" "$dst"; then
        echo "  up to date $dst"
        return
    fi

    if [[ "$OVERWRITE" -eq 1 ]]; then
        cp "$src" "$dst"
        echo "  overwrote  $dst"
        return
    fi

    echo ""
    echo "  Target exists and differs: $dst"
    echo "  Diff (existing -> incoming):"
    echo "  ---"
    diff -u "$dst" "$src" || true
    echo "  ---"

    while true; do
        read -rp "  [s]kip, [o]verwrite, or [r]ename existing and install? " choice </dev/tty
        case "$choice" in
            s|S)
                echo "  skipped    $dst"
                break
                ;;
            o|O)
                cp "$src" "$dst"
                echo "  overwrote  $dst"
                break
                ;;
            r|R)
                local ts backup
                ts="$(date +%Y%m%d-%H%M%S)"
                backup="$dst.bak-$ts"
                mv "$dst" "$backup"
                cp "$src" "$dst"
                echo "  renamed    $backup"
                echo "  installed  $dst"
                break
                ;;
            *)
                echo "  Please answer s, o, or r."
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Copy skill directory (recursive)
# -----------------------------------------------------------------------------

echo "Skill: migrate-from-tabnine-cli"

# Walk the source skill directory and install each file individually so
# collisions are handled per file, not silently overwritten as a tree.
while IFS= read -r -d '' src_file; do
    rel_path="${src_file#$SCRIPT_DIR/skills/}"
    dst_file="$TARGET_DIR/skills/$rel_path"
    install_file "$src_file" "$dst_file"
done < <(find "$SCRIPT_DIR/skills/migrate-from-tabnine-cli" -type f -print0)

echo ""
echo "Command: migrate.md"
install_file "$SCRIPT_DIR/commands/migrate.md" "$TARGET_DIR/commands/migrate.md"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

echo ""
echo "Done."
echo ""
echo "Quit and restart opencode for these changes to take effect."
echo "Then invoke the wizard with:"
echo "    /migrate"
echo "or by asking opencode to migrate your Tabnine CLI configuration."
