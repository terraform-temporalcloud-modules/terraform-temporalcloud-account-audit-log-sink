provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

locals {
  name = "ex-${basename(path.cwd)}"
}

################################################################################
# Audit log sink delivering to Google Cloud Pub/Sub
#
# This configures the Temporal Cloud side only. The topic and the service
# account must already exist in your Google Cloud project, with the two IAM
# bindings described in the README in this directory.
#
# The sink is ACCOUNT-WIDE. Applying this points the whole Temporal Cloud
# account's audit log at the topic below, and destroying it stops audit logging
# for the account.
################################################################################

module "audit_log_sink" {
  source  = "terraform-temporalcloud-modules/account-audit-log-sink/temporalcloud"
  version = "~> 1.0"

  sink_name = local.name

  # Delivery is on. Set to false to keep the sink configured but pause delivery,
  # which is the reversible alternative to destroying it.
  enabled = true

  pubsub = {
    # The bare topic name, not projects/<project>/topics/<topic>.
    topic_name = var.pubsub_topic_name

    # Supplying the email alone is enough: Temporal Cloud derives the service
    # account ID and project from it. Supply service_account_id and
    # gcp_project_id instead if you would rather be explicit — but supply one
    # form or the other, because all three being absent is an error even though
    # each is individually optional.
    service_account_email = var.pubsub_service_account_email
  }

  timeouts = {
    create = "10m"
    delete = "10m"
  }
}
