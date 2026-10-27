#!/usr/bin/env bash
# Builds the Vite prototypes (single-file dist/index.html each) and copies the
# output into play/<name>/index.html, which is tracked in git and served by
# Vercel as /play/<name>/. dist/ itself stays gitignored inside each project.
#
# Usage: bash tools/build-showcase.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

# name in play/  ->  project directory
declare -A GAMES=(
  [peak-putt]="prototypes/gameplay-arena-2/golf"
  [jigsaw-away]="prototypes/gameplay-arena-2/jigsaw"
  [stamp]="prototypes/gameplay-arena-2/stamp"
)

for name in "${!GAMES[@]}"; do
  dir="$root/${GAMES[$name]}"
  echo "== $name ($dir)"
  (cd "$dir" && { [ -d node_modules ] || npm ci; } && npm run build)
  mkdir -p "$root/play/$name"
  cp "$dir/dist/index.html" "$root/play/$name/index.html"
done

echo "Done. Builds are in play/."
