#!/bin/bash
#
# AI tooling setup:
#  -. exit with a warning unless TYPO3 is installed and set up
#     (DDEV setup if a .ddev folder exists, otherwise composer + local php cli)
#  0. copy .mcp-template.json to .mcp.json (only if .mcp.json doesn't exist yet)
#  1. make sure `typo3-dev-companion` and `npx` are available (install locally if not),
#     then run `typo3-dev-companion install` (from $PATH or the local checkout)
#  2. run `npx modern-web-guidance@latest install`
#  3. make sure `openspec` is available (install if not), then run `openspec init`
#  4. point IJ_MCP_SERVER_PROJECT_PATH in .mcp.json to this project directory
#  5. if sys_workspace is empty, insert the workspace "Updates" (via `typo3 database:import --interactive`)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

info() { printf '==> %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# TYPO3 must be installed (composer) and set up (settings.php) first
# ---------------------------------------------------------------------------
# A .ddev folder means a DDEV setup, otherwise a plain composer setup with the local php cli.
if [ -d .ddev ]; then
    info 'Found .ddev, assuming a DDEV setup'
    if ! have ddev; then
        {
            echo 'WARNING: This project has a .ddev folder, but the `ddev` command is not available.'
            echo 'Please install DDEV and set up TYPO3 first, then re-run ./ai-setup.sh.'
        } >&2
        exit 1
    fi
    COMPOSER_INSTALL_HINT='ddev composer install'
    TYPO3_SETUP_HINT='ddev typo3 setup'
    TYPO3_CLI=(ddev typo3)
else
    info 'No .ddev found, assuming a composer setup with the local php cli'
    have php || fail 'php is not available in $PATH.'
    COMPOSER_INSTALL_HINT='composer install'
    TYPO3_SETUP_HINT='php vendor/bin/typo3 setup'
    TYPO3_CLI=(php vendor/bin/typo3)
fi

# The project directory is mounted into the DDEV container, so these files can be checked from the host.
if [ ! -f vendor/bin/typo3 ] || [ ! -f config/system/settings.php ]; then
    {
        echo 'WARNING: TYPO3 has not been installed and set up yet.'
        [ -f vendor/bin/typo3 ] || echo "  - vendor/bin/typo3 is missing (run \`$COMPOSER_INSTALL_HINT\`)"
        [ -f config/system/settings.php ] || echo "  - config/system/settings.php is missing (run the TYPO3 setup, e.g. \`$TYPO3_SETUP_HINT\`)"
        echo 'Please do this first, then re-run ./ai-setup.sh.'
    } >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 0. .mcp-template.json -> .mcp.json
# ---------------------------------------------------------------------------
if [ -f .mcp.json ]; then
    info '.mcp.json already exists, not overwriting it'
else
    [ -f .mcp-template.json ] || fail '.mcp-template.json not found.'
    cp .mcp-template.json .mcp.json
    info 'Copied .mcp-template.json to .mcp.json'
fi

# ---------------------------------------------------------------------------
# 1a. typo3-dev-companion
# ---------------------------------------------------------------------------
if have typo3-dev-companion; then
    info 'typo3-dev-companion found in $PATH'
    COMPANION=(typo3-dev-companion)
else
    info 'typo3-dev-companion not found in $PATH, installing locally'
    have git      || fail 'git is required to install typo3-dev-companion.'
    have composer || fail 'composer is required to install typo3-dev-companion.'
    if [ -d typo3-dev-companion ]; then
        info 'typo3-dev-companion/ already exists, skipping clone'
    else
        git clone https://github.com/TYPO3/dev-companion.git typo3-dev-companion
    fi
    composer install --working-dir=typo3-dev-companion
    COMPANION=(php "$PROJECT_DIR/typo3-dev-companion/bin/typo3-dev-companion")
fi

# Now that it is clear where the dev-companion lives, run its install command
info "${COMPANION[*]} install --agent=claude"
"${COMPANION[@]}" install --agent=claude

# ---------------------------------------------------------------------------
# 1b. npx (ships with Node.js/npm)
# ---------------------------------------------------------------------------
if have npx; then
    info 'npx found in $PATH'
else
    info 'npx not found in $PATH, installing Node.js (includes npm and npx)'
    SUDO=''
    [ "$(id -u)" -eq 0 ] || SUDO='sudo'
    if have brew; then
        brew install node
    elif have apt-get; then
        $SUDO apt-get update && $SUDO apt-get install -y nodejs npm
    elif have dnf; then
        $SUDO dnf install -y nodejs npm
    elif have apk; then
        $SUDO apk add --no-cache nodejs npm
    else
        fail 'No supported package manager (brew, apt-get, dnf, apk) found. Please install Node.js from https://nodejs.org/ manually.'
    fi
    have npx || fail 'npx is still not available in $PATH after installing Node.js. Open a new shell and re-run this script.'
fi

# ---------------------------------------------------------------------------
# 2. npx commands
# ---------------------------------------------------------------------------
npx modern-web-guidance@latest install

# ---------------------------------------------------------------------------
# 3. openspec
# ---------------------------------------------------------------------------
if have openspec; then
    info 'openspec found in $PATH'
else
    info 'openspec not found in $PATH, installing'
    have curl || fail 'curl is required to install openspec.'
    curl -fsSL https://openspec.dev/cli/install.sh | sh
    have openspec || fail 'openspec is still not available in $PATH after installing. Open a new shell and re-run this script.'
fi
openspec init

# ---------------------------------------------------------------------------
# 4. IJ_MCP_SERVER_PROJECT_PATH in .mcp.json
# ---------------------------------------------------------------------------
MCP_FILE="$PROJECT_DIR/.mcp.json"
[ -f "$MCP_FILE" ] || fail "$MCP_FILE not found."
grep -q '"IJ_MCP_SERVER_PROJECT_PATH"' "$MCP_FILE" || fail "IJ_MCP_SERVER_PROJECT_PATH not found in $MCP_FILE."

if have jq; then
    TMP_FILE="$(mktemp)"
    jq --arg path "$PROJECT_DIR" \
        '(.. | objects | select(has("IJ_MCP_SERVER_PROJECT_PATH")) | .IJ_MCP_SERVER_PROJECT_PATH) = $path' \
        "$MCP_FILE" > "$TMP_FILE"
    mv "$TMP_FILE" "$MCP_FILE"
elif have perl; then
    # Fallback without jq: replace the value in place, keeping the rest of the file untouched.
    PROJECT_DIR="$PROJECT_DIR" perl -0pi -e '
        my $p = $ENV{PROJECT_DIR};
        $p =~ s/(["\\])/\\$1/g;
        s/("IJ_MCP_SERVER_PROJECT_PATH"\s*:\s*)"(?:[^"\\]|\\.)*"/$1"$p"/g;
    ' "$MCP_FILE"
elif have python3 || have python; then
    # Fallback without jq and perl: same in-place replacement using Python.
    PY="$(command -v python3 || command -v python)"
    PROJECT_DIR="$PROJECT_DIR" MCP_FILE="$MCP_FILE" "$PY" - <<'PY'
import json, os, re

path = os.environ["MCP_FILE"]
value = json.dumps(os.environ["PROJECT_DIR"])

with open(path, encoding="utf-8") as f:
    content = f.read()

pattern = re.compile(r'("IJ_MCP_SERVER_PROJECT_PATH"\s*:\s*)"(?:[^"\\]|\\.)*"')
content = pattern.sub(lambda m: m.group(1) + value, content)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY
else
    fail 'Need one of jq, perl or python to update .mcp.json.'
fi
info "Set IJ_MCP_SERVER_PROJECT_PATH to $PROJECT_DIR in .mcp.json"

# ---------------------------------------------------------------------------
# 5. default workspace "Updates" in sys_workspace
# ---------------------------------------------------------------------------
# `database:import --interactive` runs the mysql client with the TYPO3 connection settings;
# the SQL is fed to it via stdin.
typo3_sql() {
    printf '%s\n' "$1" | "${TYPO3_CLI[@]}" database:import --interactive
}

COUNT_OUTPUT="$(typo3_sql 'SELECT COUNT(*) AS workspace_count FROM sys_workspace;')" \
    || fail 'Could not query sys_workspace (is EXT:workspaces installed and the database set up?).'
WORKSPACE_COUNT="$(printf '%s\n' "$COUNT_OUTPUT" | grep -E '^[0-9]+$' | tail -n 1 || true)"
[ -n "$WORKSPACE_COUNT" ] || fail "Could not read the sys_workspace record count from the output: $COUNT_OUTPUT"

if [ "$WORKSPACE_COUNT" -gt 0 ]; then
    info "sys_workspace already has $WORKSPACE_COUNT record(s), not inserting one"
else
    info 'sys_workspace is empty, inserting workspace "Updates"'
    typo3_sql "INSERT INTO sys_workspace (pid, title, color, db_mountpoints) VALUES (0, 'Updates', 'orange', '1');" \
        || fail 'Could not insert the workspace record into sys_workspace.'
fi

info 'Done.'
