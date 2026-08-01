locals {
  create_account_audit_log_sink = var.create_account_audit_log_sink

  # The destinations that were supplied. Exactly one must be present; the
  # precondition below turns anything else into a plan-time error.
  destinations = [for d in [var.kinesis, var.pubsub] : d if d != null]
}

################################################################################
# Account audit log sink
#
# An account has at most ONE audit log sink. This module therefore manages an
# account-wide singleton: two configurations pointed at the same account will
# fight over it, and destroying it stops audit log delivery for the whole
# account.
#
# `kinesis` and `pubsub` are nested attributes in the provider schema rather than
# blocks, so they are assigned straight from their variables and a null value
# omits them. `timeouts` is the only true block, hence the dynamic block below.
################################################################################

resource "temporalcloud_account_audit_log_sink" "this" {
  count = local.create_account_audit_log_sink ? 1 : 0

  sink_name = var.sink_name
  enabled   = var.enabled

  kinesis = var.kinesis
  pubsub  = var.pubsub

  dynamic "timeouts" {
    for_each = length([for v in var.timeouts : v if v != null]) > 0 ? [var.timeouts] : []

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
    }
  }

  # The provider enforces this too, but reports it against the resource's own
  # attribute paths. Repeating it here names the module's variables instead, and
  # fails before anything reaches the provider.
  #
  # Checked as a precondition rather than in a `variable` validation block for
  # two reasons: a validation cannot reference a second variable below Terraform
  # 1.9, and attaching the check to the resource makes it correctly inert when
  # `create_account_audit_log_sink` is `false` and no destination is expected.
  lifecycle {
    precondition {
      condition     = length(local.destinations) == 1
      error_message = "Set exactly one of `kinesis` or `pubsub`. A sink delivers to a single destination."
    }
  }
}
