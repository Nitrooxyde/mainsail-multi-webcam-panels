#!/usr/bin/env bash
# =============================================================================
# update_channel.sh — build the multiwebcam Mainsail fork on top of an official
#                     Mainsail release and push the result to YOUR update
#                     channel repository (the private repo your printer follows).
#
# Usage:
#   CHANNEL=git@github.com:you/mainsail-dist.git ./scripts/update_channel.sh v2.18.2
#   CHANNEL=https://github.com/you/mainsail-dist.git ./scripts/update_channel.sh v2.18.3
#
# Requirements: git (with push access to $CHANNEL and an identity configured:
#               git config user.name / user.email), node/npm.
#               The printer is NEVER touched: once the push is done, the update
#               is applied from Mainsail's own UI (Update Manager).
#
# Optional overrides:
#   SOURCE  — where the patch lives (default: this public repository)
#   BRANCH  — patch branch (default: multiwebcam)
#
# Battle-tested status (2026-08-19): the channel mechanism (push -> Update
# Manager sees it -> update from the UI) has been exercised for real. The
# rebase onto a NEWER upstream release has not yet — v2.18.2 is still the
# latest official release. Read the output; your Step 0 backup is the net.
# =============================================================================
set -euo pipefail

TAG="${1:?usage: $0 <official mainsail tag, e.g. v2.18.3>}"
: "${CHANNEL:?set CHANNEL=<git url of YOUR update-channel repo>}"
SOURCE="${SOURCE:-https://github.com/Nitrooxyde/mainsail-multi-webcam-panels.git}"
BRANCH="${BRANCH:-multiwebcam}"
UPSTREAM="https://github.com/mainsail-crew/mainsail.git"
WORK="$(mktemp -d /tmp/mainsail-channel.XXXXXX)"
trap 'echo "(work dir kept for inspection: $WORK)"' ERR

echo "[1/6] Cloning the patch source ($SOURCE, branch $BRANCH)"
git clone -q --branch "$BRANCH" "$SOURCE" "$WORK/src"
cd "$WORK/src"

echo "[2/6] Fetching official tag $TAG"
git remote add upstream "$UPSTREAM"
git fetch -q upstream "refs/tags/${TAG}:refs/tags/upstream-${TAG}" --no-tags

echo "[3/6] Rebasing the multiwebcam patch onto $TAG"
if ! git rebase "upstream-${TAG}"; then
    echo "REBASE FAILED — resolve the conflict in $WORK/src, then run steps 4-6 by hand."
    echo "(the patch touches 3 files, ~25 lines; conflicts stay small and readable)"
    exit 1
fi

echo "[4/6] Building"
npm ci --prefer-offline --no-audit --no-fund
npm run build
test -f dist/index.html || { echo "FAILED: build produced no dist/index.html"; exit 1; }

echo "[5/6] Pushing the build to your channel ($CHANNEL)"
git clone -q "$CHANNEL" "$WORK/channel"
cd "$WORK/channel"
git checkout -q -B main
find . -mindepth 1 -maxdepth 1 -not -name ".git" -not -name "README.md" -exec rm -rf {} +
cp -a "$WORK/src/dist/." .
git add -A
if git diff --cached --quiet; then
    echo "Nothing changed — the channel is already at ${TAG}."
else
    git commit -q -m "build: mainsail ${TAG} + multiwebcam patch"
    git tag -f "$TAG"
    git push -q origin main
    git push -q -f origin "refs/tags/${TAG}"
fi

echo "[6/6] Done"
rm -rf "$WORK"
echo
echo "On the printer: Machine > Update Manager now offers the new build."
echo "Back up first (see the guide's Step 0), update from the UI with the printer idle,"
echo "then reload the page twice (service worker cache)."
