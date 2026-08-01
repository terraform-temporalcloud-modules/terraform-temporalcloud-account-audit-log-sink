# These identify infrastructure in your own Google Cloud project, so they have
# no sensible defaults. The README in this directory covers how to create them.

variable "pubsub_topic_name" {
  description = "Bare name of the Pub/Sub topic Temporal Cloud publishes audit logs to, for example `temporal-audit-logs`. Not a `projects/<project>/topics/<topic>` path"
  type        = string
}

variable "pubsub_service_account_email" {
  description = "Email of the service account in your project that Temporal Cloud impersonates to publish, for example `temporal-audit@example-project.iam.gserviceaccount.com`"
  type        = string
}
