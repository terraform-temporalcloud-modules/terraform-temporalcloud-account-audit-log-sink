provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

################################################################################
# Local regression coverage
#
# The examples/ directories source the PUBLISHED module so they are copy-pasteable
# for consumers. That means they validate the last release, not the code in this
# repo — a renamed or removed variable would slip through CI unnoticed.
#
# This directory closes that gap: it sources the module by relative path and
# passes EVERY input, so `terraform validate` fails here the moment the variable
# surface changes incompatibly. CI picks it up automatically because it contains a
# versions.tf with required_version.
#
# Nothing here is ever applied. An account has a single audit log sink, so the
# three enabled module calls below would contend for it — that is fine for
# validation and is why tests/*.tftest.hcl does not create one. See
# ../README.md.
#
# When you add a variable to the root module, add it here in the same PR. Adding
# it to examples/ has to wait until the next release publishes it.
################################################################################

# Every input the module accepts, with the Kinesis destination.
module "all_inputs_kinesis" {
  source = "../../"

  create_account_audit_log_sink = true

  sink_name = "tflocal-audit-kinesis"
  enabled   = true

  kinesis = {
    destination_uri = "arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs"
    region          = "us-east-1"
    role_name       = "arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer"
  }

  timeouts = {
    create = "10m"
    delete = "10m"
  }
}

# The Pub/Sub destination, with every optional attribute supplied. Together with
# the call above this covers the full input surface.
module "all_inputs_pubsub" {
  source = "../../"

  create_account_audit_log_sink = true

  sink_name = "tflocal-audit-pubsub"
  enabled   = false

  pubsub = {
    topic_name            = "temporal-audit-logs"
    gcp_project_id        = "example-project"
    service_account_email = "temporal-audit@example-project.iam.gserviceaccount.com"
    service_account_id    = "temporal-audit"
  }

  timeouts = {
    create = "10m"
    delete = "10m"
  }
}

# Minimum viable call: a name and one destination, everything else defaulted.
# `service_account_email` is not optional in practice — the module's validation
# explains why the three service account attributes cannot all be omitted.
module "minimal" {
  source = "../../"

  sink_name = "tflocal-audit-minimal"

  pubsub = {
    topic_name            = "temporal-audit-logs"
    service_account_email = "temporal-audit@example-project.iam.gserviceaccount.com"
  }
}

# The create flag off: proves the module produces no resources and that every
# output still evaluates via its try() fallback. Also proves the exactly-one
# destination precondition stays inert when there is no resource to create.
module "disabled" {
  source = "../../"

  create_account_audit_log_sink = false
}

# The wrapper, exercised through the local path as well.
module "wrapper" {
  source = "../../wrappers"

  defaults = {
    enabled = true

    kinesis = {
      destination_uri = "arn:aws:kinesis:us-east-1:111122223333:stream/temporal-audit-logs"
      region          = "us-east-1"
      role_name       = "arn:aws:iam::111122223333:role/Temporal-Cloud-Log-Writer"
    }
  }

  items = {
    primary = { sink_name = "tflocal-audit-primary" }

    # Overrides the shared Kinesis default with a Pub/Sub destination. Only one
    # of the two may be set, so the override must also clear the other.
    secondary = {
      sink_name = "tflocal-audit-secondary"
      kinesis   = null

      pubsub = {
        topic_name            = "temporal-audit-logs"
        service_account_email = "temporal-audit@example-project.iam.gserviceaccount.com"
      }
    }
  }
}
