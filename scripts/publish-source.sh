#!/bin/bash
# Publishes the AltStore source to GitHub Pages and prints the URL to add in AltStore.
#
# Prereqs:
#   - gh CLI authenticated: run `gh auth login` once
#   - If you already have `gh auth setup-git`, skip it (script calls it automatically)
#
# Controls:
#   ALTSOURCE_OWNER   GitHub owner (default: authed user)
#   ALTSOURCE_REPO    repo name (default: truecaller-ios-lookup)
#
# Alternative hosts: upload the contents of dist/ to any static host and set
# ALTSOURCE_BASE_URL when running build-altstore-source.sh instead.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! gh auth status &>/dev/null; then
  echo "gh is not authenticated. Run: gh auth login" >&2
  exit 1
fi
gh auth setup-git >/dev/null 2>&1 || true

OWNER="${ALTSOURCE_OWNER:-$(gh api user -q .login)}"
REPO="${ALTSOURCE_REPO:-truecaller-ios-lookup}"
BASE="https://${OWNER}.github.io/${REPO}"
echo "Owner: $OWNER   Repo: $REPO"
echo "Source URL will be: $BASE/source.json"

echo "--- building artifacts (base=$BASE) ---"
ALTSOURCE_BASE_URL="$BASE" ./scripts/build-altstore-source.sh >/dev/null

echo "--- ensuring repo exists & is public ---"
if gh repo view "$OWNER/$REPO" &>/dev/null; then
  gh repo edit "$OWNER/$REPO" --visibility public --accept-visibility-change-consequences >/dev/null || true
else
  gh repo create "$OWNER/$REPO" --public --description "AltStore source: Truecaller Lookup" >/dev/null
fi

echo "--- publishing dist/ to gh-pages branch ---"
TMP=$(mktemp -d)
cp dist/source.json dist/icon.png "$TMP/"
cp dist/*.ipa "$TMP/" 2>/dev/null || true
(
  cd "$TMP"
  git init -q
  git checkout -q -b gh-pages
  git add -A
  git -c user.name="AltStore Source Bot" -c user.email="altstore-${OWNER}@users.noreply.github.com" commit -qm "Update AltStore source"
  git remote add origin "https://github.com/$OWNER/$REPO.git"
  git push -q -f origin gh-pages
)
rm -rf "$TMP"

echo "--- enabling GitHub Pages (branch: gh-pages, root) ---"
if gh api "repos/$OWNER/$REPO/pages" >/dev/null 2>&1; then
  gh api -X PUT "repos/$OWNER/$REPO/pages" \
    -f "source[branch]=gh-pages" -f "source[path]=/" >/dev/null 2>&1 || true
else
  gh api -X POST "repos/$OWNER/$REPO/pages" \
    -f "source[branch]=gh-pages" -f "source[path]=/" >/dev/null 2>&1 || \
    echo "NOTE: couldn't enable Pages automatically; enable it at https://github.com/$OWNER/$REPO/settings/pages (Deploy from branch: gh-pages, /root)."
fi

echo ""
echo "Done. In AltStore:"
echo "  Add Source -> https://github.com/$OWNER/$REPO/raw/gh-pages/source.json"
echo "  (or $BASE/source.json once Pages is live)"
echo ""
echo "Then open the TrueCaller Lookup listing and tap install."