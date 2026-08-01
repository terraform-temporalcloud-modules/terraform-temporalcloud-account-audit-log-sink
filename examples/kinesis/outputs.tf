output "account_audit_log_sink_id" {
  description = "The unique identifier of the account audit log sink"
  value       = module.audit_log_sink.account_audit_log_sink_id
}

output "account_audit_log_sink_name" {
  description = "The name of the account audit log sink"
  value       = module.audit_log_sink.account_audit_log_sink_name
}

output "account_audit_log_sink_enabled" {
  description = "Whether the sink is delivering audit logs"
  value       = module.audit_log_sink.account_audit_log_sink_enabled
}

output "account_audit_log_sink_kinesis" {
  description = "The Kinesis destination Temporal Cloud recorded for the sink"
  value       = module.audit_log_sink.account_audit_log_sink_kinesis
}
