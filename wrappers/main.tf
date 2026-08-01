module "wrapper" {
  source = "../"

  for_each = var.items

  create_account_audit_log_sink = try(each.value.create_account_audit_log_sink, var.defaults.create_account_audit_log_sink, true)
  enabled                       = try(each.value.enabled, var.defaults.enabled, null)
  kinesis                       = try(each.value.kinesis, var.defaults.kinesis, null)
  pubsub                        = try(each.value.pubsub, var.defaults.pubsub, null)
  sink_name                     = try(each.value.sink_name, var.defaults.sink_name, "")
  timeouts                      = try(each.value.timeouts, var.defaults.timeouts, {})
}
