# Referencing every output forces Terraform to evaluate each one, so a broken
# output expression fails validation here rather than in a consumer's plan.

output "all_inputs_kinesis" {
  description = "Every output of the fully configured Kinesis module instance"
  value = {
    account_audit_log_sink_id      = module.all_inputs_kinesis.account_audit_log_sink_id
    account_audit_log_sink_name    = module.all_inputs_kinesis.account_audit_log_sink_name
    account_audit_log_sink_enabled = module.all_inputs_kinesis.account_audit_log_sink_enabled
    account_audit_log_sink_kinesis = module.all_inputs_kinesis.account_audit_log_sink_kinesis
    account_audit_log_sink_pubsub  = module.all_inputs_kinesis.account_audit_log_sink_pubsub
  }
}

output "all_inputs_pubsub" {
  description = "Every output of the fully configured Pub/Sub module instance"
  value = {
    account_audit_log_sink_id      = module.all_inputs_pubsub.account_audit_log_sink_id
    account_audit_log_sink_name    = module.all_inputs_pubsub.account_audit_log_sink_name
    account_audit_log_sink_enabled = module.all_inputs_pubsub.account_audit_log_sink_enabled
    account_audit_log_sink_kinesis = module.all_inputs_pubsub.account_audit_log_sink_kinesis
    account_audit_log_sink_pubsub  = module.all_inputs_pubsub.account_audit_log_sink_pubsub
  }
}

output "disabled" {
  description = "Outputs when create_account_audit_log_sink is false — every one must fall back rather than error"
  value = {
    account_audit_log_sink_id      = module.disabled.account_audit_log_sink_id
    account_audit_log_sink_name    = module.disabled.account_audit_log_sink_name
    account_audit_log_sink_enabled = module.disabled.account_audit_log_sink_enabled
    account_audit_log_sink_kinesis = module.disabled.account_audit_log_sink_kinesis
    account_audit_log_sink_pubsub  = module.disabled.account_audit_log_sink_pubsub
  }
}

output "minimal" {
  description = "Outputs from the minimum viable module call"
  value       = module.minimal.account_audit_log_sink_id
}

output "wrapper" {
  description = "Wrapper outputs, keyed by the same keys as its items"
  value       = module.wrapper.wrapper
}
