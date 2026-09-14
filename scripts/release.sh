#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

BUMP_TARGET="patch"
LOCAL_BUILD=false
DRY_RUN=false
SKIP_PUSH=false

# Parse command line flags & arguments
for arg in "$@"; do
    case "$arg" in
        --local|--build)
            LOCAL_BUILD=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --skip-push)
            SKIP_PUSH=true
            ;;
        -h|--help)
            echo "⚡ Fast Deterministic Release Cutter"
            echo ""
            echo "Usage: ./scripts/release.sh [patch|minor|major|<version>] [options]"
            echo ""
            echo "Arguments:"
            echo "  patch               Bump patch version (e.g. 1.1.0 -> 1.1.1) [default]"
            echo "  minor               Bump minor version (e.g. 1.1.0 -> 1.2.0)"
            echo "  major               Bump major version (e.g. 1.1.0 -> 2.0.0)"
            echo "  <version>           Set explicit version (e.g. 1.2.0 or v1.2.0)"
            echo ""
            echo "Options:"
            echo "  --local, --build    Build DMG locally and publish via 'gh release' (otherwise pushes tag for GitHub Actions)"
            echo "  --dry-run           Preview next version and files without making changes"
            echo "  --skip-push         Make version edits, project generation and commit without pushing to remote"
            echo ""
            echo "Examples:"
            echo "  ./scripts/release.sh          # Instantly cuts and pushes next patch release"
            echo "  ./scripts/release.sh minor    # Cuts next minor release (e.g. 1.2.0)"
            echo "  ./scripts/release.sh 1.2.5    # Sets exact version 1.2.5"
            exit 0
            ;;
        *)
            BUMP_TARGET="$arg"
            ;;
    esac
done

# Ensure required tools are installed
if ! command -v xcodegen &> /dev/null; then
    echo "❌ Error: xcodegen is required. Install with: brew install xcodegen"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "❌ Error: git is required."
    exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Compute version bump using Python
VERSION_INFO=$(/usr/bin/python3 -c '
import re, sys

bump_arg = sys.argv[1]
with open("project.yml", "r", encoding="utf-8") as f:
    content = f.read()

m_ver = re.search(r"MARKETING_VERSION:\s*[\x22\x27]?([^\x22\x27\s]+)[\x22\x27]?", content)
m_build = re.search(r"CURRENT_PROJECT_VERSION:\s*[\x22\x27]?([^\x22\x27\s]+)[\x22\x27]?", content)

if not m_ver or not m_build:
    sys.exit("Error: Could not find MARKETING_VERSION or CURRENT_PROJECT_VERSION in project.yml")

curr_ver = m_ver.group(1)
curr_build = int(m_build.group(1))

parts = curr_ver.split(".")
while len(parts) < 3:
    parts.append("0")
major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])

bump = bump_arg.lstrip("v").lower()
if bump == "patch":
    patch += 1
    next_ver = f"{major}.{minor}.{patch}"
elif bump == "minor":
    minor += 1
    patch = 0
    next_ver = f"{major}.{minor}.{patch}"
elif bump == "major":
    major += 1
    minor = 0
    patch = 0
    next_ver = f"{major}.{minor}.{patch}"
elif re.match(r"^\d+(\.\d+)*$", bump):
    next_ver = bump
else:
    sys.exit(f"Error: Invalid version argument {bump_arg}")

next_build = curr_build + 1
print(f"{curr_ver} {next_ver} {curr_build} {next_build}")
' "${BUMP_TARGET}")

read -r CURR_VER NEXT_VER CURR_BUILD NEXT_BUILD <<< "$VERSION_INFO"

echo "=================================================="
echo " ⚡ Cutting Release: v${CURR_VER} -> v${NEXT_VER} (Build ${NEXT_BUILD})"
echo "=================================================="

if [ "${DRY_RUN}" = "true" ]; then
    echo "🔍 DRY RUN: No changes written."
    echo "   Current: v${CURR_VER} (Build ${CURR_BUILD})"
    echo "   Next:    v${NEXT_VER} (Build ${NEXT_BUILD})"
    exit 0
fi

# 1. Update project.yml, README.md, and scripts/build_dmg.sh
echo "==> Updating version metadata..."
/usr/bin/python3 -c '
import sys, re

curr_ver, next_ver, curr_build, next_build = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open("project.yml", "r", encoding="utf-8") as f:
    p = f.read()
p = re.sub(r"MARKETING_VERSION:\s*[\x22\x27]?[^\x22\x27\n]+[\x22\x27]?", f"MARKETING_VERSION: \"{next_ver}\"", p)
p = re.sub(r"CURRENT_PROJECT_VERSION:\s*[\x22\x27]?[^\x22\x27\n]+[\x22\x27]?", f"CURRENT_PROJECT_VERSION: \"{next_build}\"", p)
p = re.sub(r"CFBundleShortVersionString:\s*[\x22\x27]?[^\x22\x27\n]+[\x22\x27]?", f"CFBundleShortVersionString: \"{next_ver}\"", p)
p = re.sub(r"CFBundleVersion:\s*[\x22\x27]?[^\x22\x27\n]+[\x22\x27]?", f"CFBundleVersion: \"{next_build}\"", p)
with open("project.yml", "w", encoding="utf-8") as f:
    f.write(p)

try:
    with open("README.md", "r", encoding="utf-8") as f:
        r = f.read()
    r = r.replace(f"ClaudeUsage-v{curr_ver}.dmg", f"ClaudeUsage-v{next_ver}.dmg")
    r = r.replace(f"(v{curr_ver})", f"(v{next_ver})")
    r = r.replace(f"./scripts/build_dmg.sh v{curr_ver}", f"./scripts/build_dmg.sh v{next_ver}")
    with open("README.md", "w", encoding="utf-8") as f:
        f.write(r)
except FileNotFoundError:
    pass

try:
    with open("scripts/build_dmg.sh", "r", encoding="utf-8") as f:
        b = f.read()
    b = re.sub(r"VERSION=\"\$\{1:-[^}]+\}\"", f"VERSION=\"${{1:-{next_ver}}}\"", b)
    with open("scripts/build_dmg.sh", "w", encoding="utf-8") as f:
        f.write(b)
except FileNotFoundError:
    pass
' "${CURR_VER}" "${NEXT_VER}" "${CURR_BUILD}" "${NEXT_BUILD}"

# 2. Regenerate Xcode project and Info.plists
echo "==> Regenerating Xcode project & plists..."
xcodegen generate --quiet

# 3. Git Stage & Commit
echo "==> Staging & committing release..."
git add project.yml ClaudeUsageApp/Info.plist ClaudeUsageWidget/Info.plist ClaudeUsage.xcodeproj README.md scripts/build_dmg.sh

git commit -m "chore(release): cut v${NEXT_VER} (build ${NEXT_BUILD})"

# 4. Tagging
echo "==> Creating tag v${NEXT_VER}..."
git tag -a "v${NEXT_VER}" -m "Release v${NEXT_VER}"

# 5. Push or Local Publish
if [ "${SKIP_PUSH}" = "true" ]; then
    echo "✓ Committed and tagged locally. Push skipped (--skip-push)."
    exit 0
fi

echo "==> Pushing commits and tag to origin..."
git push origin "${CURRENT_BRANCH}"
git push origin "v${NEXT_VER}"

if [ "${LOCAL_BUILD}" = "true" ]; then
    echo "==> Building DMG locally..."
    ./scripts/build_dmg.sh "${NEXT_VER}"

    if command -v gh &> /dev/null; then
        echo "==> Publishing release to GitHub via gh CLI..."
        gh release create "v${NEXT_VER}" "dist/ClaudeUsage-v${NEXT_VER}.dmg" \
            --title "v${NEXT_VER}: Claude Usage & Peak Time Tracker for macOS" \
            --generate-notes
        echo "✓ GitHub Release v${NEXT_VER} published!"
    else
        echo "✓ Local DMG packaged at dist/ClaudeUsage-v${NEXT_VER}.dmg"
        echo "⚠️ Note: gh CLI not found. To publish, install gh or upload the DMG manually."
    fi
else
    echo ""
    echo "=================================================="
    echo " 🚀 Release v${NEXT_VER} cut successfully in seconds!"
    echo " Tag: v${NEXT_VER} pushed to origin/${CURRENT_BRANCH}"
    echo ""
    echo " GitHub Actions is automatically building and publishing the DMG at:"
    echo " https://github.com/quincarter/ClaudeUsage-MacOS-App-Widget/actions"
    echo " https://github.com/quincarter/ClaudeUsage-MacOS-App-Widget/releases/tag/v${NEXT_VER}"
    echo "=================================================="
fi
