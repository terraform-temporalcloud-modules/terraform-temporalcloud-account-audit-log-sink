variable "create_account_audit_log_sink" {
  description = "Controls if the account audit log sink should be created. Set to `false` to disable the module without removing the call"
  type        = bool
  default     = true
}

################################################################################
# Sink
################################################################################

variable "sink_name" {
  description = "Name of the audit log sink. Cannot be changed in place: editing it destroys the sink and creates a replacement, which interrupts audit log delivery for the whole account while that happens. Required unless `create_account_audit_log_sink` is `false`"
  type        = string
  default     = ""
}

variable "enabled" {
  description = "Controls whether the sink delivers audit logs. Setting this to `false` keeps the sink and its destination configuration in place but stops delivery; it does not remove the sink. Distinct from `create_account_audit_log_sink`, which controls whether the sink exists at all. Defaults to `true` when omitted"
  type        = bool
  default     = null
}

variable "timeouts" {
  description = "Create and delete timeouts, as duration strings such as `30s` or `2h45m`"
  type = object({
    create = optional(string)
    delete = optional(string)
  })
  default = {}
}

################################################################################
# Destination
#
# A sink delivers to exactly one destination. Set `kinesis` or `pubsub`, never
# both — `main.tf` enforces that at plan time.
################################################################################

variable "kinesis" {
  description = "Amazon Kinesis destination. `destination_uri` is the ARN of the Kinesis data stream Temporal Cloud writes to, `region` is the AWS region that stream is in, and `role_name` is the IAM role Temporal Cloud assumes in order to write to it. Temporal does not document whether `role_name` takes a full role ARN or a bare role name — the provider's example uses an ARN, Temporal's CloudFormation template uses a bare name — so neither form is enforced here. The stream and the role must already exist and the role must trust Temporal Cloud's delivery principals; see the README prerequisites. Mutually exclusive with `pubsub`"
  type = object({
    destination_uri = string
    region          = string
    role_name       = string
  })
  default = null

  # try() covers the null-object case: the attributes below are required within
  # the object type, so the only remaining failure is an empty string, which the
  # API has no way to resolve.
  validation {
    condition = try(
      length(var.kinesis.destination_uri) > 0 &&
      length(var.kinesis.region) > 0 &&
      length(var.kinesis.role_name) > 0,
      true
    )
    error_message = "Kinesis destination_uri, region and role_name must all be non-empty."
  }

  validation {
    condition     = try(startswith(var.kinesis.destination_uri, "arn:"), true)
    error_message = "Kinesis destination_uri must be the stream's ARN, for example arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs."
  }
}

variable "pubsub" {
  description = "Google Cloud Pub/Sub destination. `topic_name` is the bare Pub/Sub topic name — not a `projects/<project>/topics/<topic>` path. The remaining attributes identify the service account in your project that Temporal Cloud impersonates to publish: supply `service_account_email`, or both `service_account_id` and `gcp_project_id`. Supplying the email alone is enough, because the other two are derived from it. The topic and the service account must already exist, with the IAM bindings described in the README prerequisites. Mutually exclusive with `kinesis`"
  type = object({
    topic_name            = string
    gcp_project_id        = optional(string)
    service_account_email = optional(string)
    service_account_id    = optional(string)
  })
  default = null

  validation {
    condition     = try(length(var.pubsub.topic_name) > 0, true)
    error_message = "Pub/Sub topic_name must be non-empty."
  }

  # The three service account attributes are individually optional, which reads
  # as "omit them all and Temporal Cloud fills them in". It does not: the
  # provider needs an ID and a project, and derives them from the email only
  # when both are absent. Omitting all three fails with "Missing Service Account
  # Configuration". Caught here so it surfaces at plan against the variable.
  validation {
    condition = try(
      (var.pubsub.service_account_email != null && var.pubsub.service_account_email != "") ||
      (
        var.pubsub.service_account_id != null && var.pubsub.service_account_id != "" &&
        var.pubsub.gcp_project_id != null && var.pubsub.gcp_project_id != ""
      ),
      true
    )
    error_message = "Set pubsub.service_account_email, or both pubsub.service_account_id and pubsub.gcp_project_id. Temporal Cloud derives the ID and project from the email, but cannot identify the service account when all three are omitted."
  }

  validation {
    condition     = try(strcontains(var.pubsub.topic_name, "/") == false, true)
    error_message = "Pub/Sub topic_name must be the bare topic name, not a projects/<project>/topics/<topic> path."
  }
}
