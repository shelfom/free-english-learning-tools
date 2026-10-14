#!/usr/bin/env bash
# Rebuild the GitHub Pages mirrors (https://shelfom.github.io/<repo>/) from the
# latest code on each repo's main branch. The Coze production sites are not touched.
#
#   tools/publish-mirrors.sh                 # every mirrored site
#   tools/publish-mirrors.sh awl-570-flashcards cambridge-ket-flashcards
#
# Needs: git, node 20+, python3, and push access to the repos.
set -euo pipefail

OWNER=shelfom
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$(mktemp -d)}"

# repo|build command ($BASE is the /<repo>/ sub-path)
SITES=(
  "ielts-listening-paraphrase|\$PNPM exec vite build --base=\$BASE"
  "ielts-reading-paraphrase|\$PNPM exec vite build --base=\$BASE"
  "ielts-sentence-repair|\$PNPM exec vite build --base=\$BASE --outDir dist --emptyOutDir"
  "ielts-writing-translation|\$PNPM exec vite build --base=\$BASE"
  "ielts-writing-band-6-to-8|mkdir -p dist && cp index.html dist/"
  "awl-570-flashcards|\$PNPM exec vite build --base=\$BASE"
  "cambridge-ket-flashcards|\$PNPM exec vite build --base=\$BASE"
  "cambridge-pet-flashcards|\$PNPM exec vite build --base=\$BASE"
  "cambridge-fce-flashcards|\$PNPM exec vite build --base=\$BASE"
)

# pnpm 9 matches the lockfiles Coze writes.
export PNPM="npx -y pnpm@9"

for entry in "${SITES[@]}"; do
  repo="${entry%%|*}"; build="${entry#*|}"
  if [ "$#" -gt 0 ] && [[ ! " $* " == *" $repo "* ]]; then continue; fi
  echo "==> $repo"
  src="$WORK/$repo"
  rm -rf "$src"
  git clone -q --depth 1 "https://github.com/$OWNER/$repo.git" "$src"
  (
    cd "$src"
    export BASE="/$repo/"
    if [ -f package.json ] && [[ "$build" == \$PNPM* ]]; then
      $PNPM install --frozen-lockfile >/dev/null 2>&1 || $PNPM install --no-frozen-lockfile >/dev/null
    fi
    bash -c "$build"
    python3 "$HERE/rebase-paths.py" dist "$BASE"
    touch dist/.nojekyll
    cd dist
    git init -q -b gh-pages
    git add -A
    git -c user.name="$OWNER" -c user.email="259815108+$OWNER@users.noreply.github.com" \
      commit -q -m "Mirror build from main@$(git -C "$src" rev-parse --short HEAD)"
    git push -q -f "https://github.com/$OWNER/$repo.git" gh-pages
  )
  gh api -X POST "repos/$OWNER/$repo/pages" -f "source[branch]=gh-pages" -f "source[path]=/" >/dev/null 2>&1 \
    || gh api -X PUT "repos/$OWNER/$repo/pages" -f "source[branch]=gh-pages" -f "source[path]=/" >/dev/null 2>&1 || true
  echo "    https://$OWNER.github.io/$repo/"
done
