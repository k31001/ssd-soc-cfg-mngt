#!/usr/bin/env bash
# 한 줄로 표준 branch protection 일괄 적용.
# 정책은 policy/branch-protection.json 에 정의 — 단일 source of truth.
set -euo pipefail

REPO="${1:?usage: $0 <org/repo>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
POLICY="$ROOT/recommended/scaffolding/policy/branch-protection.json"

echo "[bp] applying branch protection to $REPO (main) ..."
gh api "repos/$REPO/branches/main/protection" \
   --method PUT \
   --input "$POLICY" \
   -H "Accept: application/vnd.github+json" \
   >/dev/null

echo "[bp] enabling CODEOWNERS enforcement ..."
gh api "repos/$REPO/branches/main/protection/required_pull_request_reviews" \
   --method PATCH \
   -f require_code_owner_reviews=true \
   -f required_approving_review_count=1 \
   >/dev/null

echo "[bp] done."
