#!/usr/bin/env bash
# =============================================================================
# update_fork_mainsail.sh — rebase the multiwebcam patch onto an upstream
#                           Mainsail release and publish the GitHub release
#                           that Moonraker's update manager consumes.
#
# Usage:
#   ./scripts/update_fork_mainsail.sh v2.18.3          # from a clone of your fork
#   FORK=you/your-fork ./scripts/update_fork_mainsail.sh v2.18.3   # explicit target
#
# Requirements: git, node/npm, python3, and an authenticated `gh` CLI
#               (the account must own $FORK).
#
# /!\ NOT BATTLE-TESTED YET: this fork was cut from v2.18.2, still the latest
#     upstream release at the time of writing, so the rebase-and-publish flow
#     below has never run against a real new version. Read the output, don't
#     fire and forget. Report anything that breaks — it helps everyone.
#
# Effect: publishes https://github.com/<FORK>/releases/tag/<tag> with the
#         mainsail.zip asset. The update itself is then applied FROM THE
#         MAINSAIL UI (Update Manager) — this script never touches the printer.
#
# Two rules that must never be broken (learned the hard way):
#  - The release TITLE must be exactly the tag (e.g. "v2.18.3"): Moonraker reads
#    the remote version from the release *name*, not from the tag. A different
#    title = "update available" shown forever.
#  - release_info.json must carry the owner/name of the repo Moonraker points
#    at. Moonraker compares `repo:` in moonraker.conf with
#    "<project_owner>/<project_name>" and, on mismatch, raises an anomaly and
#    silently falls back to the repo it detected. This script enforces it.
#
# Versioning scheme: tag vX.Y.Z = upstream vX.Y.Z + the multiwebcam patch
# (the tag is force-moved onto our rebased commit).
# =============================================================================
set -euo pipefail

TAG="${1:?usage: $0 <upstream tag, e.g. v2.18.3>}"
# Target repo: taken from $FORK, otherwise deduced from this clone's origin remote.
# It must be YOUR fork — this is the repo your printer's update manager will follow.
detect_fork() {
    local url
    url="$(git config --get remote.origin.url 2>/dev/null || true)"
    [[ "$url" =~ github\.com[:/]+([^/]+)/([^/.]+) ]] && printf '%s/%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
}
FORK="${FORK:-$(detect_fork)}"
: "${FORK:?cannot determine the fork: run this from a clone of your fork, or set FORK=owner/repo}"
BRANCH="${BRANCH:-multiwebcam}"
UPSTREAM="https://github.com/mainsail-crew/mainsail.git"
OWNER="${FORK%%/*}"
NAME="${FORK##*/}"
WORK="$(mktemp -d /tmp/mainsail-fork-update.XXXXXX)"
trap 'echo "(work dir kept for inspection: $WORK)"' ERR

echo "[1/8] Cloning $FORK (branch $BRANCH)"
git clone --branch "$BRANCH" "https://github.com/${FORK}.git" "$WORK/mainsail"
cd "$WORK/mainsail"

echo "[2/8] Fetching upstream tag $TAG"
git remote add upstream "$UPSTREAM"
git fetch upstream "refs/tags/${TAG}:refs/tags/upstream-${TAG}" --no-tags

echo "[3/8] Rebasing the multiwebcam patch onto $TAG"
if ! git rebase "upstream-${TAG}"; then
    echo "REBASE FAILED — resolve the conflict by hand in $WORK/mainsail,"
    echo "then: git rebase --continue, and re-run steps 4-8 manually."
    echo "The patch touches only 4 files (~27 lines); conflicts stay small."
    exit 1
fi

echo "[4/8] Fork identity in release_info.json -> ${OWNER}/${NAME}"
sed -i "s/project_name: '[^']*'/project_name: '${NAME}'/; s/project_owner: '[^']*'/project_owner: '${OWNER}'/" \
    src/plugins/build-release_info.ts
if ! git diff --quiet; then
    git commit -qam "chore: fork identity (${FORK}) in release_info.json"
    echo "      identity commit added (your fork differs from the one it was forked from)"
fi

echo "[5/8] Building"
npm ci --prefer-offline --no-audit --no-fund
npm run build
grep -q "\"version\":\"${TAG}\"" dist/release_info.json \
    || { echo "FAILED: release_info.json does not carry ${TAG}"; exit 1; }
grep -q "\"project_owner\":\"${OWNER}\"" dist/release_info.json \
    || { echo "FAILED: project_owner != ${OWNER} (patch lost during rebase?)"; exit 1; }
# Must equal the repo name, or Moonraker raises an anomaly and falls back (see header).
grep -q "\"project_name\":\"${NAME}\"" dist/release_info.json \
    || { echo "FAILED: project_name != ${NAME} (patch lost during rebase?)"; exit 1; }

echo "[6/8] Packing mainsail.zip (python3: zip is often absent on WSL)"
python3 - <<'EOF'
import zipfile, os
os.chdir('dist')
with zipfile.ZipFile('mainsail.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk('.'):
        for f in files:
            p = os.path.join(root, f)
            if os.path.normpath(p) == 'mainsail.zip':
                continue
            z.write(p, os.path.relpath(p, '.'))
    print('zip OK,', len(z.namelist()), 'files')
EOF

echo "[7/8] Pushing branch + tag to $FORK"
git push origin "$BRANCH" --force-with-lease
git tag -f "$TAG"
git push origin "$TAG" --force

echo "[8/8] GitHub release (title MUST equal the tag)"
if gh release view "$TAG" -R "$FORK" >/dev/null 2>&1; then
    gh release upload "$TAG" dist/mainsail.zip -R "$FORK" --clobber
    gh release edit "$TAG" -R "$FORK" --title "$TAG"
else
    gh release create "$TAG" dist/mainsail.zip -R "$FORK" \
        --title "$TAG" \
        --notes "Mainsail ${TAG} with independent webcam panels (multiwebcam branch, rebased)."
fi

rm -rf "$WORK"
echo
echo "DONE. On the printer: Mainsail > Machine > Update Manager now offers ${TAG}."
echo "Update from the UI (printer idle), then reload the page twice (service worker cache)."
