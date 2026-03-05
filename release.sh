#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# release.sh — ChronoForge Arena release pipeline
#
# Usage:
#   ./release.sh patch    # 0.9.1 → 0.9.2  (bug-fix / balance)
#   ./release.sh minor    # 0.9.1 → 0.10.0 (new content / features)
#   ./release.sh major    # 0.9.1 → 1.0.0  (milestone / full release)
#
# What it does, in order:
#   1. Bump version.txt
#   2. Run git-cliff  → CHANGELOG.md
#   3. Run Python     → data/patchnotes.txt  (BBCode, Godot reads this in-game)
#   4. git commit + tag
#   5. Godot headless export  → build/
#   6. steamcmd upload        → Steam (skipped if STEAM_USER unset)
#
# Dependencies:
#   git-cliff   https://github.com/orhun/git-cliff   (cargo install git-cliff)
#   python3     (stdlib only — no pip install needed)
#   godot       in PATH, or set GODOT_BIN
#   steamcmd    in PATH, or set STEAM_CMD             (optional)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

BUMP="${1:-patch}"

# ── Config — override via environment variables ───────────────────────────────
GODOT_BIN="${GODOT_BIN:-godot}"
STEAM_CMD="${STEAM_CMD:-steamcmd}"
STEAM_USER="${STEAM_USER:-}"          # e.g. export STEAM_USER=mysteamlogin
EXPORT_PRESET="${EXPORT_PRESET:-Windows Desktop}"
BUILD_DIR="${BUILD_DIR:-./build}"
BUILD_EXE="ChronoForgeArena.exe"

# ── Helpers ───────────────────────────────────────────────────────────────────
step() { echo; echo "── $* ──"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

command -v git-cliff &>/dev/null || die "git-cliff not found. Install: cargo install git-cliff"
command -v python3   &>/dev/null || die "python3 not found."

# ── 1. Version bump ───────────────────────────────────────────────────────────
step "Version bump ($BUMP)"

[[ -f version.txt ]] || die "version.txt not found"
CURRENT=$(cat version.txt | tr -d '[:space:]')
IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$CURRENT"

case "$BUMP" in
    major) V_MAJOR=$((V_MAJOR + 1)); V_MINOR=0; V_PATCH=0 ;;
    minor) V_MINOR=$((V_MINOR + 1)); V_PATCH=0 ;;
    patch) V_PATCH=$((V_PATCH + 1)) ;;
    *)     die "Unknown bump type '$BUMP'. Use: patch | minor | major" ;;
esac

NEW_VERSION="${V_MAJOR}.${V_MINOR}.${V_PATCH}"
printf '%s\n' "$NEW_VERSION" > version.txt
echo "  $CURRENT → $NEW_VERSION"

# ── 2. Changelog (git-cliff) ──────────────────────────────────────────────────
step "Generating CHANGELOG.md"
git cliff --tag "v${NEW_VERSION}" --output CHANGELOG.md
echo "  CHANGELOG.md updated"

# ── 3. In-game patchnotes (latest 2 sections → BBCode) ───────────────────────
step "Generating data/patchnotes.txt"
python3 tools/generate_patchnotes.py CHANGELOG.md data/patchnotes.txt --sections 2

# ── 4. Git commit + tag ───────────────────────────────────────────────────────
step "Committing release v${NEW_VERSION}"
git add version.txt CHANGELOG.md data/patchnotes.txt
git commit -m "chore: release v${NEW_VERSION}"
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
echo "  Tagged v${NEW_VERSION}"

# ── 5. Godot export ───────────────────────────────────────────────────────────
step "Exporting Godot build"
mkdir -p "$BUILD_DIR"

if ! command -v "$GODOT_BIN" &>/dev/null; then
    echo "  WARN: '$GODOT_BIN' not found in PATH — skipping export."
    echo "  Set GODOT_BIN=/path/to/godot and re-run, or export manually."
else
    "$GODOT_BIN" --headless \
                 --export-release "$EXPORT_PRESET" \
                 "${BUILD_DIR}/${BUILD_EXE}" \
        && echo "  Exported → ${BUILD_DIR}/${BUILD_EXE}" \
        || die "Godot export failed"
fi

# ── 6. Steam upload ───────────────────────────────────────────────────────────
step "Steam upload"

if [[ -z "$STEAM_USER" ]]; then
    echo "  STEAM_USER not set — skipping upload."
    echo "  To enable: export STEAM_USER=your_steam_login && ./release.sh patch"
elif ! command -v "$STEAM_CMD" &>/dev/null; then
    echo "  WARN: steamcmd not found at '$STEAM_CMD' — skipping upload."
else
    # Patch the build description in app_build.vdf with the new version
    VDF_FILE="steam/app_build.vdf"
    if [[ -f "$VDF_FILE" ]]; then
        # Replace the Desc line (cross-platform sed)
        sed -i.bak "s|\"Desc\".*|\"Desc\" \"ChronoForge Arena v${NEW_VERSION} Demo\"|" "$VDF_FILE"
        rm -f "${VDF_FILE}.bak"
    fi

    "$STEAM_CMD" \
        +login "$STEAM_USER" \
        +run_app_build "$(pwd)/steam/app_build.vdf" \
        +quit \
        && echo "  Uploaded to Steam (beta branch)" \
        || die "steamcmd upload failed"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo
echo "✓  Released v${NEW_VERSION}"
echo "   Git tag:  v${NEW_VERSION}"
echo "   Build:    ${BUILD_DIR}/${BUILD_EXE}"
echo "   Reminder: git push && git push --tags"
