#!/usr/bin/env bash
# scripts/smoke-test.sh — post-build structural assertion.
#
# Catches the "no-theme silent failure" class of bug: a page that built
# successfully but is missing <!doctype>, <head>, or a stylesheet link.
# Any of those three missing = deploy was served with no layout applied.
#
# Usage:
#   ./scripts/smoke-test.sh _site
#   ./scripts/smoke-test.sh _site/subdir    # base_path variant
#
# Exit 0 on pass, 1 on any failure.

set -euo pipefail

SITE_DIR="${1:-_site}"
FAILED=0

# The canary files: every Jekyll site MUST produce a rendered home page.
# If any of these are malformed, the build is structurally broken.
CANARIES=(
  "index.html"
)

# Find all built HTML pages for the deep check.
# Exclude common Jekyll outputs that are intentionally minimal (sitemap, feed).
mapfile -t ALL_HTML < <(find "$SITE_DIR" -name "*.html" \
    -not -name "sitemap.html" \
    -not -name "robots.txt.html" \
    2>/dev/null)

echo "🔬 smoke-test: checking $SITE_DIR ($(wc -l < <(printf '%s\n' "${ALL_HTML[@]}")) html files)"

# ────────────────────────────────────────────────────────────────────
# Check 1: every HTML file has <!doctype html>
# ────────────────────────────────────────────────────────────────────
missing_doctype=()
for f in "${ALL_HTML[@]}"; do
  if ! head -5 "$f" | grep -qi "<!doctype html>"; then
    missing_doctype+=("$f")
  fi
done
if [[ ${#missing_doctype[@]} -gt 0 ]]; then
  echo "🔴 FAIL — ${#missing_doctype[@]} file(s) missing <!doctype html>:"
  printf '     %s\n' "${missing_doctype[@]:0:5}"
  FAILED=1
else
  echo "🟢 pass: all files have <!doctype html>"
fi

# ────────────────────────────────────────────────────────────────────
# Check 2: every HTML file has <head> and <body> tags
# ────────────────────────────────────────────────────────────────────
missing_head=()
for f in "${ALL_HTML[@]}"; do
  if ! grep -qi "<head" "$f" || ! grep -qi "<body" "$f"; then
    missing_head+=("$f")
  fi
done
if [[ ${#missing_head[@]} -gt 0 ]]; then
  echo "🔴 FAIL — ${#missing_head[@]} file(s) missing <head> or <body>:"
  printf '     %s\n' "${missing_head[@]:0:5}"
  FAILED=1
else
  echo "🟢 pass: all files have <head> + <body>"
fi

# ────────────────────────────────────────────────────────────────────
# Check 3: home page must link a stylesheet
# ────────────────────────────────────────────────────────────────────
for canary in "${CANARIES[@]}"; do
  path="$SITE_DIR/$canary"
  if [[ ! -f "$path" ]]; then
    echo "🔴 FAIL — canary file missing: $path"
    FAILED=1
    continue
  fi
  if ! grep -qi 'rel="stylesheet"' "$path"; then
    echo "🔴 FAIL — $path has no <link rel=\"stylesheet\"> (theme not applied)"
    FAILED=1
  else
    echo "🟢 pass: $canary links at least one stylesheet"
  fi
done

# ────────────────────────────────────────────────────────────────────
# Check 4: home page is reasonable size (un-themed output is <2KB)
# ────────────────────────────────────────────────────────────────────
home_size=$(wc -c < "$SITE_DIR/index.html" 2>/dev/null || echo 0)
if (( home_size < 5000 )); then
  echo "🔴 FAIL — index.html is only $home_size bytes (un-themed output is tiny; full theme >5KB)"
  FAILED=1
else
  echo "🟢 pass: index.html is $home_size bytes (healthy)"
fi

# ────────────────────────────────────────────────────────────────────
# Check 5: at least one <article> or .archive__item on home
# ────────────────────────────────────────────────────────────────────
if grep -qE '<article|archive__item' "$SITE_DIR/index.html"; then
  echo "🟢 pass: home page has at least one post/article rendered"
else
  echo "🟡 warn: home page has no <article> — check post loop"
fi

# ────────────────────────────────────────────────────────────────────
if (( FAILED )); then
  echo ""
  echo "❌ SMOKE TEST FAILED — site is structurally broken. Deploy blocked."
  exit 1
fi

echo ""
echo "✅ Smoke test passed — site has doctype, head, body, stylesheets, content."
exit 0
