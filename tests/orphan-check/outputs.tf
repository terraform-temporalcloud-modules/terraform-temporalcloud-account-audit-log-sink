output "orphans" {
  description = "Names of audit log sinks still present in the account. At most one entry, because only a named lookup is possible"
  value       = [for s in data.temporalcloud_account_audit_log_sink.named : s.sink_name]
}

output "orphan_count" {
  description = "Number of audit log sinks still present. Zero when no `sink_name` was supplied, because nothing was checked"
  value       = length(data.temporalcloud_account_audit_log_sink.named)
}

output "orphan_state" {
  description = "State Temporal Cloud reports for the named sink, or an empty string when nothing was checked"
  value       = try(data.temporalcloud_account_audit_log_sink.named[0].state, "")
}

output "orphan_enabled" {
  description = "Whether the named sink is still delivering audit logs. `null` when nothing was checked"
  value       = try(data.temporalcloud_account_audit_log_sink.named[0].enabled, null)
}
