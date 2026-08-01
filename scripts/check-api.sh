#!/usr/bin/env bash
#
# Liveness check: confirms the Temporal Cloud API answers and the API key works.
#
# Run this before the tests so a credentials or connectivity problem fails
# immediately and unambiguously. Without it a missing or rejected key surfaces as
# every run block SKIPPING, which reads as a suite that had nothing to do rather
# than as a credentials problem.
#
# Creates nothing — tests/liveness reads one data source.

set -euo pipefail

if [ -z "${TEMPORAL_CLOUD_API_KEY:-}" ]; then
  echo "ERROR: TEMPORAL_CLOUD_API_KEY is not set." >&2
  echo "       The tests create nothing, but the provider authenticates when it" >&2
  echo "       initialises, so they cannot run without it." >&2
  exit 1
fi

cd "$(git rev-parse --show-toplevel)/tests/liveness"

if ! terraform init -backend=false -no-color >/dev/null 2>&1; then
  echo "ERROR: terraform init failed for the liveness check." >&2
  terraform init -backend=false -no-color 2>&1 | tail -20 >&2
  exit 1
fi

if ! output="$(terraform apply -auto-approve -no-color 2>&1)"; then
  echo "ERROR: Temporal Cloud API is unreachable or the API key was rejected." >&2
  echo >&2
  printf '%s\n' "$output" | tail -20 >&2
  echo >&2
  echo "Check that TEMPORAL_CLOUD_API_KEY is set to a current, unexpired key with" >&2
  echo "access to the intended account." >&2
  exit 1
fi

# A successful read is the whole liveness signal. The region count is reported for
# context only and is deliberately NOT a failure condition: an audit log sink is
# account-scoped and needs no region, so failing on zero would reject an account
# this module works perfectly well against.
count="$(terraform output -raw region_count)"

echo "API reachable, key accepted. Account reports $count region(s)."
