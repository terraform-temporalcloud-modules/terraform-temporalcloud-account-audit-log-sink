#!/usr/bin/env bash
#
# Fails if the test suite left an audit log sink behind.
#
# The suite deliberately creates none — an account holds a single audit log sink
# and creating one changes account-wide compliance state, so there is no applying
# test. tests/README.md explains that. With nothing created, nothing can be
# orphaned, and the default run of this script says exactly that and exits 0.
#
# It is still wired into CI, because the check becomes real the moment someone
# does create a sink by hand: pass the name, either as the first argument or in
# AUDIT_LOG_SINK_NAME, and it reports whether that sink is still there.
#
# The provider offers no data source that enumerates audit log sinks — only
# `temporalcloud_account_audit_log_sink`, which requires a name — so a nameless
# sweep is not possible. That data source also FAILS rather than returning an
# empty result when the sink is absent, which is why the named branch below reads
# the terraform exit status as well as the outputs.
#
# Requires TEMPORAL_CLOUD_API_KEY when a name is supplied. Creates nothing.

set -euo pipefail

sink_name="${1:-${AUDIT_LOG_SINK_NAME:-}}"

if [ -z "$sink_name" ]; then
  echo "No sink name supplied — nothing to check."
  echo
  echo "The test suite creates no audit log sink, so it cannot orphan one. To check"
  echo "a sink that was created by hand:"
  echo
  echo "  scripts/check-orphans.sh <sink-name>"
  exit 0
fi

cd "$(git rev-parse --show-toplevel)/tests/orphan-check"

terraform init -backend=false -no-color >/dev/null

if ! output="$(terraform apply -auto-approve -no-color -var "sink_name=$sink_name" 2>&1)"; then
  # An absent sink and a genuine failure both land here, so show the error and
  # let a human read it rather than claiming the account is clean.
  echo "Could not read an audit log sink named \"$sink_name\"."
  echo "That is the expected result when the sink is gone. Terraform reported:"
  echo
  printf '%s\n' "$output" | tail -20
  exit 0
fi

count="$(terraform output -raw orphan_count)"

if [ "$count" -eq 0 ]; then
  echo "No leftover audit log sink named \"$sink_name\"."
  exit 0
fi

echo "ERROR: the audit log sink \"$sink_name\" is still present." >&2
echo "  state:   $(terraform output -raw orphan_state)" >&2
echo "  enabled: $(terraform output -json orphan_enabled)" >&2
echo >&2
echo "It was not destroyed. Remove it in the Temporal Cloud UI, or import and" >&2
echo "destroy it. Deleting it stops audit log delivery for the whole account, so" >&2
echo "confirm no live configuration owns it first." >&2
exit 1
