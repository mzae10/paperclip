#!/usr/bin/env bash
# =============================================================================
# Sync this fork with the original Paperclip repo, then rebuild + restart.
#
#   ./update.sh            # fetch upstream -> ff master -> merge -> rebuild
#   ./update.sh --no-build # sync only (don't touch containers)
#
# Expected remotes (set once):
#   upstream -> https://github.com/paperclipai/paperclip.git   (the original)
#   origin   -> https://github.com/<you>/paperclip.git         (your fork)
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"        # .../selfhost
REPO="$(cd "$HERE/.." && pwd)"               # fork repo root
BUILD=1
[ "${1:-}" = "--no-build" ] && BUILD=0

if ! git -C "$REPO" remote get-url upstream >/dev/null 2>&1; then
  echo "!! No 'upstream' remote. Add it once:"
  echo "   git -C \"$REPO\" remote add upstream https://github.com/paperclipai/paperclip.git"
  exit 1
fi

echo ">> Fetching upstream..."
git -C "$REPO" fetch upstream --tags --prune

echo ">> Fast-forwarding master to upstream/master..."
git -C "$REPO" fetch . upstream/master:master 2>/dev/null \
  || git -C "$REPO" branch -f master upstream/master

CUR="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
echo ">> On '$CUR'. New upstream commits:"
git -C "$REPO" --no-pager log --oneline "$CUR..master" | head -30 || true

echo ">> Merging into '$CUR'..."
if ! git -C "$REPO" merge --no-edit master; then
  echo "!! Conflicts. Resolve in $REPO, commit, then re-run ./update.sh"
  exit 1
fi

if [ "$BUILD" = "1" ]; then
  echo ">> Rebuilding + restarting..."
  ( cd "$HERE" && docker compose build server && docker compose up -d )
  echo ">> Done.  docker compose -f selfhost/docker-compose.yml ps"
else
  echo ">> Synced. Skipped rebuild (--no-build)."
fi

echo ">> Push the merge to your fork:  git -C \"$REPO\" push origin $CUR"
