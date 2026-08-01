################################################################################
# Account audit log sink
#
# Outputs are wrapped in `try()` so they still evaluate to an empty value when
# `create_account_audit_log_sink = false` leaves no resource to reference.
################################################################################

output "account_audit_log_sink_id" {
  description = "The unique identifier of the account audit log sink"
  value       = try(temporalcloud_account_audit_log_sink.this[0].id, "")
}

output "account_audit_log_sink_name" {
  description = "The name of the account audit log sink"
  value       = try(temporalcloud_account_audit_log_sink.this[0].sink_name, "")
}

output "account_audit_log_sink_enabled" {
  description = "Whether the sink is delivering audit logs. `false` means the sink exists but delivery is paused"
  value       = try(temporalcloud_account_audit_log_sink.this[0].enabled, null)
}

################################################################################
# Destination
#
# Exposed as whole objects rather than per-attribute: only one is ever populated,
# and consumers reading them back are usually confirming what the account is
# pointed at rather than wiring a single field into something else.
################################################################################

output "account_audit_log_sink_kinesis" {
  description = "The resolved Amazon Kinesis destination configuration. `null` when the sink delivers to Pub/Sub or does not exist"
  value       = try(temporalcloud_account_audit_log_sink.this[0].kinesis, null)
}

output "account_audit_log_sink_pubsub" {
  description = "The resolved Google Cloud Pub/Sub destination configuration, including the project, service account email and service account ID Temporal Cloud selected when they were not supplied. `null` when the sink delivers to Kinesis or does not exist"
  value       = try(temporalcloud_account_audit_log_sink.this[0].pubsub, null)
}
