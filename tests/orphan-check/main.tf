# Reports whether a named audit log sink is still present in the account.
#
# Creates nothing: a data source and outputs only.
#
# There is no data source that ENUMERATES audit log sinks — the only one the
# provider offers, `temporalcloud_account_audit_log_sink`, takes a required
# `sink_name` and looks that one sink up. So this fixture cannot sweep the account
# the way the namespace module's equivalent does; it can only answer "is the sink
# I name still there?".
#
# It is count-gated on `sink_name` for that reason. With no name supplied it reads
# nothing and reports zero orphans, which is the correct answer for this repo:
# tests/*.tftest.hcl deliberately creates no sink, so the suite cannot orphan one.
# Supply a name to check after creating a sink by hand.
#
# Note the asymmetry the caller has to handle: when the named sink is absent the
# data source fails rather than returning an empty result, so a clean account
# surfaces as an apply error, not as `orphan_count = 0`.
# scripts/check-orphans.sh interprets both outcomes.

data "temporalcloud_account_audit_log_sink" "named" {
  count = var.sink_name == "" ? 0 : 1

  sink_name = var.sink_name
}
