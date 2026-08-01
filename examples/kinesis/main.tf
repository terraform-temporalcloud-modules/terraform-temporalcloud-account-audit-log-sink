provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

locals {
  name = "ex-${basename(path.cwd)}"
}

################################################################################
# Audit log sink delivering to Amazon Kinesis
#
# This configures the Temporal Cloud side only. The stream and the IAM role must
# already exist in your AWS account, and the role must trust Temporal Cloud's
# delivery principals — see the README in this directory before applying.
#
# The sink is ACCOUNT-WIDE. Applying this points the whole Temporal Cloud
# account's audit log at the stream below, and destroying it stops audit logging
# for the account.
################################################################################

module "audit_log_sink" {
  source  = "terraform-temporalcloud-modules/account-audit-log-sink/temporalcloud"
  version = "~> 1.0"

  sink_name = local.name

  # Delivery is on. Set to false to keep the sink configured but pause delivery,
  # which is the reversible alternative to destroying it.
  enabled = true

  kinesis = {
    # The stream's ARN, not its bare name.
    destination_uri = var.kinesis_stream_arn
    region          = var.kinesis_region

    # The role's full ARN. A Kinesis destination has no separate field for your
    # AWS account ID, so the account has to travel in this value.
    role_name = var.kinesis_role_arn
  }

  timeouts = {
    create = "10m"
    delete = "10m"
  }
}
